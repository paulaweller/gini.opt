include("helpers.jl")

function generate_full_problem_gini(instance::Instance)
    
    I, J, S, N, P, O, V, T, D, bigM = unroll_instance(instance)

    # Initialize model
    m = Model(Gurobi.Optimizer)
    #m = Model(HiGHS.Optimizer)
    set_silent(m)
    R = 1:length(J)
    # Decision variables
    @variable(m, x[I], Bin)     # 1 if facility is located at i ∈ I, 0 otherwise.
    @variable(m, y[I] >= 0)     # Capacity decided for facility i ∈ I
    #@variable(m, w[I,J,S] >= 0) # Flow between facility i ∈ I and client j ∈ J in scenario s ∈ S
    #@variable(m, z[J,S] >= 0)   # Shortage in location j ∈ J in scenario s ∈ S

    # demand of client j divided by total demand
    @expression(m, u[j in J, s in S], D[j,s]/sum(D[j1,s] for j1 in J))
    @variable(m, X[J,I,S]>= 0)     # how much of J's demand is satisfied by i
    @constraint(m, [j in J, s in S], sum(X[j,i,s] for i in I) <= 1)

    @variable(m, Ut[S] >= 0)   # effectiveness measure
    @constraint(m, [s in S], Ut[s] == sum(u[j,s]*X[j,i,s] for j in J, i in I))

    # calculating ranking
    @variable(m, p[J,S] >=0)
    @variable(m, Oi[J,R,S], Bin)
    @constraint(m, [j in J, s in S], p[j,s] == sum(r*Oi[j,r,s] for r in R)/length(R))
    @constraint(m, [j in J,s in S], sum(Oi[j,r,s] for r in R) == 1)
    @constraint(m, [r in R,s in S], sum(Oi[j,r,s] for j in J) == 1)
    @variable(m, Z[R,S]>= 0)

    @constraint(m, zconr[j in J, r in R, s in S], Z[r,s] >= sum(u[j,s]*X[j,i,s] for i in I)-1+Oi[j,r,s])
    @constraint(m, zconl[j in J, r in R, s in S], Z[r,s] <= sum(u[j,s]*X[j,i,s] for i in I)+1-Oi[j,r,s])
    @constraint(m, [j in J,r in R[1:(end-1)],s in S], Z[r,s] <= Z[r+1,s])


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
        sum(1/length(R)*(2*length(R)+1-2*r)*Z[r,s]*P[s] for r in R for s in S) 
    )
    
    @objective(m, Max, Obje)
    
    return m  # Return the generated model
end