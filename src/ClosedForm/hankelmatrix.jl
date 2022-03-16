"""
# Usage

    solve(parameters, order, lparameters, lorders, u, t)

Use Closed-Form Hankel matrix algorithm to obtain numerical solution at zero initial condition.
"""
struct ClosedFormHankelM <: FractionalDiffEqAlgorithm end


function solve(prob::MultiTermsFODEProblem, t, ::ClosedFormHankelM)
    @unpack parameters, orders, rightfun, rparameters, rorders = prob
    h = t[2]-t[1]
    u = rightfun.(t)
    u = u[:]
    A, B = 0, 0

    g = genfun(1)
    nt = length(t)
    n = length(parameters)
    m = length(rparameters)
    for i=1:n
        A = A .+ getvec(orders[i], nt, g)*parameters[i]/(h^orders[i])
    end

    for i=1:m
        B = B .+ getvec(rorders[i], nt, g)*rparameters[i]/(h^rorders[i])
    end

    A = rotl90(newhankel(A[end:-1:1]))
    B = rotl90(newhankel(B[end:-1:1]))

    y = B*inv(A)*u
    return y
end

function newhankel(v)
    n = length(v)
    v = v[:]

    hankelm = zeros(n, n)
    for i=1:length(v)
        hankelm[i, 1:end-i+1] = v[i:end]
    end

    return hankelm
end