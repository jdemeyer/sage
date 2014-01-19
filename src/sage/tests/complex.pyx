from sage.rings.complex_number cimport ComplexNumber
from sage.rings.complex_mpc cimport MPComplexNumber
from sage.rings.real_mpfr cimport RealNumber
from sage.libs.mpfr cimport *
include 'sage/rings/mpc.pxi'

import sys

def bench_mul_complex_number(ComplexNumber b, ComplexNumber c, long iterations):
    cdef ComplexNumber a

    while iterations > 0:
        a = b._mul_(c)
        iterations -= 1

def bench_mul_complex_mpcsage(MPComplexNumber b, MPComplexNumber c, long iterations):
    cdef MPComplexNumber a

    while iterations > 0:
        a = b._mul_(c)
        iterations -= 1

def bench_mul_complex_mpc(MPComplexNumber b, MPComplexNumber c, long iterations):
    cdef MPComplexNumber a = b._new()

    while iterations > 0:
        mpc_mul(a.value, b.value, c.value, MPC_RNDNN)
        iterations -= 1
