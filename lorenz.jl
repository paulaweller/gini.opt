include("helpers.jl")

function generate_full_problem_lorenz(instance::Instance)
    
    I, J, S, N, P, O, V, T, D, b1, b2, bigM = unroll_instance(instance)
    R = 1:length(J) # percentile ranks

    # Initialize model
    m = Model(Gurobi.Optimizer)
    set_silent(m)
    
    # Decision variables
    @variable(m, x[I], Bin)     # 1 if facility is located at i ∈ I, 0 otherwise.
    @variable(m, y[I] >= 0)     # Capacity decided for facility i ∈ I
    @variable(m, X[J,I,S]>= 0)  # how much of j's demand is covered by i

    # Expressions
    @expression(m, u[j in J, s in S], D[j,s]/sum(D[j1,s] for j1 in J))  # demand of client j divided by total demand  
    @expression(m, Ut[s in S], sum(u[j,s]*X[j,i,s] for j in J, i in I)) # effectiveness measure
    
    # Constraints

    # Maximum number of servers
    @constraint(m, numServers, sum(x[i] for i in I) <= N)
    
    # Capacity limits: cannot deliver more than capacity decided...
    @constraint(m, capBal[i in I, s in S], sum(X[j,i,s]*D[j,s] for j in J) <=  y[i])
    # ...and only if facility was located.
    @constraint(m, capLoc[i in I], y[i] <= x[i] * bigM)
    # do not cover more demand than exists
    @constraint(m, [j in J, s in S], sum(X[j,i,s] for i in I) <= 1)
    # first-stage financial budget
    @constraint(m, sum(O[i] * x[i] + V[i] * y[i] for i in I)  <= b1)
    # second-stage financial budget
    @constraint(m, [s in S], sum(T[i,j] * X[j,i,s]*D[j,s] for i in I, j in J) <= b2)


    # calculating ranking

    @variable(m, p[J,S] >=0)        # percentile value of area j
    @variable(m, Oi[J,R,S], Bin)    # 1 if area j is on rank r, 0 else
    @variable(m, 0 <= Z[R,S] <= 1)  # utility of the r-ranked area

    # percentile values are r/length(R) for the respective j
    @constraint(m, [j in J, s in S], p[j,s] == sum(r*Oi[j,r,s] for r in R)/length(R))
    # only one rank per area
    @constraint(m, [j in J, s in S], sum(Oi[j,r,s] for r in R) == 1)
    # only one area per rank
    @constraint(m, [r in R, s in S], sum(Oi[j,r,s] for j in J) == 1)
    # setting correct value for Z 
    @constraint(m, zconr[j in J, r in R, s in S], Z[r,s] >= sum(u[j,s]*X[j,i,s] for i in I)-1+Oi[j,r,s])
    @constraint(m, zconl[j in J, r in R, s in S], Z[r,s] <= sum(u[j,s]*X[j,i,s] for i in I)+1-Oi[j,r,s])
    # ranks must be sorted in increasing order of utility
    @constraint(m, [j in J,r in R[1:(end-1)],s in S], Z[r,s] <= Z[r+1,s])

    # calculate Gini coefficient for later retrieval
    @expression(m, G[s in S], 
        1 - 1/(length(J)*Ut[s])*(
            Z[1,s] + sum( sum(Z[j1,s] for j1 in J[1:j-1]) + sum(Z[j1,s] for j1 in J[1:j]) for j in J[2:end])
            )
            )

    # objective function (expected value of Ut[s]*(1-G[s]), but algebraically simplified)
    Obje = @expression(m,
        sum(1/length(R)*(2*length(R)+1-2*r)*Z[r,s]*P[s] for r in R for s in S) 
    )
    
    @objective(m, Max, Obje)
    
    return m  # Return the generated model
end