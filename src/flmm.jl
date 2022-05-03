function flmm2(alpha,fdefun,Jfdefun,t0,tfinal,y0,h, param)
    itmax = 100 ;
    tol = 1.0e-6 ;
    method = 3 ;

    m_alpha = ceil.(Int, alpha)
    m_alpha_factorial = factorial.(collect(0:m_alpha-1))
    # Structure for storing information on the problem
    
    problem_size = size(y0, 1)
    
    
    # Check compatibility size of the problem with size of the vector field
    f_temp = f_vectorfield(t0, y0[:, 1], param, fdefun)
    
    # Number of points in which to evaluate the solution or the weights
    r = 16
    N = ceil((tfinal-t0)/h)
    Nr = ceil((N+1)/r)*r
    Q = ceil(log2((Nr)/r))-1
    NNr = 2^(Q+1)*r

    # Preallocation of some variables
    y = zeros(problem_size, N+1)
    fy = zeros(problem_size, N+1)
    zn = zeros(problem_size, NNr+1)

    # Evaluation of convolution and starting weights of the FLMM
    (omega,w,s) = Weights(alpha, NNr+1, method)
    halpha = h^alpha
    
    # Initializing solution and proces of computation
    t = collect(0:N)*h
    y[:, 1] = y0[:, 1]
    fy[:, 1] = f_vectorfield(t0, y0[:, 1], param, fdefun)
    (y, fy) = FirstApproximations(t, y, fy, tol, itmax, s, halpha, omega, w, problem_size, param, fdefun, Jfdefun, y0, m_alpha, t0, m_alpha_factorial)
    (y, fy) = Triangolo(s+1, r-1, 0, t, y, fy, zn, N, tol, itmax, s, w, omega, halpha, problem_size, fdefun, Jfdefun, param, y0, m_alpha, t0, m_alpha_factorial)
    
    # Main process of computation by means of the FFT algorithm
    nx0 = 0; ny0 = 0
    ff = zeros(1, 2^(Q+2), 1)
    ff[1:2] = [0 2]
    for q = 0:Q
        L = 2^q
        [y, fy] = DisegnaBlocchi(L, ff, r, Nr, nx0+L*r, ny0, t, y, fy, zn, N, tol, itmax, s, w, omega, halpha, problem_size, fdefun, Jfdefun, param, y0, m_alpha, t0, m_alpha_factorial) ;
        ff[1:4*L] = [ff(1:2*L); ff(1:2*L-1); 4*L]
    end
    # Evaluation solution in TFINAL when TFINAL is not in the mesh
    if tfinal < t[N+1]
        c = (tfinal - t[N])/h
        t[N+1] = tfinal
        y[:, N+1] = (1-c)*y[:, N] + c*y[:, N+1]
    end
    t = t[1:N+1]; y = y[:, 1:N+1]
    return t, y
end


function DisegnaBlocchi(L, ff, r, Nr, nx0, ny0, t, y, fy, zn, N , tol, itmax, s, w, omega, halpha, problem_size, fdefun, Jfdefun, param,y0, m_alpha, t0, m_alpha_factorial)
    nxi = nx0 ; nxf = nx0 + L*r - 1
    nyi = ny0 ; nyf = ny0 + L*r - 1
    is = 1
    s_nxi[is] = nxi; s_nxf[is] = nxf ; s_nyi[is] = nyi; s_nyf[is] = nyf
    i_triangolo = 0;  stop = false
    while ~stop
        stop = nxi+r-1 == nx0+L*r-1 | (nxi+r-1>=Nr-1)
        zn = Quadrato(nxi, nxf, nyi, nyf, fy, zn, omega, problem_size)
        (y, fy) = Triangolo(nxi, nxi+r-1, nxi, t, y, fy, zn, N, tol, itmax, s, w, omega, halpha, problem_size, fdefun, Jfdefun, param,y0, m_alpha, t0, m_alpha_factorial) ;
        i_triangolo = i_triangolo + 1
        
        if ~stop
            if nxi+r-1 == nxf   # Il triangolo finisce dove finisce il quadrato -> si scende di livello
                i_Delta = ff[i_triangolo]
                Delta = i_Delta*r
                nxi = s_nxf[is]+1; nxf = s_nxf[is] + Delta
                nyi = s_nxf[is] - Delta +1; nyf = s_nxf[is]
                s_nxi[is] = nxi; s_nxf[is] = nxf; s_nyi[is] = nyi; s_nyf[is] = nyf
            else # Il triangolo finisce prima del quadrato -> si fa un quadrato accanto
                nxi = nxi + r ; nxf = nxi + r - 1 ; nyi = nyf + 1 ; nyf = nyf + r
                is = is + 1
                s_nxi[is] = nxi ; s_nxf[is] = nxf ; s_nyi[is] = nyi ; s_nyf[is] = nyf
            end
        end
        
    end
    return y, fy
end

function Quadrato(nxi, nxf, nyi, nyf, fy, zn, omega, problem_size)
    coef_beg = nxi-nyf; coef_end = nxf-nyi+1
    funz_beg = nyi+1; funz_end = nyf+1
    vett_coef = omega(coef_beg+1:coef_end+1)
    vett_funz = [fy[:, funz_beg:funz_end]  zeros(problem_size, funz_end-funz_beg+1)]
    zzn = real(FastConv(vett_coef,vett_funz))
    zn[:, nxi+1:nxf+1] = zn[:, nxi+1:nxf+1] + zzn[:, nxf-nyf:end-1]
    return zn
end

function Triangolo(nxi, nxf, j0, t, y, fy, zn, N, tol, itmax, s, w, omega, halpha, problem_size, fdefun, Jfdefun, param, y0, m_alpha, t0, m_alpha_factorial)
    for n = nxi:min(N, nxf)
        n1 = n + 1
        St = StartingTerm(t[n1], y0, m_alpha, t0, m_alpha_factorial)
        
        Phi = zeros(problem_size, 1)
        for j = 0:s
            Phi = Phi + w[j+1, n1]*fy[:, j+1]
        end
        for j = j0:n-1
            Phi = Phi + omega[n-j+1]*fy[:, j+1]
        end
        Phi_n = St + halpha*(zn[:, n1] + Phi)
        
        yn0 = y[:, n]; fn0 = f_vectorfield(t[n1], yn0, param, fdefun)
        Jfn0 = Jf_vectorfield(t[n1], yn0, param, Jfdefun)
        Gn0 = yn0 - halpha*omega[1]*fn0 - Phi_n
        stop = false; it = 0
        while ~stop            
            JGn0 = zeros(problem_size, problem_size)+I - halpha*omega[1]*Jfn0
            yn1 = yn0 - JGn0\Gn0
            fn1 = f_vectorfield(t[n1], yn1, param, fdefun)
            Gn1 = yn1 - halpha*omega[1]*fn1 - Phi_n
            it = it + 1
            
            stop = norm(yn1-yn0, inf) < tol | norm(Gn1, inf)<tol
            if it > itmax && ~stop
                @warn "Non Convergence"
                stop = 1
            end
            
            yn0 = yn1; Gn0 = Gn1
            if ~stop
                Jfn0 = Jf_vectorfield(t[n1], yn0, param, Jfdefun)
            end
            
        end
        y[:, n1] = yn1
        fy[:, n1] = fn1
        return y, fy
    end
    end

function [y, fy] = FirstApproximations(t, y, fy, tol, itmax, s, halpha, omega, w, problem_size, param, fdefun, Jfdefun, y0, m_alpha, t0, m_alpha_factorial)
    m = problem_size
    Im = zeros(m, m)+I ; Ims = zeros(m*s, m*s)+I
    Y0 = zeros(s*m, 1); F0 = copy(Y0); B0 = copy(Y0)
    for j = 1 : s
        Y0[(j-1)*m+1:j*m, 1] = y[:, 1]
        F0[(j-1)*m+1:j*m, 1] = f_vectorfield(t[j+1], y[:, 1], param, fdefun)
        St = StartingTerm(t[j+1],y0, m_alpha, t0, m_alpha_factorial)
        B0[(j-1)*m+1:j*m, 1] = St + halpha*(omega[j+1]+w[1, j+1])*fy[:, 1]
    end
    W = zeros(s, s)
    for i = 1:s
        for j = 1:s
            if i >= j
                W[i, j] = omega[i-j+1] + w[j+1, i+1]
            else
                W[i, j] = w[j+1, i+1]
            end
        end
    end
    W = halpha*kron(W, Im)
    G0 = Y0 - B0 - W*F0
    JF = zeros(s*m, s*m)
    for j = 1:s
        JF[(j-1)*m+1:j*m, (j-1)*m+1:j*m] = Jf_vectorfield(t[j+1], y[:, 1], param, Jfdefun)
    end
    stop = false; it = 0
    while ~stop
        JG = Ims - W*JF
        Y1 = Y0 - JG\G0
        
        for j = 1 : s
            F1[(j-1)*m+1:j*m, 1] = f_vectorfield(t[j+1], Y1[(j-1)*m+1:j*m, 1], param, fdefun)
        end
        G1 = Y1 - B0 - W*F1
        
        it = it + 1
        
        stop = norm(Y1-Y0, inf) < tol | norm(G1, inf) <  tol
        if it > itmax && ~stop
            @warn "Non Convergence"
            stop = 1
        end
        
        Y0 = Y1 ; G0 = G1
        if ~stop
            for j = 1 : s
                JF[(j-1)*m+1:j*m, (j-1)*m+1:j*m] = Jf_vectorfield(t[j+1], Y1[(j-1)*m+1:j*m, 1], param, Jfdefun)
            end
        end
        
    end
    for j = 1 : s
        y[:, j+1] = Y1[(j-1)*m+1:j*m, 1]
        fy[:, j+1] = F1[(j-1)*m+1:j*m, 1]
    end
    end

function FastConv(x, y)
        Lx = length(x); Ly = size(y, 2); problem_size = size(y, 1)
    
        r = Lx
        z = zeros(Number, problem_size, r)
        X = ourfft(x, r)
        for i = 1:problem_size
            Y = ourfft(y[i, :], r)
            Z = X.*Y
            z[i, :] = ourifft(Z, r)
        end
    return z
end

function ourfft(x, n)
    s=length(x)
    x=x[:]
    if s > n
        return fft(x[1:n])
    elseif s < n
        return fft([x; zeros(n-s)])
    else
        return fft(x)
    end
end

function ourifft(x, n)
    s=length(x)
    x=x[:]
    if s > n
        return ifft(x[1:n])
    elseif s < n
        return ifft([x; zeros(n-s)])
    else
        return ifft(x)
    end
end

function Weights(alpha,N,method)
        # Trapezoidal method with generating function ((1+x)/2/(1-x))^alpha
        if method == 1
            omega1 = zeros(1, N+1); omega2 = copy(omega1)
            omega1[1] = 1; omega2[1] = 1
            alpha_minus_1 = alpha - 1 ; alpha_plus_1 = alpha + 1
            for n = 1 : N
                omega1[n+1] = (alpha_plus_1/n - 1)*omega1[n]
                omega2[n+1] = (1 + alpha_minus_1/n)*omega2[n]
            end
            x = fft([omega1, zeros(size(omega1))])
            y = fft([omega2, zeros(size(omega2))])
            omega = ifft(x.*y) 
            omega = omega(1:N+1)/2^alpha
        # Newton-Gregory formula with generating function (1-x)^(-alpha)*(1-alpha/2*(1-x))
        elseif method == 2
            omega1 = zeros(1, N+1); omega = copy(omega1)
            alphameno1 = alpha - 1
            omega1[1] = 1
            for n = 1 : N
                omega1[n+1] = (1 + alphameno1/n)*omega1[n]
            end
            omega[1] = 1-alpha/2
            omega[2:N+1] = (1-alpha/2)*omega1[2:N+1] + alpha/2*omega1[1:N]
         
        # BDF-2 with generating function (2/3/(1-4x/3+x^2/3))^alpha
        elseif method == 3 
            omega = zeros(1, N+1)
            onethird = 1/3; fourthird = 4/3
            twothird_oneminusalpha = 2/3*(1-alpha)
            fourthird_oneminusalpha = 4/3*(1-alpha)
            omega[1] = 1; omega[2] = fourthird*alpha*omega[1]
            for n = 2:N
                omega[n+1] = (fourthird - fourthird_oneminusalpha/n)*omega[n] + (twothird_oneminusalpha/n - onethird)*omega[n-1]
            end
            omega = omega*((2/3)^(alpha))
        end

    k = floor(1/abs(alpha))
    if abs(k - 1/alpha) < 1.0e-12
        A = collect(0:k)*abs(alpha)
    else
        A = [collect(0:k)*abs(alpha); 1]
    end
    s = length(A) - 1
    # Generation of the matrix and the right hand--side vectors of the system
    nn = 0:N
    V = zeros(s+1, s+1); jj_nu = zeros(s+1, N+1); nn_nu_alpha = jj_nu
    for i = 0:s
        nu = A[i+1]
        V[i+1, :] = collect(0:s).^nu
        jj_nu[i+1, :] = nn.^nu
        if alpha > 0
            nn_nu_alpha[i+1, :] = gamma(nu+1)/gamma(nu+1+alpha)*nn.^(nu+alpha)
        else
            if i == 0
                nn_nu_alpha[i+1, :] = zeros[1, N+1]
            else
                nn_nu_alpha[i+1, :] = gamma(nu+1)/gamma(nu+1+alpha)*nn.^(nu+alpha)
            end
        end
    end
    temp = FastConv([omega  zeros(size(omega))], [jj_nu zeros(size(jj_nu))])
    b = nn_nu_alpha - temp[:, 1:N+1]
    # Solution of the linear system with multiple right-hand side
    w = V\b

    return omega, w, s
end

function f_vectorfield(t,y,param, fdefun)
    if isempty(param)
        f = fdefun(t, y)
    else
        f = fdefun(t, y, param)
    end
    return f
end

function f = Jf_vectorfield(t, y, param, Jfdefun)
    if isempty(param)
        f = Jfdefun(t, y)
    else
        f = Jfdefun(t, y, param)
    end
    return f
end

function StartingTerm(t,y0, m_alpha, t0, m_alpha_factorial)
    ys = zeros(size(y0,1), 1)
    for k = 1:m_alpha
        ys = ys + (t-t0)^(k-1)/m_alpha_factorial(k)*y0[:, k]
    end
    return ys
end