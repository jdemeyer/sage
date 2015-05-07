cdef extern from "sage/misc/cython_metaclass.h":
    ctypedef object (*PyCFunction)(self, args)
    ctypedef object (*PyCFunctionWithKeywords)(self, args, kwds)
    object PyMethodDescr_CallSelf(desc, self)
    PyCFunctionWithKeywords PyMethodDescr_GetArgsKwdsFunction(desc)
