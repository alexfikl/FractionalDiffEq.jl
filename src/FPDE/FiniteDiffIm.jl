struct FiniteDiffIm <: FractionalDiffEqAlgorithm end

function solve(α, dx, dt, xStart, xEnd, n, κ, ::FiniteDiffIm)
    x = collect(0:dx:xEnd)
    t = collect(0:dt:n)

    U = zeros(Int64(n/dt + 1), Int64((xEnd - xStart)/dx + 1))

    U[:, 1] .= 0
    U[:, end] .= 0

    U[1, :] .= sin.(x)

    mu = (dt^α)/(dx^2)
    r = mu * gamma(2-α)
    A1 = diagm((1+2*r)*ones(length(x)-2))
    A2 = diagm(1 => -r*ones(length(x)-3))
    A3 = diagm(-1 => -r*ones(length(x)-3))

    A = A1 + A2 + A3


    U[2, 2:end-1] = A \ U[1, 2:end-1]

    j = collect(0:length(t))
    b_j = (j.+1).^(1-α) .- j.^(1-α)
    c_j = b_j[1:end-1] - b_j[2:end]

    V = copy(U[2:end, 2:end-1])
    for k = 1:length(V[:, 1])-1
        V[k+1, :] = A \ ImNextStep(V, U[1, 2:end-1], k, b_j, c_j)'
    end

    U[2:end, 2:end-1] = V

    return U
end

function ImNextStep( V, U_0, k, b_j, c_j )    
    nextRow = c_j[1:k]' * reverse(V[1:k, :], dims=1) .+ (b_j[k+1].*U_0)'
    return nextRow
end


