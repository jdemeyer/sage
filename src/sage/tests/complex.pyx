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

def bench_fma_mpfr(RealNumber a, L, RealNumber c, long iterations):
    cdef RealNumber w = a._new()

    cdef mpfr_t B[100]
    cdef unsigned int i
    cdef RealNumber b

    for i in range(100):
        b = L[i]
        mpfr_init2(B[i], mpfr_get_prec(b.value))
        mpfr_set(B[i], b.value, GMP_RNDZ)

    while iterations > 0:
        for i in range(100):
            mpfr_fma(w.value, a.value, B[i], c.value, GMP_RNDN)
        iterations -= 100

def bench_fma_old(RealNumber a, L, RealNumber c, long iterations):
    cdef RealNumber w = a._new()

    cdef mpfr_t B[100]
    cdef unsigned int i
    cdef RealNumber b

    for i in range(100):
        b = L[i]
        mpfr_init2(B[i], mpfr_get_prec(b.value))
        mpfr_set(B[i], b.value, GMP_RNDZ)

    while iterations > 0:
        for i in range(100):
            mpfr_fma_old(w.value, a.value, B[i], c.value, GMP_RNDN)
        iterations -= 100

def bench_fma_noop(RealNumber a, L, RealNumber c, long iterations):
    cdef RealNumber u = a._new()
    cdef RealNumber w = a._new()

    cdef mpfr_t B[100]
    cdef unsigned int i
    cdef RealNumber b

    for i in range(100):
        b = L[i]
        mpfr_init2(B[i], mpfr_get_prec(b.value))
        mpfr_set(B[i], b.value, GMP_RNDZ)

    while iterations > 0:
        for i in range(100):
            mpfr_fma_noop(w.value, a.value, B[i], c.value, GMP_RNDN)
        iterations -= 100

def bench_fma_mul_add(RealNumber a, L, RealNumber c, long iterations):
    cdef RealNumber u = a._new()
    cdef RealNumber w = a._new()

    cdef mpfr_t B[100]
    cdef unsigned int i
    cdef RealNumber b

    for i in range(100):
        b = L[i]
        mpfr_init2(B[i], mpfr_get_prec(b.value))
        mpfr_set(B[i], b.value, GMP_RNDZ)

    while iterations > 0:
        for i in range(100):
            mpfr_mul(u.value, a.value, B[i], GMP_RNDN)
            mpfr_add(w.value, u.value, c.value, GMP_RNDN)
        iterations -= 100

def bench_add(RealNumber a, L, RealNumber c, long iterations):
    cdef mpfr_t B[100]
    cdef unsigned int i
    cdef RealNumber b

    for i in range(100):
        b = L[i]
        mpfr_init2(B[i], mpfr_get_prec(b.value))
        mpfr_set(B[i], b.value, GMP_RNDZ)

    while iterations > 0:
        for i in range(100):
            mpfr_add(a.value, B[i], c.value, GMP_RNDN)
        iterations -= 100
