"""
Handle PARI documentation for Sage
"""

import re
from subprocess import check_output

leading_ws = re.compile("^ +", re.MULTILINE)
double_space = re.compile("  +")

end_space = re.compile(r"(@\[end[a-z]*\])([A-Za-z])")

begin_verb = re.compile(r"@1")
end_verb = re.compile(r"@[23] *@\[endcode\]")
verb_loop = re.compile("^(    .*)@\[[a-z]*\]", re.MULTILINE)

dollars = re.compile(r"@\[dollar\]\s*(.*?)\s*@\[dollar\]", re.DOTALL)

math_loop = re.compile(r"(@\[startMATH\][^@]*)@\[[a-z]*\]")

prototype = re.compile("^[^\n]*\n\n")
library_syntax = re.compile("The library syntax is.*", re.DOTALL)

newlines = re.compile("\n\n\n\n*")

bullet_loop = re.compile("(@BULLET(  [^\n]*\n)*)([^ \n])")

escape_backslash = re.compile(r"^(\S.*)\\", re.MULTILINE)
escape_mid = re.compile(r"^(\S.*)[|]", re.MULTILINE)


def sub_loop(regex, repl, text):
    """
    In ``text``, substitute ``regex`` by ``repl`` recursively. As long
    as substitution is possible, ``regex`` is substituted.

    INPUT:

    - ``regex`` -- a compiled regular expression

    - ``repl`` -- replacement text

    - ``text`` -- input text

    OUTPUT: substituted text

    EXAMPLES:

    Ensure there a space between any 2 letters ``x``::

        sage: from sage_setup.autogen.pari.doc import sub_loop
        sage: import re
        sage: sub_loop(re.compile("xx"), "x x", "xxx_xx")
        'x x x_x x'
    """
    while True:
        text, n = regex.subn(repl, text)
        if not n:
            return text


def raw_to_rest(doc):
    """
    Convert raw PARI documentation (with ``@``-codes) to reST syntax.

    INPUT:

    - ``doc`` -- the raw PARI documentation

    OUTPUT: a unicode string
    """
    doc = unicode(doc)

    # Basic search-and-replace
    doc = doc.replace("@[lt]", "<")
    doc = doc.replace("@[gt]", ">")
    doc = doc.replace("@[pm]", "+-")
    doc = doc.replace("@[nbrk]", unichr(0xa0))
    doc = doc.replace("@[agrave]", unichr(0xe0))
    doc = doc.replace("@[eacute]", unichr(0xe9))
    doc = doc.replace("@[ouml]", unichr(0xf6))
    doc = doc.replace("@[uuml]", unichr(0xfc))
    doc = doc.replace("\\'{a}", unichr(0xe1))

    # Remove leading whitespace from every line
    doc = leading_ws.sub("", doc)

    # Remove multiple spaces
    doc = double_space.sub(" ", doc)

    # Sphinx dislikes inline markup immediately followed by a letter:
    # insert a non-breaking space
    doc = end_space.sub("\\1" + unichr(0xa0) + "\\2", doc)

    # Bullet items
    doc = doc.replace("@3@[startbold]*@[endbold] ", "@BULLET  ")
    doc = sub_loop(bullet_loop, "\\1  \\3", doc)
    doc = doc.replace("@BULLET  ", "- ")

    # Verbatim blocks
    doc = begin_verb.sub("::\n\n@0", doc)
    doc = end_verb.sub("", doc)
    doc = doc.replace("@0", "    ")
    doc = doc.replace("@3", "")

    # Remove all further markup from within verbatim blocks
    doc = sub_loop(verb_loop, "\\1", doc)

    # Replace (except in verbatim blocks)
    # \ -> \\
    # | -> \|
    doc = sub_loop(escape_backslash, "\\1@BACKSLASH", doc)
    doc = sub_loop(escape_mid, "\\1@MID", doc)
    doc = doc.replace("@BACKSLASH", "\\\\")
    doc = doc.replace("@MID", "\\|")

    # Pair dollars -> beginmath/endmath
    doc = dollars.sub(r"@[startMATH]\1@[endMATH]", doc)

    # Math markup
    doc = doc.replace("@[obr]", "{")
    doc = doc.replace("@[cbr]", "}")
    doc = doc.replace("@[startword]", "\\")
    doc = doc.replace("@[endword]", "")
    doc = doc.replace("@[startlword]", "\\")
    doc = doc.replace("@[endlword]", "")
    doc = doc.replace("@[startbi]", "\\mathbb{")
    doc = doc.replace("@[endbi]", "}")

    # Remove extra markup inside math blocks
    doc = sub_loop(math_loop, "\\1", doc)

    # Inline markup. We do use the more verbose :foo:`text` style since
    # those nest more easily.
    doc = doc.replace("@[startMATH]", ":math:`")
    doc = doc.replace("@[endMATH]", "`")
    doc = doc.replace("@[startpodcode]", "``")
    doc = doc.replace("@[endpodcode]", "``")
    doc = doc.replace("@[startcode]", ":literal:`")
    doc = doc.replace("@[endcode]", "`")
    doc = doc.replace("@[startit]", ":emphasis:`")
    doc = doc.replace("@[endit]", "`")
    doc = doc.replace("@[startbold]", ":strong:`")
    doc = doc.replace("@[endbold]", "`")

    # Remove prototype
    doc = prototype.sub("", doc)

    # Remove everything after "The library syntax is"
    doc = library_syntax.sub("", doc)

    # Allow at most 2 consecutive newlines
    doc = newlines.sub("\n\n", doc)

    # Strip result
    doc = doc.strip()

    # Ensure no more @ remains
    try:
        i = doc.index("@")
    except ValueError:
        return doc
    ilow = max(0, i-30)
    ihigh = min(len(doc), i+30)
    raise SyntaxError("@ found: " + repr(doc[ilow:ihigh]))


def get_raw_doc(function):
    r"""
    Get the raw documentation of PARI function ``function``.

    INPUT:

    - ``function`` -- name of a PARI function

    EXAMPLES::

        sage: from sage_setup.autogen.pari.doc import get_raw_doc
        sage: get_raw_doc("cos")
        '@[startbold]cos@[dollar](x)@[dollar]:@[endbold]\n\n\n\nCosine of @[dollar]x@[dollar].\n\n\nThe library syntax is @[startcode]GEN @[startbold]gcos@[endbold](GEN x, long prec)@[endcode].\n\n\n'
        sage: get_raw_doc("abcde")
        Traceback (most recent call last):
        ...
        RuntimeError: no help found for 'abcde'
    """
    doc = check_output(["gphelp", "-raw", function])
    if doc.endswith("""' not found !\n"""):
        raise RuntimeError("no help found for {!r}".format(function))
    return doc


def get_rest_doc(function):
    r"""
    Get the documentation of the PARI function ``function`` in reST
    syntax.

    INPUT:

    - ``function`` -- name of a PARI function

    EXAMPLES::

        sage: from sage_setup.autogen.pari.doc import get_rest_doc
        sage: get_rest_doc("cos")
        u'Cosine of :math:`x`.'
        sage: print get_rest_doc("ellap")
        Let :math:`E` be an :emphasis:`ell` structure as output by :literal:`ellinit`, defined over
        :math:`\mathbb{Q}` or a finite field :math:`\mathbb{F}_q`. The argument :math:`p` is best left omitted if the
        curve is defined over a finite field, and must be a prime number otherwise.
        This function computes the trace of Frobenius :math:`t` for the elliptic curve :math:`E`,
        defined by the equation :math:`#E(\mathbb{F}_q) = q+1 - t`.
        <BLANKLINE>
        If the curve is defined over :math:`\mathbb{Q}`, :math:`p` must be explicitly given and the
        function computes the trace of the reduction over :math:`\mathbb{F}_p`.
        The trace of Frobenius is also the :math:`a_p` coefficient in the curve :math:`L`-series
        :math:`L(E,s) = \sum_n a_n n^{-s}`, whence the function name. The equation must be
        integral at :math:`p` but need not be minimal at :math:`p`; of course, a minimal model
        will be more efficient.
        <BLANKLINE>
        ::
        <BLANKLINE>
            ? E = ellinit([0,1]); \\\\ y^2 = x^3 + 0.x + 1, defined over Q
            ? ellap(E, 7) \\\\ 7 necessary here
            %2 = -4 \\\\ #E(F_7) = 7+1-(-4) = 12
            ? ellcard(E, 7)
            %3 = 12 \\\\ OK
        <BLANKLINE>
            ? E = ellinit([0,1], 11); \\\\ defined over F_11
            ? ellap(E) \\\\ no need to repeat 11
            %4 = 0
            ? ellap(E, 11) \\\\ ... but it also works
            %5 = 0
            ? ellgroup(E, 13) \\\\ ouch, inconsistent input!
             *** at top-level: ellap(E,13)
             *** ^-----------
             *** ellap: inconsistent moduli in Rg_to_Fp:
             11
             13
        <BLANKLINE>
            ? Fq = ffgen(ffinit(11,3), 'a); \\\\ defines F_q := F_{11^3}
            ? E = ellinit([a+1,a], Fq); \\\\ y^2 = x^3 + (a+1)x + a, defined over F_q
            ? ellap(E)
            %8 = -3
        <BLANKLINE>
        :strong:`Algorithms used.` If :math:`E/\mathbb{F}_q` has CM by a principal imaginary
        quadratic order we use a fast explicit formula (involving essentially Kronecker
        symbols and Cornacchia's algorithm), in :math:`O(\log q)^2`.
        Otherwise, we use Shanks-Mestre's baby-step/giant-step method, which runs in
        time :math:`~{O}(q^{1/4})` using :math:`~{O}(q^{1/4})` storage, hence becomes
        unreasonable when :math:`q` has about 30...digits. If the :literal:`seadata` package is
        installed, the :literal:`SEA` algorithm becomes available, heuristically in
        :math:`~{O}(\log q)^4`, and primes of the order of 200...digits become feasible.
        In very small characteristic (2,3,5,7 or :math:`13`), we use Harley's algorithm.
    """
    raw = get_raw_doc(function)
    try:
        return raw_to_rest(raw)
    except BaseException as e:
        raise RuntimeError("failed to convert doc of {!r}: {}".format(function, e))
