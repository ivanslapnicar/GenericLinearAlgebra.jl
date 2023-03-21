module LAPACK2

using libblastrampoline_jll
using LinearAlgebra
using LinearAlgebra: BlasInt, chkstride1, LAPACKException
using LinearAlgebra.BLAS: @blasfunc
using LinearAlgebra.LAPACK: chkdiag, chkside, chkuplo

liblapack_name = libblastrampoline_jll.libblastrampoline

## Standard QR/QL
function steqr!(
    compz::Char,
    d::StridedVector{Float64},
    e::StridedVector{Float64},
    Z::StridedMatrix{Float64} = compz == 'N' ? Matrix{Float64}(undef, 0, 0) :
                                Matrix{Float64}(undef, length(d), length(d)),
    work::StridedVector{Float64} = compz == 'N' ? Vector{Float64}(undef, 0) :
                                   Vector{Float64}(undef, max(1, 2 * length(d) - 2)),
)

    # Extract sizes
    n = length(d)
    ldz = stride(Z, 2)

    # Checks
    length(e) + 1 == n || throw(DimensionMismatch(""))
    if compz == 'N'
    elseif compz in ('V', 'I')
        chkstride1(Z)
        n <= size(Z, 1) || throw(DimensionMismatch("Z matrix has too few rows"))
        n <= size(Z, 2) || throw(DimensionMismatch("Z matrix has too few colums"))
    else
        throw(ArgumentError("compz must be either 'N', 'V', or 'I'"))
    end

    # Allocations
    info = Vector{BlasInt}(undef, 1)

    ccall(
        (@blasfunc("dsteqr_"), liblapack_name),
        Cvoid,
        (
            Ref{UInt8},
            Ref{BlasInt},
            Ptr{Float64},
            Ptr{Float64},
            Ptr{Float64},
            Ref{BlasInt},
            Ptr{Float64},
            Ptr{BlasInt},
        ),
        compz,
        n,
        d,
        e,
        Z,
        max(1, ldz),
        work,
        info,
    )
    info[1] == 0 || throw(LAPACKException(info[1]))

    return d, Z
end

## Square root free QR/QL (values only, but fast)
function sterf!(d::StridedVector{Float64}, e::StridedVector{Float64})

    # Extract sizes
    n = length(d)

    # Checks
    length(e) >= n - 1 || throw(DimensionMismatch("subdiagonal is too short"))

    # Allocations
    info = BlasInt[0]

    ccall(
        (@blasfunc("dsterf_"), liblapack_name),
        Cvoid,
        (Ref{BlasInt}, Ptr{Float64}, Ptr{Float64}, Ptr{BlasInt}),
        n,
        d,
        e,
        info,
    )

    info[1] == 0 || throw(LAPACKException(info[1]))

    d
end

## Divide and Conquer
function stedc!(
    compz::Char,
    d::StridedVector{Float64},
    e::StridedVector{Float64},
    Z::StridedMatrix{Float64},
    work::StridedVector{Float64},
    lwork::BlasInt,
    iwork::StridedVector{BlasInt},
    liwork::BlasInt,
)

    # Extract sizes
    n = length(d)
    ldz = stride(Z, 2)

    # Checks
    length(e) + 1 == n || throw(DimensionMismatch(""))
    # length(work)
    # length(lwork)

    # Allocations
    info = BlasInt[0]

    ccall(
        (@blasfunc("dstedc_"), liblapack_name),
        Cvoid,
        (
            Ref{UInt8},
            Ref{BlasInt},
            Ptr{Float64},
            Ptr{Float64},
            Ptr{Float64},
            Ref{BlasInt},
            Ptr{Float64},
            Ref{BlasInt},
            Ptr{BlasInt},
            Ref{BlasInt},
            Ptr{BlasInt},
        ),
        compz,
        n,
        d,
        e,
        Z,
        max(1, ldz),
        work,
        lwork,
        iwork,
        liwork,
        info,
    )

    info[1] == 0 || throw(LAPACKException(info[1]))

    return d, Z
end

function stedc!(
    compz::Char,
    d::StridedVector{Float64},
    e::StridedVector{Float64},
    Z::StridedMatrix{Float64} = compz == 'N' ? Matrix{Float64}(undef, 0, 0) :
                                Matrix{Float64}(undef, length(d), length(d)),
)

    work::Vector{Float64} = Float64[0]
    iwork::Vector{BlasInt} = BlasInt[0]
    stedc!(compz, d, e, Z, work, -1, iwork, -1)

    lwork::BlasInt = work[1]
    work = Vector{Float64}(undef, lwork)
    liwork = iwork[1]
    iwork = Vector{BlasInt}(undef, liwork)

    return stedc!(compz, d, e, Z, work, lwork, iwork, liwork)
end

## RRR
for (lsymb, elty) in ((:dstemr_, :Float64), (:sstemr_, :Float32))
    @eval begin
        function stemr!(
            jobz::Char,
            range::Char,
            dv::StridedVector{$elty},
            ev::StridedVector{$elty},
            vl::$elty,
            vu::$elty,
            il::BlasInt,
            iu::BlasInt,
            w::StridedVector{$elty},
            Z::StridedMatrix{$elty},
            nzc::BlasInt,
            isuppz::StridedVector{BlasInt},
            work::StridedVector{$elty},
            lwork::BlasInt,
            iwork::StridedVector{BlasInt},
            liwork::BlasInt,
        )

            # Extract sizes
            n = length(dv)
            ldz = stride(Z, 2)

            # Checks
            length(ev) >= n - 1 || throw(DimensionMismatch("subdiagonal is too short"))

            # Allocations
            eev::Vector{$elty} = length(ev) == n - 1 ? [ev; zero($elty)] : copy(ev)
            abstol = Vector{$elty}(undef, 1)
            m = Vector{BlasInt}(undef, 1)
            tryrac = BlasInt[1]
            info = Vector{BlasInt}(undef, 1)

            ccall(
                (@blasfunc($lsymb), liblapack_name),
                Cvoid,
                (
                    Ref{UInt8},
                    Ref{UInt8},
                    Ref{BlasInt},
                    Ptr{$elty},
                    Ptr{$elty},
                    Ref{$elty},
                    Ref{$elty},
                    Ref{BlasInt},
                    Ref{BlasInt},
                    Ptr{BlasInt},
                    Ptr{$elty},
                    Ptr{$elty},
                    Ref{BlasInt},
                    Ref{BlasInt},
                    Ptr{BlasInt},
                    Ptr{BlasInt},
                    Ptr{$elty},
                    Ref{BlasInt},
                    Ptr{BlasInt},
                    Ref{BlasInt},
                    Ptr{BlasInt},
                ),
                jobz,
                range,
                n,
                dv,
                eev,
                vl,
                vu,
                il,
                iu,
                m,
                w,
                Z,
                max(1, ldz),
                nzc,
                isuppz,
                tryrac,
                work,
                lwork,
                iwork,
                liwork,
                info,
            )

            info[1] == 0 || throw(LAPACKException(info[1]))

            w, Z, tryrac[1]
        end

        function stemr!(
            jobz::Char,
            range::Char,
            dv::StridedVector{$elty},
            ev::StridedVector{$elty},
            vl::$elty = typemin($elty),
            vu::$elty = typemax($elty),
            il::BlasInt = 1,
            iu::BlasInt = length(dv),
        )

            n = length(dv)
            w = Vector{$elty}(undef, n)
            if jobz == 'N'
                # Z = Matrix{$elty}(0, 0)
                nzc::BlasInt = 0
                isuppz = Vector{BlasInt}(undef, 0)
            elseif jobz == 'V'
                nzc = -1
                isuppz = similar(dv, BlasInt, 2n)
            else
                throw(ArgumentError("jobz must be either 'N' or 'V'"))
            end

            work = Vector{$elty}(undef, 1)
            lwork::BlasInt = -1
            iwork = BlasInt[0]
            liwork::BlasInt = -1
            Z = Matrix{$elty}(undef, jobz == 'N' ? 1 : n, 1)
            nzc = -1

            stemr!(
                jobz,
                range,
                dv,
                ev,
                vl,
                vu,
                il,
                iu,
                w,
                Z,
                nzc,
                isuppz,
                work,
                lwork,
                iwork,
                liwork,
            )

            lwork = work[1]
            work = Vector{$elty}(undef, lwork)
            liwork = iwork[1]
            iwork = Vector{BlasInt}(undef, liwork)
            nzc = Z[1]
            Z = similar(dv, $elty, n, nzc)

            return stemr!(
                jobz,
                range,
                dv,
                ev,
                vl,
                vu,
                il,
                iu,
                w,
                Z,
                nzc,
                isuppz,
                work,
                lwork,
                iwork,
                liwork,
            )
        end
    end
end

# Non-symmetric eigenvalue problem
function lahqr!(
    wantt::Bool,
    wantz::Bool,
    H::StridedMatrix{Float64},
    ilo::Integer,
    ihi::Integer,
    wr::StridedVector{Float64},
    wi::StridedVector{Float64},
    iloz::Integer,
    ihiz::Integer,
    Z::StridedMatrix{Float64},
)
    # SUBROUTINE DLAHQR( WANTT, WANTZ, N, ILO, IHI, H, LDH, WR, WI,
    #                         ILOZ, IHIZ, Z, LDZ, INFO )

    #      .. Scalar Arguments ..
    #      INTEGER            IHI, IHIZ, ILO, ILOZ, INFO, LDH, LDZ, N
    #      LOGICAL            WANTT, WANTZ
    #      ..
    #      .. Array Arguments ..
    #      DOUBLE PRECISION   H( LDH, * ), WI( * ), WR( * ), Z( LDZ, * )

    n = LinearAlgebra.checksquare(H)
    ldh = stride(H, 2)
    ldz = stride(Z, 2)

    info = Ref{BlasInt}(0)

    ccall(
        (@blasfunc("dlahqr_"), liblapack_name),
        Cvoid,
        (
            Ref{BlasInt},
            Ref{BlasInt},
            Ref{BlasInt},
            Ref{BlasInt},
            Ref{BlasInt},
            Ptr{Float64},
            Ref{BlasInt},
            Ptr{Float64},
            Ptr{Float64},
            Ref{BlasInt},
            Ref{BlasInt},
            Ptr{Float64},
            Ref{BlasInt},
            Ptr{BlasInt},
        ),
        wantt,
        wantz,
        n,
        ilo,
        ihi,
        H,
        max(1, ldh),
        wr,
        wi,
        iloz,
        ihiz,
        Z,
        max(1, ldz),
        info,
    )

    if info[] != 0
        throw(LAPACKException(info[]))
    end

    return wr, wi, Z
end
function lahqr!(H::StridedMatrix{Float64})
    n = size(H, 1)
    return lahqr!(
        false,
        false,
        H,
        1,
        n,
        Vector{Float64}(undef, n),
        Vector{Float64}(undef, n),
        1,
        1,
        Matrix{Float64}(undef, 0, 0),
    )
end

## Cholesky + singular values
function spteqr!(
    compz::Char,
    d::StridedVector{Float64},
    e::StridedVector{Float64},
    Z::StridedMatrix{Float64},
    work::StridedVector{Float64} = Vector{Float64}(undef, 4length(d)),
)

    n = length(d)
    ldz = stride(Z, 2)

    # Checks
    length(e) >= n - 1 || throw(DimensionMismatch("subdiagonal vector is too short"))
    if compz == 'N'
    elseif compz == in('V', 'I')
        size(Z, 1) >= n || throw(DimensionMismatch("Z does not have enough rows"))
        size(Z, 2) >= ldz || throw(DimensionMismatch("Z does not have enough columns"))
    else
        throw(ArgumentError("compz must be either 'N', 'V', or 'I'"))
    end

    info = Vector{BlasInt}(undef, 1)

    ccall(
        (@blasfunc(:dpteqr_), liblapack_name),
        Cvoid,
        (
            Ref{UInt8},
            Ref{BlasInt},
            Ptr{Float64},
            Ptr{Float64},
            Ptr{Float64},
            Ref{BlasInt},
            Ptr{Float64},
            Ptr{BlasInt},
        ),
        compz,
        n,
        d,
        e,
        Z,
        max(1, ldz),
        work,
        info,
    )

    info[1] == 0 || throw(LAPACKException(info[1]))

    d, Z
end

# Gu's dnc eigensolver
for (f, elty) in ((:dsyevd_, :Float64), (:ssyevd_, :Float32))

    @eval begin
        function syevd!(jobz::Char, uplo::Char, A::StridedMatrix{$elty})
            n = LinearAlgebra.checksquare(A)
            lda = stride(A, 2)
            w = Vector{$elty}(undef, n)
            work = Vector{$elty}(undef, 1)
            lwork = BlasInt(-1)
            iwork = Vector{BlasInt}(undef, 1)
            liwork = BlasInt(-1)
            info = Ref(BlasInt(0))
            for i = 1:2
                ccall(
                    (@blasfunc($f), liblapack_name),
                    Cvoid,
                    (
                        Ref{UInt8},
                        Ref{UInt8},
                        Ref{BlasInt},
                        Ptr{$elty},
                        Ref{BlasInt},
                        Ptr{$elty},
                        Ptr{$elty},
                        Ref{BlasInt},
                        Ptr{BlasInt},
                        Ref{BlasInt},
                        Ref{BlasInt},
                    ),
                    jobz,
                    uplo,
                    n,
                    A,
                    lda,
                    w,
                    work,
                    lwork,
                    iwork,
                    liwork,
                    info,
                )

                if info[] != 0
                    return LinearAlgebra.LAPACKException(info[])
                end
                if i == 1
                    lwork = BlasInt(work[1])
                    resize!(work, lwork)
                    liwork = iwork[1]
                    resize!(iwork, liwork)
                end
            end
            return w, A
        end
    end
end
for (f, elty, relty) in
    ((:zheevd_, :ComplexF64, :Float64), (:cheevd_, :ComplexF32, :Float32))

    @eval begin
        function heevd!(jobz::Char, uplo::Char, A::StridedMatrix{$elty})
            n = LinearAlgebra.checksquare(A)
            lda = stride(A, 2)
            w = Vector{$relty}(undef, n)
            work = Vector{$elty}(undef, 1)
            lwork = BlasInt(-1)
            rwork = Vector{$relty}(undef, 1)
            lrwork = BlasInt(-1)
            iwork = Vector{BlasInt}(undef, 1)
            liwork = BlasInt(-1)
            info = Ref(BlasInt(0))
            for i = 1:2
                ccall(
                    (@blasfunc($f), liblapack_name),
                    Cvoid,
                    (
                        Ref{UInt8},
                        Ref{UInt8},
                        Ref{BlasInt},
                        Ptr{$elty},
                        Ref{BlasInt},
                        Ptr{$relty},
                        Ptr{$elty},
                        Ref{BlasInt},
                        Ptr{$relty},
                        Ref{BlasInt},
                        Ptr{BlasInt},
                        Ref{BlasInt},
                        Ref{BlasInt},
                    ),
                    jobz,
                    uplo,
                    n,
                    A,
                    lda,
                    w,
                    work,
                    lwork,
                    rwork,
                    lrwork,
                    iwork,
                    liwork,
                    info,
                )

                if info[] != 0
                    return LinearAlgebra.LAPACKException(info[])
                end

                if i == 1
                    lwork = BlasInt(work[1])
                    resize!(work, lwork)
                    lrwork = BlasInt(rwork[1])
                    resize!(rwork, lrwork)
                    liwork = iwork[1]
                    resize!(iwork, liwork)
                end
            end
            return w, A
        end
    end
end

# Generalized Eigen
## Eigenvectors of (pseudo) triangular matrices
for (f, elty) in ((:dtgevc_, :Float64), (:stgevc_, :Float32))

    @eval begin
        function tgevc!(
            side::Char,
            howmny::Char,
            select::Vector{BlasInt},
            S::StridedMatrix{$elty},
            P::StridedMatrix{$elty},
            VL::StridedMatrix{$elty},
            VR::StridedMatrix{$elty},
            work::Vector{$elty},
        )

            n = LinearAlgebra.checksquare(S)
            if LinearAlgebra.checksquare(P) != n
                throw(DimensionMismatch("the two matrices must have same size"))
            end

            lds, ldp, ldvl, ldvr = stride(S, 2), stride(P, 2), stride(VL, 2), stride(VR, 2)
            if side == 'L'
                mm = size(VL, 2)
                if size(VL, 1) != n
                    throw(
                        DimensionMismatch(
                            "first dimension of output is $size(VL, 1) but should be $n",
                        ),
                    )
                end
            elseif side == 'R'
                mm = size(VR, 2)
                if size(VR, 1) != n
                    throw(
                        DimensionMismatch(
                            "first dimension of output is $size(VR, 1) but should be $n",
                        ),
                    )
                end
            elseif side == 'B'
                mm = size(VL, 2)
                if mm != size(VR, 2)
                    throw(
                        DimensionMismatch(
                            "the matrices for storing the left and right eigenvectors must have the same number of columns when side == 'B'",
                        ),
                    )
                end
                if size(VL, 1) != n
                    throw(
                        DimensionMismatch(
                            "first dimension of output is $size(VL, 1) but should be $n",
                        ),
                    )
                end
            else
                if size(VR, 1) != n
                    throw(
                        DimensionMismatch(
                            "first dimension of output is $size(VR, 1) but should be $n",
                        ),
                    )
                end
                throw(ArgumentError("side must be either 'L', 'R', or 'B'"))
            end
            if howmny == 'A' || howmny == 'B'
                if mm != n
                    throw(
                        DimensionMismatch(
                            "the number of columns in the output matrices are $mm, but should be $n",
                        ),
                    )
                end
            elseif howmny == 'S'
                mx, mn = extrema(select)
                if mx > 1 || mn < 0
                    throw(ArgumentError("the elements of select must be either 0 or 1"))
                end
                if sum(select) != mm
                    throw(
                        DimensionMismatch(
                            "the number of columns in the output arrays is $mm, but you have selected $(sum(select)) vectors",
                        ),
                    )
                end
            else
                throw(ArgumentError("howmny must be either A, B, or S but was $howmny"))
            end

            m = Ref(BlasInt(0))
            info = Ref(BlasInt(0))

            ccall(
                (@blasfunc($f), liblapack_name),
                Cvoid,
                (
                    Ref{UInt8},
                    Ref{UInt8},
                    Ptr{BlasInt},
                    Ref{BlasInt},
                    Ptr{$elty},
                    Ref{BlasInt},
                    Ptr{$elty},
                    Ref{BlasInt},
                    Ptr{$elty},
                    Ref{BlasInt},
                    Ptr{$elty},
                    Ref{BlasInt},
                    Ref{BlasInt},
                    Ref{BlasInt},
                    Ptr{$elty},
                    Ref{BlasInt},
                ),
                side,
                howmny,
                select,
                n,
                S,
                lds,
                P,
                ldp,
                VL,
                ldvl,
                VR,
                ldvr,
                mm,
                m,
                work,
                info,
            )

            if info[] != 0
                throw(LAPACKException(info[]))
            end

            return VL, VR, m[]
        end

        function tgevc!(
            side::Char,
            howmny::Char,
            select::Vector{BlasInt},
            S::StridedMatrix{$elty},
            P::StridedMatrix{$elty},
            VL::StridedMatrix{$elty},
            VR::StridedMatrix{$elty},
        )

            n = LinearAlgebra.checksquare(S)
            work = Vector{$elty}(undef, 6n)

            return tgevc!(side, howmny, select, S, P, VL, VR, work)
        end

        function tgevc!(
            side::Char,
            howmny::Char,
            select::Vector{BlasInt},
            S::StridedMatrix{$elty},
            P::StridedMatrix{$elty},
        )
            # No checks here as they are done in method above
            n = LinearAlgebra.checksquare(S)
            if side == 'L'
                VR = Matrix{$elty}(undef, n, 0)
                if howmny == 'A' || howmny == 'B'
                    VL = Matrix{$elty}(undef, n, n)
                else
                    VL = Matrix{$elty}(undef, n, sum(select))
                end
            elseif side == 'R'
                VL = Matrix{$elty}(undef, n, 0)
                if howmny == 'A' || howmny == 'B'
                    VR = Matrix{$elty}(undef, n, n)
                else
                    VR = Matrix{$elty}(undef, n, sum(select))
                end
            else
                if howmny == 'A' || howmny == 'B'
                    VL = Matrix{$elty}(undef, n, n)
                    VR = Matrix{$elty}(undef, n, n)
                else
                    VL = Matrix{$elty}(undef, n, sum(select))
                    VR = Matrix{$elty}(undef, n, sum(select))
                end
            end

            return tgevc!(side, howmny, select, S, P, VL, VR)
        end
    end
end


# Rectangular full packed format

## Symmetric rank-k operation for matrix in RFP format.
for (f, elty, relty) in (
    (:dsfrk_, :Float64, :Float64),
    (:ssfrk_, :Float32, :Float32),
    (:zhfrk_, :ComplexF64, :Float64),
    (:chfrk_, :ComplexF32, :Float32),
)

    @eval begin
        function sfrk!(
            transr::Char,
            uplo::Char,
            trans::Char,
            alpha::Real,
            A::StridedMatrix{$elty},
            beta::Real,
            C::StridedVector{$elty},
        )
            chkuplo(uplo)
            chkstride1(A)
            if trans in ('N', 'n')
                n, k = size(A)
            elseif trans in ('T', 't', 'C', 'c')
                k, n = size(A)
            end
            lda = max(1, stride(A, 2))

            ccall(
                (@blasfunc($f), liblapack_name),
                Cvoid,
                (
                    Ref{UInt8},
                    Ref{UInt8},
                    Ref{UInt8},
                    Ref{BlasInt},
                    Ref{BlasInt},
                    Ref{$relty},
                    Ptr{$elty},
                    Ref{BlasInt},
                    Ref{$relty},
                    Ptr{$elty},
                ),
                transr,
                uplo,
                trans,
                n,
                k,
                alpha,
                A,
                lda,
                beta,
                C,
            )
            C
        end
    end
end

# Cholesky factorization of a real symmetric positive definite matrix A
for (f, elty) in (
    (:dpftrf_, :Float64),
    (:spftrf_, :Float32),
    (:zpftrf_, :ComplexF64),
    (:cpftrf_, :ComplexF32),
)

    @eval begin
        function pftrf!(transr::Char, uplo::Char, A::StridedVector{$elty})
            chkuplo(uplo)
            n = round(Int, div(sqrt(8length(A)), 2))
            info = Vector{BlasInt}(undef, 1)

            ccall(
                (@blasfunc($f), liblapack_name),
                Cvoid,
                (Ref{UInt8}, Ref{UInt8}, Ref{BlasInt}, Ptr{$elty}, Ptr{BlasInt}),
                transr,
                uplo,
                n,
                A,
                info,
            )
            A
        end
    end
end

# Computes the inverse of a (real) symmetric positive definite matrix A using the Cholesky factorization
for (f, elty) in (
    (:dpftri_, :Float64),
    (:spftri_, :Float32),
    (:zpftri_, :ComplexF64),
    (:cpftri_, :ComplexF32),
)

    @eval begin
        function pftri!(transr::Char, uplo::Char, A::StridedVector{$elty})
            chkuplo(uplo)
            n = round(Int, div(sqrt(8length(A)), 2))
            info = Vector{BlasInt}(undef, 1)

            ccall(
                (@blasfunc($f), liblapack_name),
                Cvoid,
                (Ref{UInt8}, Ref{UInt8}, Ref{BlasInt}, Ptr{$elty}, Ptr{BlasInt}),
                transr,
                uplo,
                n,
                A,
                info,
            )

            A
        end
    end
end

# DPFTRS solves a system of linear equations A*X = B with a symmetric positive definite matrix A using the Cholesky factorization
for (f, elty) in (
    (:dpftrs_, :Float64),
    (:spftrs_, :Float32),
    (:zpftrs_, :ComplexF64),
    (:cpftrs_, :ComplexF32),
)

    @eval begin
        function pftrs!(
            transr::Char,
            uplo::Char,
            A::StridedVector{$elty},
            B::StridedVecOrMat{$elty},
        )
            chkuplo(uplo)
            chkstride1(B)
            n = round(Int, div(sqrt(8length(A)), 2))
            if n != size(B, 1)
                throw(DimensionMismatch("B has first dimension $(size(B,1)) but needs $n"))
            end
            nhrs = size(B, 2)
            ldb = max(1, stride(B, 2))
            info = Vector{BlasInt}(undef, 1)

            ccall(
                (@blasfunc($f), liblapack_name),
                Cvoid,
                (
                    Ref{UInt8},
                    Ref{UInt8},
                    Ref{BlasInt},
                    Ref{BlasInt},
                    Ptr{$elty},
                    Ptr{$elty},
                    Ref{BlasInt},
                    Ptr{BlasInt},
                ),
                transr,
                uplo,
                n,
                nhrs,
                A,
                B,
                ldb,
                info,
            )

            B
        end
    end
end

# Solves a matrix equation (one operand is a triangular matrix in RFP format)
for (f, elty) in (
    (:dtfsm_, :Float64),
    (:stfsm_, :Float32),
    (:ztfsm_, :ComplexF64),
    (:ctfsm_, :ComplexF32),
)

    @eval begin
        function tfsm!(
            transr::Char,
            side::Char,
            uplo::Char,
            trans::Char,
            diag::Char,
            alpha::$elty,
            A::StridedVector{$elty},
            B::StridedVecOrMat{$elty},
        )
            chkuplo(uplo)
            chkside(side)
            chkdiag(diag)
            chkstride1(B)
            m, n = size(B, 1), size(B, 2)
            if round(Int, div(sqrt(8length(A)), 2)) != m
                throw(
                    DimensionMismatch(
                        "First dimension of B must equal $(round(Int, div(sqrt(8length(A)), 2))), got $m",
                    ),
                )
            end
            ldb = max(1, stride(B, 2))

            ccall(
                (@blasfunc($f), liblapack_name),
                Cvoid,
                (
                    Ref{UInt8},
                    Ref{UInt8},
                    Ref{UInt8},
                    Ref{UInt8},
                    Ref{UInt8},
                    Ref{BlasInt},
                    Ref{BlasInt},
                    Ref{$elty},
                    Ptr{$elty},
                    Ptr{$elty},
                    Ref{BlasInt},
                ),
                transr,
                side,
                uplo,
                trans,
                diag,
                m,
                n,
                alpha,
                A,
                B,
                ldb,
            )

            return B
        end
    end
end

# Computes the inverse of a triangular matrix A stored in RFP format.
for (f, elty) in (
    (:dtftri_, :Float64),
    (:stftri_, :Float32),
    (:ztftri_, :ComplexF64),
    (:ctftri_, :ComplexF32),
)

    @eval begin
        function tftri!(transr::Char, uplo::Char, diag::Char, A::StridedVector{$elty})
            chkuplo(uplo)
            chkdiag(diag)
            n = round(Int, div(sqrt(8length(A)), 2))
            info = Vector{BlasInt}(undef, 1)

            ccall(
                (@blasfunc($f), liblapack_name),
                Cvoid,
                (
                    Ref{UInt8},
                    Ref{UInt8},
                    Ref{UInt8},
                    Ref{BlasInt},
                    Ptr{$elty},
                    Ptr{BlasInt},
                ),
                transr,
                uplo,
                diag,
                n,
                A,
                info,
            )

            A
        end
    end
end

# Copies a triangular matrix from the rectangular full packed format (TF) to the standard full format (TR)
for (f, elty) in (
    (:dtfttr_, :Float64),
    (:stfttr_, :Float32),
    (:ztfttr_, :ComplexF64),
    (:ctfttr_, :ComplexF32),
)

    @eval begin
        function tfttr!(transr::Char, uplo::Char, Arf::StridedVector{$elty})
            chkuplo(uplo)
            n = round(Int, div(sqrt(8length(Arf)), 2))
            info = Vector{BlasInt}(undef, 1)
            A = similar(Arf, $elty, n, n)

            ccall(
                (@blasfunc($f), liblapack_name),
                Cvoid,
                (
                    Ref{UInt8},
                    Ref{UInt8},
                    Ref{BlasInt},
                    Ptr{$elty},
                    Ptr{$elty},
                    Ref{BlasInt},
                    Ptr{BlasInt},
                ),
                transr,
                uplo,
                n,
                Arf,
                A,
                n,
                info,
            )

            A
        end
    end
end

# Copies a triangular matrix from the standard full format (TR) to the rectangular full packed format (TF).
for (f, elty) in (
    (:dtrttf_, :Float64),
    (:strttf_, :Float32),
    (:ztrttf_, :ComplexF64),
    (:ctrttf_, :ComplexF32),
)

    @eval begin
        function trttf!(transr::Char, uplo::Char, A::StridedMatrix{$elty})
            chkuplo(uplo)
            chkstride1(A)
            n = size(A, 1)
            lda = max(1, stride(A, 2))
            info = Vector{BlasInt}(undef, 1)
            Arf = similar(A, $elty, div(n * (n + 1), 2))

            ccall(
                (@blasfunc($f), liblapack_name),
                Cvoid,
                (
                    Ref{UInt8},
                    Ref{UInt8},
                    Ref{BlasInt},
                    Ptr{$elty},
                    Ref{BlasInt},
                    Ptr{$elty},
                    Ptr{BlasInt},
                ),
                transr,
                uplo,
                n,
                A,
                lda,
                Arf,
                info,
            )

            Arf
        end
    end
end

end
