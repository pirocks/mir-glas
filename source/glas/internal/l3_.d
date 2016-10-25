/++
Copyright: Ilya Yaroshenko 2016-.
License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Ilya Yaroshenko
+/
module glas.internal.l3_;

pragma(LDC_no_moduleinfo);

import std.experimental.ndslice.slice: Slice;
import ldc.intrinsics: llvm_expect;

import glas.ndslice;
import glas.fortran;

import glas.internal.utility;

package(glas) enum L3(Type) =
q{
    pragma(LDC_no_moduleinfo);


    import std.experimental.ndslice.slice: Slice;
    import ldc.attributes;
    import ldc.intrinsics: llvm_expect;
    import glas.ndslice;
    import glas.fortran;
    import glas.internal.utility;


    private alias T = } ~ Type.stringof ~ q{;

    export extern(C) @system nothrow @nogc pragma(inline, false):

    void glas_} ~ prefix!Type ~ q{gemm
        (
            T alpha,
                Slice!(2, const(T)*) asl,
                Slice!(2, const(T)*) bsl,
            T beta,
                Slice!(2,        T*) csl,
            ulong settings,
        )
    {
        import glas.internal.gemm: gemm_impl;
        gemm_impl(alpha, asl, bsl, beta, csl, settings);
    }

    void glas_} ~ prefix!Type ~ q{symm
        (
            T alpha,
                Slice!(2, const(T)*) asl,
                Slice!(2, const(T)*) bsl,
            T beta,
                Slice!(2,        T*) csl,
            ulong settings,
        )
    {
        import glas.internal.symm: symm_impl;
        symm_impl(alpha, asl, bsl, beta, csl, settings);
    }

    int } ~ prefix!Type ~ q{gemm_(
        ref const char transa,
        ref const char transb,
        ref const 

        FortranInt m,
        ref const 

        FortranInt n,
        ref const 

        FortranInt k,
        ref const T alpha,
            const(T)* a,
            ref const FortranInt lda,
            const(T)* b,
            ref const FortranInt ldb,
        ref const T beta,
            T* c,
            ref const FortranInt ldc,
        )
    {
        auto  tra = toUpper(transa);
        auto  trb = toUpper(transb);

        auto nota = tra == 'N';
        auto notb = trb == 'N';
        auto conja = tra == 'C';
        auto conjb = trb == 'C';

        
        FortranInt info = void;
        
        if (llvm_expect(!nota && !conja && tra != 'T', false))
            info = 1;
        else
        if (llvm_expect(!notb && !conjb && trb != 'T', false))
            info = 2;
        else
        if (llvm_expect(m < 0, false))
            info = 3;
        else
        if (llvm_expect(n < 0, false))
            info = 4;
        else
        if (llvm_expect(k < 0, false))
            info = 5;
        else
        if (llvm_expect(lda < max(1, nota ? m : k), false))
            info = 8;
        else
        if (llvm_expect(ldb < max(1, notb ? k : n), false))
            info = 10;
        else
        if (llvm_expect(ldc < max(1, m), false))
            info = 13;
        else
        {
            static if (__VERSION__ < 2072)
            {
                auto asl = _toSlice!(2, const(T)*)([m, k], nota ? [1, lda] : [lda, 1], a);
                auto bsl = _toSlice!(2, const(T)*)([k, n], notb ? [1, ldb] : [ldb, 1], b);
                auto csl = _toSlice!(2,       T *)([m, n],        [1, ldc],            c);
            }
            else
            {
                auto asl = Slice!(2, const(T)*)([m, k], nota ? [1, lda] : [lda, 1], a);
                auto bsl = Slice!(2, const(T)*)([k, n], notb ? [1, ldb] : [ldb, 1], b);
                auto csl = Slice!(2,       T *)([m, n],        [1, ldc],            c);
            }
            ulong settings;
            static if (isComplex!T)
            {
                if (conja)
                    settings ^= ConjA;
                if (conjb)
                    settings ^= ConjB;
            }
            glas.ndslice.gemm(alpha, asl, bsl, beta, csl, settings);
            return 0;
        }
        enum name = prefix!T ~ "GEMM";
        xerbla_(name.ptr, info);
        return 0;
    }

    int } ~ prefix!Type ~ q{symm_(
        ref const char side,
        ref const char uplo,
        ref const 

        FortranInt m,
        ref const 

        FortranInt n,
        ref const T alpha,
            const(T)* a,
            ref const FortranInt lda,
            const(T)* b,
            ref const FortranInt ldb,
        ref const T beta,
            T* c,
            ref const FortranInt ldc,
        )
    {
        return symm_impl_(side, uplo, m, n, alpha, a, lda, b, ldb, beta, c, ldc, false);
    }

    static if (isComplex!T)
    int } ~ prefix!Type ~ q{hemm_(
        ref const char side,
        ref const char uplo,
        ref const 

        FortranInt m,
        ref const 

        FortranInt n,
        ref const T alpha,
            const(T)* a,
            ref const FortranInt lda,
            const(T)* b,
            ref const FortranInt ldb,
        ref const T beta,
            T* c,

            ref const FortranInt ldc,
        )
    {
        return symm_impl_(side, uplo, m, n, alpha, a, lda, b, ldb, beta, c, ldc, true);
    }
};


pragma(inline, true)
package(glas) auto toUpper()(dchar c)
{
    return dchar(c & 0b1101_1111);
}

pragma(inline, true)
package(glas) auto max()(FortranInt a, FortranInt b)
{
    return a > b ? a : b;
}

@system nothrow @nogc pragma(inline, true)
package(glas) int symm_impl_(T)(
    ref const char side,
    ref const char uplo,
    ref const FortranInt m,
    ref const FortranInt n,
    ref const T alpha,
        const(T)* a,
        ref const FortranInt lda,
        const(T)* b,
        ref const FortranInt ldb,
    ref const T beta,
        T* c,
        ref const FortranInt ldc,
    bool conj,
    )
{
    auto  _side = toUpper(side);
    auto  _uplo = toUpper(uplo);
    auto s = _side != 'L';
    auto u = _uplo != 'L';

    auto k = s ? n : m;

    
    FortranInt info = 0;

    if (llvm_expect(s && _side != 'R', false))
        info = 1;
    else
    if (llvm_expect(u && _uplo != 'U', false))
        info = 2;
    else
    if (llvm_expect(m < 0, false))
        info = 3;
    else
    if (llvm_expect(n < 0, false))
        info = 4;
    else
    if (llvm_expect(lda < max(1, k), false))
        info = 7;
    else
    if (llvm_expect(ldb < max(1, m), false))
        info = 9;
    else
    if (llvm_expect(ldc < max(1, m), false))
        info = 12;
    else
    {
        static if (__VERSION__ < 2072)
        {
            auto asl = _toSlice!(2, const(T)*)([k, k], [1, lda], a);
            auto bsl = _toSlice!(2, const(T)*)([m, n], [1, ldb], b);
            auto csl = _toSlice!(2,       T *)([m, n], [1, ldc], c);
        }
        else
        {
            auto asl = Slice!(2, const(T)*)([k, k], [1, lda], a);
            auto bsl = Slice!(2, const(T)*)([m, n], [1, ldb], b);
            auto csl = Slice!(2,       T *)([m, n], [1, ldc], c);
        }
        ulong settings;
        static if (isComplex!T)
        {
            if (conj)
                settings ^= ConjA;
        }
        if (u)
            settings ^= Upper;
        if (s)
            settings ^= Right;
        glas.ndslice.symm(alpha, asl, bsl, beta, csl, settings);
        return 0;
    }
    enum nameSYMM = prefix!T ~ "SYMM";
    enum nameHEMM = prefix!T ~ "HEMM";
    xerbla_(conj ? nameHEMM.ptr : nameSYMM.ptr, info);
    return 0;
}