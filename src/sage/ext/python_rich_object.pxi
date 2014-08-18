from cpython.ref cimport PyObject, PyTypeObject

cdef extern from "Python.h":
    ctypedef void _typeobject
    ctypedef void (*freefunc)(void *)
    ctypedef void (*destructor)(PyObject *)
    ctypedef long (*hashfunc)(PyObject *) except -1
    ctypedef PyObject *(*richcmpfunc) (PyObject *, PyObject *, int) except NULL
    ctypedef PyObject *(*newfunc)(PyTypeObject *, PyObject *, PyObject *) except NULL
    ctypedef PyObject *(*allocfunc)(PyTypeObject *, Py_ssize_t) except NULL

    # We need a PyTypeObject with elements so we can
    # get and set tp_new, tp_dealloc, tp_flags, and tp_basicsize
    ctypedef struct RichPyTypeObject "PyTypeObject":
        allocfunc tp_alloc
        newfunc tp_new
        freefunc tp_free
        destructor tp_dealloc
        hashfunc tp_hash
        richcmpfunc tp_richcompare

        #sizeof(Object)
        Py_ssize_t tp_basicsize

        long tp_flags


    cdef long Py_TPFLAGS_HAVE_GC

    # Allocation
    PyObject* PyObject_MALLOC(int)

    # Free
    void PyObject_FREE(PyObject*)
