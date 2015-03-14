r"""
Tools for generating lists of integers

IMPORTANT NOTE (2009/02):
The internal functions in this file will be deprecated soon.
Please only use them through :class:`IntegerListsLex`.

AUTHORS:

- Mike Hansen

- Travis Scrimshaw (2012-05-12): Fixed errors when returning ``None`` from
  first. Added checks to make sure ``max_slope`` is satisfied.

- Travis Scrimshaw (2012-10-29): Made ``IntegerListsLex`` into a parent with
  the element class ``IntegerListsLexElement``.
"""
#*****************************************************************************
#       Copyright (C) 2007 Mike Hansen <mhansen@gmail.com>,
#       Copyright (C) 2012 Travis Scrimshaw <tscrim@ucdavis.edu>
#
#  Distributed under the terms of the GNU General Public License (GPL)
#
#    This code is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#    General Public License for more details.
#
#  The full text of the GPL is available at:
#
#                  http://www.gnu.org/licenses/
#*****************************************************************************

include 'sage/ext/interrupt.pxi'
from sage.misc.cachefunc import cached_method
from sage.rings.arith import binomial
from sage.rings.integer cimport Integer, smallInteger
from sage.rings.integer_ring import ZZ
from sage.rings.rational_field import QQ
from sage.categories.finite_enumerated_sets import FiniteEnumeratedSets
from sage.structure.parent cimport Parent
from sage.structure.list_clone cimport ClonableArray
from sage.misc.lazy_attribute import lazy_attribute
from sage.rings.infinity import infinity
from sage.geometry.polyhedron.constructor import Polyhedron


def Polyhedron_inf(ieqs, **kwds):
    """
    Given a list of inequalities, return a :class:`Polyhedron`
    determined by the inequalities.

    Unlike the usual :class:`Polyhedron` constructor, we allow
    infinities as constant terms of the inequalities.
    """
    if 'ambient_dim' not in kwds:
        try:
            kwds['ambient_dim'] = len(ieqs[0])-1
        except Exception:
            raise ValueError("ieqs must be a non-empty list of lists")

    # Loop over given inequalities and construct new, checking for
    # infinities.
    cdef list newieqs = []
    for ieq in ieqs:
        c = ieq[0]
        if c == -infinity:
            # Insatisfiable => empty polyhedron
            return Polyhedron(**kwds)
        elif c == infinity:
            # Trivial inequality => do not add it
            pass
        else:
            newieqs.append(ieq)

    return Polyhedron(ieqs=newieqs, **kwds)


class IntegerList(ClonableArray):
    """
    Element class for :class:`IntegerLists`.
    """
    def check(self):
        """
        Check to make sure this is a valid element in its
        :class:`IntegerLists` parent.

        .. TODO:: Placeholder. Implement a proper check.

        EXAMPLES::

            sage: C = IntegerLists(4)
            sage: C([4]).check()
            True
        """
        return True


def _function_iter(f):
    """
    A generator returning f(0), f(1), ...
    """
    cdef Integer i = smallInteger(0)
    cdef Integer one = smallInteger(1)
    while True:
        yield f(i)
        i = i._add_(one)


def _minimal_rectangle_sum(part, min_length, max_length):
    """
    Given a number of parts, each equal to ``part`` with length
    bounded by ``[min_length, max_length]``, what is the minimal
    possible sum?
    """
    assert min_length <= max_length
    if not part or max_length <= 0:
        return smallInteger(0)
    if part > 0:
        return part * min_length
    else:
        return part * max_length


def _maximal_rectangle_sum(part, min_length, max_length):
    """
    Given a number of parts, each equal to ``part`` with length
    bounded by ``[min_length, max_length]``, what is the maximal
    possible sum?
    """
    assert min_length <= max_length
    if not part or max_length <= 0:
        return smallInteger(0)
    if part > 0:
        return part * max_length
    else:
        return part * min_length


cdef Integer len_or_0(x):
    try:
        return smallInteger(len(x))
    except Exception:
        return smallInteger(0)


cdef signed_infinity(s):
    if not s:
        return smallInteger(0)
    if s > 0:
        return infinity
    else:
        return -infinity


class IntegerLists(Parent):
    r"""
    A combinatorial class `C` for integer lists satisfying certain
    sum, length, upper/lower bound and regularity constraints. The
    purpose of this tool is mostly to provide a Constant Amortized
    Time iterator through those lists, in lexicographic order.

    INPUT:

    - ``n`` -- a non negative integer
    - ``min_length`` -- a non negative integer
    - ``max_length`` -- an integer or `\infty`
    - ``length`` -- an integer; overrides min_length and max_length if
      specified
    - ``floor`` -- a function `f` (or list);    defaults to ``lambda i: 0``
    - ``ceiling`` -- a function `f` (or list);  defaults to
      ``lambda i: infinity``
    - ``min_slope`` -- an integer or `-\infty`; defaults to `-\infty`
    - ``max_slope`` -- an integer or `+\infty`; defaults to `+\infty`

    An *integer list* is a list `l` of nonnegative integers, its
    *parts*. The *length* of `l` is the number of its parts;
    the *sum* of `l` is the sum of its parts.

    .. NOTE::

       Two valid integer lists are considered equivalent if they only
       differ by trailing zeroes. In this case, only the list with the
       least number of trailing zeroes will be produced.

    The constraints on the lists are as follow:

    - Sum: `sum(l) == n`

    - Length: ``min_length <= len(l) <= max_length``

    - Lower and upper bounds: ``floor(i) <= l[i] <= ceiling(i)``, for
      ``i`` from 0 to ``len(l)``

    - Regularity condition: ``minSlope <= l[i+1]-l[i] <= maxSlope``,
      for ``i`` from 0 to ``len(l)-1``

    This is a generic low level tool. The interface has been designed
    with efficiency in mind. It is subject to incompatible changes in
    the future. More user friendly interfaces are provided by high
    level tools like :class:`Partitions` or :class:`Compositions`.

    EXAMPLES:

    We create the combinatorial class of lists of length 3 and sum 2::

        sage: C = IntegerLists(2, length=3)
        sage: C
        Integer lists of sum 2 satisfying certain constraints
        sage: C.cardinality()
        6
        sage: [p for p in C]
        [[2, 0, 0], [1, 1, 0], [1, 0, 1], [0, 2, 0], [0, 1, 1], [0, 0, 2]]

        sage: [2, 0, 0] in C
        True
        sage: [2, 0, 1] in C
        False
        sage: "a" in C
        False
        sage: ["a"] in C
        False

        sage: C.first()
        [2, 0, 0]

    One can specify lower and upper bound on each part::

        sage: list(IntegerLists(5, length = 3, floor = [1,2,0], ceiling = [3,2,3]))
        [[3, 2, 0], [2, 2, 1], [1, 2, 2]]

    Using the slope condition, one can generate integer partitions
    (but see :mod:`sage.combinat.partition.Partitions`)::

        sage: list(IntegerLists(4, max_slope=0))
        [[4], [3, 1], [2, 2], [2, 1, 1], [1, 1, 1, 1]]

    This is the list of all partitions of `7` with parts at least `2`::

        sage: list(IntegerLists(7, max_slope = 0, min_part = 2))
        [[7], [5, 2], [4, 3], [3, 2, 2]]

    This is the list of all partitions of `5` and length at most 3
    which are bounded below by [2,1,1]::

        sage: list(IntegerLists(5, max_slope = 0, max_length = 3, floor = [2,1,1]))
        [[5], [4, 1], [3, 2], [3, 1, 1], [2, 2, 1]]

    Note that ``[5]`` is considered valid, because the lower bound
    constraint only apply to existing positions in the list. To
    obtain instead the partitions containing ``[2,1,1]``, one need to
    use ``min_length``::

        sage: list(IntegerLists(5, max_slope = 0, min_length = 3, max_length = 3, floor = [2,1,1]))
        [[3, 1, 1], [2, 2, 1]]

    This is the list of all partitions of `5` which are contained in
    ``[3,2,2]``::

        sage: list(IntegerLists(5, max_slope = 0, max_length = 3, ceiling = [3,2,2]))
        [[3, 2], [3, 1, 1], [2, 2, 1]]


    This is the list of all compositions of `4` (but see Compositions)::

        sage: list(IntegerLists(4, min_part = 1))
        [[4], [3, 1], [2, 2], [2, 1, 1], [1, 3], [1, 2, 1], [1, 1, 2], [1, 1, 1, 1]]

    This is the list of all integer vectors of sum `4` and length `3`::

        sage: list(IntegerLists(4, length = 3))
        [[4, 0, 0], [3, 1, 0], [3, 0, 1], [2, 2, 0], [2, 1, 1], [2, 0, 2], [1, 3, 0], [1, 2, 1], [1, 1, 2], [1, 0, 3], [0, 4, 0], [0, 3, 1], [0, 2, 2], [0, 1, 3], [0, 0, 4]]


    There are all the lists of sum 4 and length 4 such that l[i] <= i::

        sage: list(IntegerLists(4, length=4, ceiling=lambda i: i))
        [[0, 1, 2, 1], [0, 1, 1, 2], [0, 1, 0, 3], [0, 0, 2, 2], [0, 0, 1, 3]]

    This is the list of all monomials of degree `4` which divide the
    monomial `x^3y^1z^2` (a monomial being identified with its
    exponent vector)::

        sage: R.<x,y,z> = QQ[]
        sage: m = [3,1,2]
        sage: def term(exponents):
        ...       return x^exponents[0] * y^exponents[1] * z^exponents[2]
        ...
        sage: list( IntegerLists(4, length = len(m), ceiling = m, element_constructor = term) )
        [x^3*y, x^3*z, x^2*y*z, x^2*z^2, x*y*z^2]

    Note the use of the element_constructor feature.

    In general, the complexity of the iteration algorithm is constant
    time amortized for each integer list produced.  There is one
    degenerate case though where the algorithm may run forever without
    producing anything. If max_length is `+\infty` and max_slope `>0`,
    testing whether there exists a valid integer list of sum `n` may
    be only semi-decidable. In the following example, the algorithm
    will enter an infinite loop, because it needs to decide whether
    `ceiling(i)` is nonzero for some `i`::

        sage: list( IntegerLists(1, ceiling = lambda i: 0) ) # todo: not implemented

    .. NOTE::

       Caveat: counting is done by brute force generation. In some
       special cases, it would be possible to do better by counting
       techniques for integral point in polytopes.

    .. NOTE::

       Caveat: with the current implementation, the constraints should
       satisfy the following conditions:

       - The upper and lower bounds themselves should satisfy the
         slope constraints.

       - The maximal and minimal slopes values should not be equal.

       - The maximal and minimal part values should not be equal.

    Those conditions are not checked by the algorithm, and the
    result may be completely incorrect if they are not satisfied:

    In the following example, the slope condition is not satisfied
    by the upper bound on the parts, and ``[3,3]`` is erroneously
    included in the result::

        sage: list(IntegerLists(6, max_part=3, max_slope=-1))
        [[3, 2, 1]]

    With some work, this could be fixed without affecting the overall
    complexity and efficiency. Also, the generation algorithm could be
    extended to deal with non-constant slope constraints and with
    negative parts, as well as to accept a range parameter instead of
    a single integer for the sum `n` of the lists (the later was
    readily implemented in MuPAD-Combinat). Encouragements,
    suggestions, and help are welcome.

    .. TODO:

        Integrate all remaining tests from
        http://mupad-combinat.svn.sourceforge.net/viewvc/mupad-combinat/trunk/MuPAD-Combinat/lib/COMBINAT/TEST/MachineIntegerLists.tst

    TESTS::

        sage: g = lambda x: lambda i: x
        sage: list(IntegerLists(0, floor = g(1), min_slope = 0))
        [[]]
        sage: list(IntegerLists(0, floor = g(1), min_slope = 0, max_slope = 0))
        [[]]
        sage: list(IntegerLists(0, max_length=0, floor = g(1), min_slope = 0, max_slope = 0))
        [[]]
        sage: list(IntegerLists(0, max_length=0, floor = g(0), min_slope = 0, max_slope = 0))
        [[]]
        sage: list(IntegerLists(0, min_part = 1, min_slope = 0))
        [[]]
        sage: list(IntegerLists(1, min_part = 1, min_slope = 0))
        [[1]]
        sage: list(IntegerLists(0, min_length = 1, min_part = 1, min_slope = 0))
        []
        sage: list(IntegerLists(0, min_length = 1, min_slope = 0))
        [[0]]
        sage: list(IntegerLists(3, max_length=2, ))
        [[3], [2, 1], [1, 2], [0, 3]]
        sage: partitions = {"min_part": 1, "max_slope": 0}
        sage: partitions_min_2 = {"floor": g(2), "max_slope": 0}
        sage: compositions = {"min_part": 1}
        sage: integer_vectors = lambda l: {"length": l}
        sage: lower_monomials = lambda c: {"length": c, "floor": lambda i: c[i]}
        sage: upper_monomials = lambda c: {"length": c, "ceiling": lambda i: c[i]}
        sage: constraints = { "min_part":1, "min_slope": -1, "max_slope": 0}
        sage: list(IntegerLists(6, **partitions))
        [[6],
         [5, 1],
         [4, 2],
         [4, 1, 1],
         [3, 3],
         [3, 2, 1],
         [3, 1, 1, 1],
         [2, 2, 2],
         [2, 2, 1, 1],
         [2, 1, 1, 1, 1],
         [1, 1, 1, 1, 1, 1]]
        sage: list(IntegerLists(6, **constraints))
        [[6],
         [3, 3],
         [3, 2, 1],
         [2, 2, 2],
         [2, 2, 1, 1],
         [2, 1, 1, 1, 1],
         [1, 1, 1, 1, 1, 1]]
        sage: list(IntegerLists(1, **partitions_min_2))
        []
        sage: list(IntegerLists(2, **partitions_min_2))
        [[2]]
        sage: list(IntegerLists(3, **partitions_min_2))
        [[3]]
        sage: list(IntegerLists(4, **partitions_min_2))
        [[4], [2, 2]]
        sage: list(IntegerLists(5, **partitions_min_2))
        [[5], [3, 2]]
        sage: list(IntegerLists(6, **partitions_min_2))
        [[6], [4, 2], [3, 3], [2, 2, 2]]
        sage: list(IntegerLists(7, **partitions_min_2))
        [[7], [5, 2], [4, 3], [3, 2, 2]]
        sage: list(IntegerLists(9, **partitions_min_2))
        [[9], [7, 2], [6, 3], [5, 4], [5, 2, 2], [4, 3, 2], [3, 3, 3], [3, 2, 2, 2]]
        sage: list(IntegerLists(10, **partitions_min_2))
        [[10],
         [8, 2],
         [7, 3],
         [6, 4],
         [6, 2, 2],
         [5, 5],
         [5, 3, 2],
         [4, 4, 2],
         [4, 3, 3],
         [4, 2, 2, 2],
         [3, 3, 2, 2],
         [2, 2, 2, 2, 2]]
        sage: list(IntegerLists(4, **compositions))
        [[4], [3, 1], [2, 2], [2, 1, 1], [1, 3], [1, 2, 1], [1, 1, 2], [1, 1, 1, 1]]
        sage: list(IntegerLists(6, min_length=1, floor=[7]))
        []
    """
    def __init__(self,
                 n=None,
                 length=None, min_length=0, max_length=infinity,
                 floor=None, ceiling=None,
                 min_part=0, max_part=infinity,
                 min_slope=-infinity, max_slope=infinity,
                 *, min_sum=0, max_sum=infinity, sum=None,
                 min_part_last=1, max_part_last=infinity,
                 name=None, sort_lex=True,
                 element_constructor=None,
                 element_class=IntegerList):
        """
        Initialize ``self``.

        TESTS::

            sage: C = IntegerLists(2, length=3)
            sage: C == loads(dumps(C))
            True
            sage: C == loads(dumps(C)) # this did fail at some point, really!
            True
            sage: C is loads(dumps(C)) # todo: not implemented
            True
            sage: C.cardinality().parent() is ZZ
            True
            sage: TestSuite(C).run()
        """
        if n is not None:
            sum = n

        if sum is not None:
            min_sum = sum
            max_sum = sum

        if length is not None:
            min_length = length
            max_length = length

        if min_length < 0:
            raise ValueError("the minimal length must be at least 0")

        # Floor/ceiling should either be iterable, or a callable function
        if not floor:
            floor_iter = iter([])
        else:
            try:
                floor_iter = iter(floor)
            except TypeError:
                floor_iter = _function_iter(floor)

        if not ceiling:
            ceil_iter = iter([])
        else:
            try:
                ceil_iter = iter(ceiling)
            except TypeError:
                ceil_iter = _function_iter(ceiling)

        if name is not None:
            self.rename(name)

        self.floor_iter = floor_iter
        self.ceil_iter = ceil_iter
        self.min_sum = min_sum
        self.max_sum = max_sum
        self.min_length = min_length
        self.max_length = max_length
        self.min_part = min_part
        self.max_part = max_part
        self.min_part_last = min_part_last
        self.max_part_last = max_part_last
        self.min_slope = min_slope
        self.max_slope = max_slope
        self.Element = element_class
        if element_constructor is not None:
            self._element_constructor_ = element_constructor
        self.sort_lex = sort_lex
        Parent.__init__(self, category=FiniteEnumeratedSets())

        # floor_list and ceil_list will contain lower and upper bounds
        # for the i-th part, keeping in mind min/max_part and
        # floor/ceil_iter and also min/max_slope.
        self.floor_list = []
        self.ceil_list = []

        # Computed version of max_length: if the conditions imply some
        # upper bound on the length, this attribute will be changed to
        # reflect that.
        if self.is_trivially_zero():
            self.effective_max_length = 0
        else:
            self.effective_max_length = max_length

        # try_length is the minimal length of lists to compute before
        # we worry that there are no more possible lists.
        if self.effective_max_length < infinity:
            self.try_length = self.effective_max_length
        else:
            self.try_length = max([8 + self.min_length,
                len_or_0(floor), len_or_0(ceiling)])
            if self.max_sum < infinity:
                self.try_length = max(self.try_length, self.max_sum)
            if -self.min_sum < infinity:
                self.try_length = max(self.try_length, -self.min_sum)
        assert self.try_length < infinity

    def is_trivially_zero(self):
        """
        Do the conditions trivially exclude a list of length > 0?
        """
        return (
            self.min_sum == infinity or
            self.min_part == infinity or
            self.max_length <= 0 or
            self.max_sum == -infinity or
            self.max_part == -infinity or
            self.min_sum > self.max_sum or
            self.min_length > self.max_length or
            self.min_part > self.max_part or
            _minimal_rectangle_sum(self.min_part, max(1, self.min_length), self.max_length) > self.max_sum or
            _maximal_rectangle_sum(self.max_part, max(1, self.min_length), self.max_length) < self.min_sum)

    def _element_constructor_(self, lst):
        """
        Construct an element with ``self`` as parent.

        EXAMPLES::

            sage: C = IntegerLists(4)
            sage: C([4])
            [4]
        """
        return self.element_class(self, lst)

    def __cmp__(self, x):
        """
        Compares two different :class:`IntegerLists`.

        For now, the comparison is done just on their repr's which is
        not robust!

        EXAMPLES::

            sage: C = IntegerLists(2, length=3)
            sage: D = IntegerLists(4, length=3)
            sage: repr(C) == repr(D)
            False
            sage: C == D
            False
        """
        return cmp(repr(self), repr(x))

    def _repr_(self):
        """
        Returns the name of this combinatorial class.

        EXAMPLES::

            sage: C = IntegerLists(2, length=3)
            sage: C
            Integer lists of sum 2 satisfying certain constraints
            sage: C = IntegerLists(min_sum=-1, max_sum=4)
            sage: C
            Integer lists of sum in [-1, 4] satisfying certain constraints
            sage: C = IntegerLists(min_sum=-infinity, max_sum=4)
            sage: C
            Integer lists of sum at most 4 satisfying certain constraints
            sage: C = IntegerLists()
            sage: C
            Integer lists of sum at least 0 satisfying certain constraints
            sage: C = IntegerLists(min_sum=-infinity, max_sum=infinity)
            sage: C
            Integer lists satisfying certain constraints
            sage: C = IntegerLists(min_sum=1, max_sum=4, name="A given name")
            sage: C
            A given name
        """
        if self.min_sum == self.max_sum:
            s= " of sum {}".format(self.min_sum)
        elif self.min_sum == -infinity:
            if self.max_sum == infinity:
                s = ""
            else:
                s = " of sum at most {}".format(self.max_sum)
        elif self.max_sum == infinity:
            s = " of sum at least {}".format(self.min_sum)
        else:
            s = " of sum in [{}, {}]".format(self.min_sum, self.max_sum)
        return "Integer lists" + s + " satisfying certain constraints"

    def floor(self, i):
        """
        Returns the minimum part that can appear at the `i^{th}` position of
        any list produced.

        EXAMPLES::

            sage: C = IntegerLists(4, length=2, min_part=1)
            sage: C.floor(0)
            1
            sage: C = IntegerLists(4, length=2, floor=[1,2])
            sage: C.floor(0)
            1
            sage: C.floor(1)
            2
        """
        return self.get_floor_ceil(i)[0]

    def ceiling(self, i):
        """
        Returns the maximum part that can appear in the `i^{th}`
        position in any list produced.

        EXAMPLES::

            sage: C = IntegerLists(4, length=2, max_part=3)
            sage: C.ceiling(0)
            3
            sage: C = IntegerLists(4, length=2, ceiling=[3,2])
            sage: C.ceiling(0)
            3
            sage: C.ceiling(1)
            2
        """
        return self.get_floor_ceil(i)[1]

    def get_floor_ceil(self, Py_ssize_t i):
        """
        Compute ``self.floor_list`` and ``self.ceil_list`` until at
        least position ``i`` and return
        ``(self.floor_list[i], self.ceil_list[i])``.
        """
        if i < 0:
            raise IndexError

        cdef Py_ssize_t n = len(self.floor_list)
        assert n == len(self.ceil_list)

        while n <= i:
            floor_sum = sum(self.floor_list)
            ceil_sum = sum(self.ceil_list)

            # Compute floor_list[n] and ceil_list[n]
            p = self.min_part
            p = max(p, next(self.floor_iter, p))
            if n > 0:
                p = max(p, self.floor_list[n-1] + self.min_slope)
            if self.max_part <= 0:
                # Total sum of *other* parts is at most ceil_sum
                p = max(p, self.min_sum - ceil_sum)
            self.floor_list.append(p)

            p = self.max_part
            p = min(p, next(self.ceil_iter, p))
            if n > 0:
                p = min(p, self.ceil_list[n-1] + self.max_slope)
            if self.min_part >= 0:
                # Total sum of *other* parts is at least floor_sum
                p = min(p, self.max_sum - floor_sum)
            self.ceil_list.append(p)

            n += 1

        return (self.floor_list[i], self.ceil_list[i])

    def _polyhedron_ieqs(self, Py_ssize_t length, Py_ssize_t sumlength, Py_ssize_t dimension):
        """
        Return a list of inequalities for the :class:`Polyhedron`
        constructor.

        INPUT:

        - ``length`` -- length of sequence to generate inequalities
          for: the first ``length`` variables will have inequalities
          involving floor/ceiling and will have bounds on their slopes.

        - ``sumlength`` -- number of variables to use for sum
          inequalities: the first ``sumlength`` variables will be
          summed.

        - ``dimension`` -- ambient dimension of the target polyhedron,
          i.e. number of variables to use.

        OUTPUT:

        - if the polyhedron is trivially empty, return ``None``
        
        - otherwise, a list of inequalities (really, lists of length
        ``dimension+1``)
        """
        assert 0 <= length <= dimension
        assert 0 <= sumlength <= dimension

        cdef list ieqs = []
        cdef list e
        cdef Py_ssize_t i

        # Inequalities for floor/ceiling
        for i in range(length):
            f, c = self.get_floor_ceil(i)
            if f >= c+1:
                # Contradiction: all polyhedra of length > i must be empty.
                # Note: the +1 in the formula above makes this work even
                # if floor and ceiling are both +/- infinity
                self.effective_max_length = min(self.effective_max_length, i)
                return None
            e = [0] * dimension
            e[i] = 1
            ieqs.append([-f] + e)
            e[i] = -1
            ieqs.append([c] + e)

        # Inequalties for slopes
        for i in range(length-1):
            e = [0] * dimension
            e[i+1] = 1
            e[i] = -1
            ieqs.append([-self.min_slope] + e)
            e[i+1] = -1
            e[i] = 1
            ieqs.append([self.max_slope] + e)

        # Inequalities for sum
        e = [1] * sumlength + [0] * (dimension - sumlength)
        ieqs.append([-self.min_sum] + e)
        e = [-1] * sumlength + [0] * (dimension - sumlength)
        ieqs.append([self.max_sum] + e)

        return ieqs

    @cached_method
    def polyhedron(self, Py_ssize_t length):
        """
        Return a polyhedron representing a list of integers of length
        ``length``. The polyhedron has one dimension for every part.

        Note: the length conditions are not checked. It returns a
        possibly non-empty polyhedron for all lengths.
        """
        if length < 0:
            raise ValueError("polyhedron dimension must be >= 0")

        cdef list ieqs = self._polyhedron_ieqs(length, length, length)
        if ieqs is None:
            # Empty polyhedron
            return Polyhedron(base_ring=QQ, ambient_dim=length)

        # Extra inequalities for last part if length more than minimum
        cdef list e
        if length > self.min_length:
            e = [0] * length
            e[length-1] = 1
            ieqs.append([-self.min_part_last] + e)
            e[length-1] = -1
            ieqs.append([self.max_part_last] + e)

        return Polyhedron_inf(ieqs=ieqs, base_ring=QQ)

    @cached_method
    def polyhedron_more(self, Py_ssize_t length):
        """
        Return a polyhedron representing a list of integers of length
        more than ``length``. The polyhedron has ``length+1`` dimensions,
        where the first ``length`` dimensions represent parts as usual,
        and the last dimension represents the sum of all additional
        parts.
        """
        if length < 0:
            raise ValueError("polyhedron dimension must be >= 0")

        # Start with empty polyhedron
        P = Polyhedron(base_ring=QQ, ambient_dim=length+1)

        cdef list ieqs0 = self._polyhedron_ieqs(length, length+1, length+1)
        if ieqs0 is None:
            return P

        # Instead of computing one polyhedron, we compute 3 and take
        # the convex hull: we compute one polyhedron for every choice of
        # sign (<0, =0, >0) of part "length-1".
        fa, ca = self.get_floor_ceil(length-1)
        cdef list e, ieqs
        cdef long sign
        for sign from -1 <= sign <= 1:
            # Floor/ceiling of part "length-1" keeping in mind sign
            f = fa if sign == -1 else max(fa, smallInteger(sign))
            c = ca if sign == 1 else min(ca, smallInteger(sign))
            if f >= c+1:
                continue

            # Limit of floor/ceiling for part index going to infinity
            flim = max(self.min_part, f + signed_infinity(self.min_slope))
            clim = min(self.max_part, c + signed_infinity(self.max_slope))

            # Bounds on last part (which has index >= length)
            flast = max(self.min_part_last, min(f+self.min_slope, flim))
            clast = min(self.max_part_last, max(c+self.max_slope, clim))
            if flast >= clast+1:
                continue

            # Sum of floors/ceilings
            if f < 0:
                if flim >= 0:
                    # The sum is actually a finite negative number,
                    # try again with a larger length!
                    self.try_length = max(self.try_length, length - f)
                fs = -infinity
            else:
                # Take only last part to get minimal sum
                fs = flast

            if c > 0:
                if clim <= 0:
                    self.try_length = max(self.try_length, length + c)
                cs = infinity
            else:
                cs = clast

            ieqs = ieqs0[:]

            # Inequalities for part "length-1"
            e = [0] * (length+1)
            e[length-1] = 1
            ieqs.append([-f] + e)
            e[length-1] = -1
            ieqs.append([c] + e)

            # Inequalities for parts >= length
            e = [0] * (length+1)
            e[length] = 1
            ieqs.append([-fs] + e)
            e[length] = -1
            ieqs.append([cs] + e)

            P = P.convex_hull(Polyhedron_inf(ieqs=ieqs, base_ring=QQ))

        return P

    def __iter__(self):
        """
        Returns an iterator for the elements of ``self``.

        EXAMPLES::

            sage: C = IntegerLists(2, length=3)
            sage: list(C) #indirect doctest
            [[2, 0, 0], [1, 1, 0], [1, 0, 1], [0, 2, 0], [0, 1, 1], [0, 0, 2]]
        """
        cdef list L = []

        # Iterate by length
        cdef Py_ssize_t length = self.min_length

        # Note: effective_max_length can change during this loop
        while length <= self.effective_max_length:
            sig_check()
            P = self.polyhedron(length)
            if length > self.try_length and P.is_empty():
                # Perhaps all following polyhedra are empty?
                Q = self.polyhedron_more(length)
                if Q.is_empty():
                    self.effective_max_length = min(self.effective_max_length, length-1)
                    continue
                elif length > self.try_length:  # Do nothing if try_length was increased
                    raise ValueError("no more lists found, but cannot prove that there are none of length > {}".format(length))
            elif not P.is_compact():
                raise ValueError("there seem to be infinitely many lists of length {}".format(length))

            if self.sort_lex:
                L += [x.list() for x in P.integral_points()]
            else:
                for x in P.integral_points():
                    yield self._element_constructor_(x.list())

            length += 1

        if self.sort_lex:
            L.sort(key=lambda t: [-a for a in t])
            for t in L:
                yield self._element_constructor_(t)


    def count(self):
        """
        Default brute force implementation of count by iteration
        through all the objects.

        Note that this skips the call to ``_element_constructor``, unlike
        the default implementation.

        .. TODO::

            Do the iteration in place to save on copying time

        EXAMPLES::

            sage: C = IntegerLists(2, length=3)
            sage: C.cardinality() == C.count()
            True
        """
        return self.cardinality()

    def __contains__(self, v):
        """
        Returns ``True`` if and only if ``v`` is in ``self``.

        EXAMPLES::

            sage: C = IntegerLists(2, length=3)
            sage: [2, 0, 0] in C
            True
            sage: [2, 0] in C
            False
            sage: [3, 0, 0] in C
            False
            sage: all(v in C for v in C)
            True
        """
        cdef Py_ssize_t length = len(v)
        if length < self.min_length or length > self.effective_max_length:
            return False
        return self.polyhedron(length).__contains__(v)
