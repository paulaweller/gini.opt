include("helpers.jl")

function generate_full_problem_mandell(instance::Instance)
    
    I, J, S, N, P, O, V, T, D, bigM = unroll_instance(instance)

    # Initialize model
    m = Model(Gurobi.Optimizer)
    #m = Model(HiGHS.Optimizer)
    set_silent(m)

    # Decision variables
    @variable(m, x[I], Bin)     # 1 if facility is located at i ∈ I, 0 otherwise.
    @variable(m, y[I] >= 0)     # Capacity decided for facility i ∈ I

    @variable(m, u[J,S] >= 0)  # demand of client j divided by total demand
    @constraint(m, [j in J, s in S], u[j,s] == D[j,s]/sum(D[j1,s] for j1 in J))
    @variable(m, X[J,I,S])     # how much of J's demand is satisfied by i
    @constraint(m, [j in J, s in S], sum(X[j,i,s] for i in I) <= 1)

    @variable(m, Ut[S] >= 0)   # effectiveness measure
    @constraint(m, [s in S], Ut[s] == sum(u[j,s]*X[j,i,s] for j in J, i in I))

    # calculating mean diff
    @variable(m, rho[J,S])
    @constraint(m, [j in J, s in S], rho[j,s] == u[j,s]/sum(u[j1,s] for j1 in J))
    @variable(m, diff[J,J,S])
    @constraint(m, [j1 in J, j2 in J[j1+1:end], s in S], diff[j1,j2,s] >= rho[j1,s]*sum(u[j1,s]*X[j1,i,s] for i in I)-rho[j2,s]*sum(u[j2,s]*X[j2,i,s] for i in I))
    @constraint(m, [j1 in J, j2 in J[j1+1:end], s in S], diff[j1,j2,s] >= rho[j2,s]*sum(u[j2,s]*X[j2,i,s] for i in I)-rho[j1,s]*sum(u[j1,s]*X[j1,i,s] for i in I))



    # Constraints
    # Maximum number of servers
    @constraint(m, numServers,
        sum(x[i] for i in I) <= N
    )
    
    # Capacity limits: cannot deliver more than capacity decided, 
    #   and only if facility was located
    @constraint(m, capBal[i in I, s in S],
        sum(X[j,i,s]*D[j,s] for j in J) <=  y[i]
    )

    @constraint(m, capLoc[i in I], 
        y[i] <= x[i] * bigM
    )
    
    # # Demand balance: Demand of active clients must be fulfilled
    # @constraint(m, demBal[j in J, s in S],
    #     sum(w[i,j,s] for i in I) >= D[j,s] - z[j,s]
    # )

    # The two-stage objective function
    FirstStage = @expression(m, 
        sum(O[i] * x[i] + V[i] * y[i] for i in I) 
    )

    @expression(m, SecondStage[s in S],

    sum(T[i,j] * X[j,i,s]*D[j,s] for i in I, j in J)

)

    @constraint(m, FirstStage <= 500)
    @constraint(m, [s in S], SecondStage[s] <= 1000)

    Obje = @expression(m,
        sum(P[s]*(sum(u[j,s]*X[j,i,s] for j in J for i in I)-sum(diff[j1,j2,s] for j1 in J for j2 in J[j1+1:end])) for s in S) 
    )
    
    @objective(m, Max, Obje)
    
    return m  # Return the generated model
end