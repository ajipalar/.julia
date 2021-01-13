module ArnoldiMethod

using LinearAlgebra

using Base: RefValue

export partialschur, LM, SR, LR, SI, LI, partialeigen

"""
    Arnoldi(n, k) -> Arnoldi

Pre-allocated Arnoldi relation of the Vₖ₊₁ and Hₖ matrices that satisfy
A * Vₖ = Vₖ₊₁ * Hₖ, where Vₖ₊₁ is orthonormal of size n × (k+1) and Hₖ upper 
Hessenberg of size (k+1) × k. The constructor will just allocate sufficient
space, but will *not* initialize the first vector of `v₁`. For the latter see
`reinitialize!`.
"""
struct Arnoldi{T,TV<:StridedMatrix{T},TH<:StridedMatrix{T}}
    V::TV
    H::TH

    function Arnoldi{T}(matrix_order::Int, krylov_dimension::Int) where {T}
        krylov_dimension <= matrix_order || throw(ArgumentError("Krylov dimension should be less than matrix order."))
        V = Matrix{T}(undef, matrix_order, krylov_dimension + 1)
        H = zeros(T, krylov_dimension + 1, krylov_dimension)    
        return new{T,typeof(V),typeof(H)}(V, H)
    end
end

"""
    RitzValues(maxdim) -> RitzValues

Convenience wrapper for Ritz values + residual norms and some permutation of 
these values. The Ritz values are computed from the active part of the 
Hessenberg matrix `H[active:maxdim,active:maxdim]`. 

When computing exact shifts in the implicit restart, we need to reorder the Ritz
values in some way. For convenience we simply keep track of a permutation `ord`
of the Ritz values rather than moving the Ritz values themselves around. That
way we don't lose the order of the residual norms.
"""
struct RitzValues{Tv,Tr}
    λs::Vector{Tv}
    rs::Vector{Tr}
    ord::Vector{Int}

    function RitzValues{T}(maxdim::Int) where {T}
        λs = Vector{complex(T)}(undef, maxdim)
        rs = Vector{real(T)}(undef, maxdim)
        ord = Vector{Int}(undef, maxdim)
        return new{complex(T),real(T)}(λs, rs, ord)
    end
end

struct PartialSchur{TQ,TR}
    Q::TQ
    R::TR
end

include("targets.jl")
include("partition.jl")
include("schurfact.jl")
include("expansion.jl")
include("implicit_restart.jl")
include("factorization.jl")
include("run.jl")
include("eigvals.jl")
include("eigenvector_uppertriangular.jl")
include("show.jl")


end