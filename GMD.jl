include("helpers.jl")

function generate_full_problem_GMD(instance::Instance)
    
    I, J, S, N, P, O, V, T, D, b1, b2, bigM = unroll_instance(instance)

    # Initialize model
    m = Model(Gurobi.Optimizer)
    set_silent(m)

    # Decision variables
    @variable(m, x[I], Bin)     # 1 if facility is located at i ∈ I, 0 otherwise.
    @variable(m, y[I] >= 0)     # Capacity decided for facility i ∈ I
    @variable(m, X[J,I,S])      # how much of j's demand is covered by i
    
    # Expressions 
    @expression(m, u[j in J, s in S], D[j,s]/sum(D[j1,s] for j1 in J))  # demand of client j divided by total demand  
    @expression(m, Ut[s in S], sum(u[j,s]*X[j,i,s] for j in J, i in I)) # effectiveness measure
    @expression(m, mean_ut[s in S], 1/length(J)*sum(u[j,s]*X[j,i,s] for i in I for j in J)) # mean utility

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

    # calculating GMD

    @variable(m, diff[J,J,S] >= 0)  # absolute value of the difference in utility at j and j'

    # setting the correct absolute value for the difference
    @constraint(m, [j1 in J, j2 in J[j1+1:end], s in S], diff[j1,j2,s] >= sum(u[j1,s]*X[j1,i,s] for i in I)-sum(u[j2,s]*X[j2,i,s] for i in I))
    @constraint(m, [j1 in J, j2 in J[j1+1:end], s in S], diff[j1,j2,s] >= sum(u[j2,s]*X[j2,i,s] for i in I)-sum(u[j1,s]*X[j1,i,s] for i in I))

    # calculate GMD for retrieving the value later
    @expression(m, GMD[s in S], 1/(2*mean_ut[s]*length(J)^2)*sum(diff[j1,j2,s] for j1 in J for j2 in (j1+1):length(J)))

    # objective function (expected value of Ut[s]*(1-GMD[s]), but algebraically simplified)
    Obje = @expression(m,
        sum(P[s]*(sum(u[j,s]*X[j,i,s] for j in J for i in I)-1/(2*length(J))*sum(diff[j1,j2,s] for j1 in J for j2 in J[j1+1:end])) for s in S) 
    )
    
    @objective(m, Max, Obje)
    
    return m  # Return the generated model
end