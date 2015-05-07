from sage.misc.cython_metaclass cimport *
from cpython.object cimport PyTypeObject, newfunc


cdef class CustomNewDelMetaclass(type):
    def __init__(cls, *args):
        cdef PyTypeObject* t = <PyTypeObject*>cls
        try:
            m = cls.__new__
        except AttributeError:
            pass
        else:
            t.tp_new = <newfunc>PyMethodDescr_GetArgsKwdsFunction(m)


cdef class MetaA(type):
    def __getmetaclass__(_):
        return CustomNewDelMetaclass

    def __tpnew__(self, *args, **kwds):
        print "Calling MetaA.__new__({}) with args = {}".format(self, args)
        return (<PyTypeObject*>type).tp_new(self, args, kwds)

    def __cinit__(self, *args):
        print "Calling MetaA.__cinit__({}) with args = {}".format(self, args)

cdef class MetaB(type):
    def __cinit__(self, *args):
        print "Calling MetaB.__cinit__({}) with args = {}".format(self, args)

class A(object):
    __metaclass__ = MetaA

class B(object):
    __metaclass__ = MetaB
