function solve(prob::FFODEProblem, h, ::AtanganaSeda)
    if length(prob.u0) > 1
        solve_ffodesystem(prob, h)
    else
        solve_singletermffode(prob, h)
    end
end
function solve_singletermffode(prob::FFODEProblem, h)
    @unpack f, order, u0, tspan, p = prob
    α = order[1]; β = order[2]
    t0 = tspan[1]; tfinal = tspan[2]
    t = (t0+h):h:tfinal
    N::Int = ceil(Int, (tfinal-t0)/h)
    u = zeros(N+1)
    u[1] = u0

    AB=1-α+α/gamma(α)
    u[2] = u[1] + h*f(t[1], u[1])
    u[3] = u[2]+(h/2)*(3*f(t[2], u[2])-f(t[1], u[1]))
    for n=3:N
        temp1 = 0; temp2 = 0; temp3 = 0
        for j=3:n
            temp1 += β.*t[j-2].^(β-1).*f(t[j-2], u[j-2]).*((n-j+1).^α-(n-j).^α)
            temp2 += (β.*t[j-1].^(β-1).*f(t[j-1], u[j-1])-β.*t[j-2].^(β-1).*f(t[j-2], u[j-2])).*((n-j+1).^α.*(n-j+3+2*α)-(n-j).^α.*(n-j+3+3*α))
            temp3 += ((β.*t[j].^(β-1).*f(t[j], u[j])-2*β.*t[j-1].^(β-1).*f(t[j-1], u[j-1])+β.*t[j-2]^(β-1).*f(t[j-2], u[j-2]))).*(((n-j+1).^α.*(2*(n-j).^2+(3*α+10).*(n-j)+2*α.^2+9*α+12))-(n-j).^α.*(2*(n-j).^2+(5*α+10)*(n-j)+6*α.^2+18*α+12))
        end
    u[n+1] = u[1]+((1-α)/AB)*β.*t[n].^(β-1).*u[n]+((h^(α).*α)./(AB*gamma(α+1))).*temp1+((h.^(α).*α)./(AB*gamma(α+2))).*temp2+((h.^(α).*α)./(AB*(2*gamma(α+3)))).*temp3
    end
    return t, u[1:N]
end

function solve_ffodesystem(prob::FFODEProblem, h)
    @unpack f, order, u0, tspan, p = prob
    α = order[1]; β = order[2]
    t0 = tspan[1]; tfinal = tspan[2]
    t = t0:h:tfinal
    N::Int = ceil(Int, (tfinal-t0)/h)
    AB=1-α+α/gamma(α)
    l = length(u0)
    result = zeros(length(u0), N+1)
    result[:, 1] = u0
    temp1 = zeros(l)
    f(temp1, u0, p, t[1])
    result[:, 2] = u0 + h.*temp1
    temp2 = zeros(l)
    f(temp2, result[:, 2], p, t[2])
    result[:, 3] = result[:, 2] + (h/2).*(3 .*temp2-temp1)
    for n=3:N
        test1, test2, test3 = zeros(l), zeros(l), zeros(l)
        temptemp1, temptemp2, temptemp3 = zeros(l), zeros(l), zeros(l)
        for j=3:n
            f(temptemp1, result[:, j], p, t[j])
            f(temptemp2, result[:, j-1], p, t[j-1])
            f(temptemp3, result[:, j-2], p, t[j-2])
            test1 += ((n+1-j).^α-(n-j).^α).*β.*t[j-2].^(β-1).*temptemp3
            test2 += (β.*t[j-1]^(β-1).*temptemp2-β.*t[j-2].^(β-1).*temptemp3)*((n+1-j).^α.*(n-j+3+2*α)-(n-j).^α.*(n-j+3+3*α))
            test3 += (β.*t[j].^(β-1).*temptemp1-2*β.*t[j-1].^(β-1).*temptemp2+β.*t[j-2].^(β-1).*temptemp3).*((n-j+1).^α.*(2*(n-j).^2+(3*α+10).*(n-j)+2*(α).^2+9*α+12)-(n-j).^α.*(2*(n-j).^2+(5*α+10).*(n-j)+6*α.^2+18*α+12))
        end
        test = zeros(l)
        f(test, result[:, n], p, t[n])
        result[:, n+1] = u0+((1-α)./AB).*β.*t[n].^(β-1).*test+((h.^α).*α./(AB.*gamma(α+1))).*test1+((h.^α).*α./(AB.*gamma(α+2))).*test2+((h.^α).*α./(2*AB.*gamma(α+3))).*test3
    end
    return result
end