include("helpers.jl")
include("lorenz.jl")
include("GMD.jl")

using JuMP

TotalFacilities = 2
TotalClients    = 3
TotalScenarios  = 3

# randomly generate a problem instance
instance = generate_instance(TotalFacilities, TotalClients, TotalScenarios)
print_instance(instance)

# generate and solve GMD (Gini mean difference) model
GMD_model = generate_full_problem_GMD(instance)
optimize!(GMD_model)

# write to file
# write_to_file(GMD_model, "GMD_model.lp")

# generate and solve Lorenz-based Gini model
lorenz_model = generate_full_problem_lorenz(instance)
optimize!(lorenz_model)

# write to file
# write_to_file(lorenz_model, "lorenz_model.lp")

# extract GMD solution
x_GMD = Int.(round.(value.(GMD_model[:x]).data))
y_GMD = value.(GMD_model[:y])
u_GMD = value.(GMD_model[:u])
X_GMD = value.(GMD_model[:X])
ut_GMD = value.(GMD_model[:Ut])
GMD = value.(GMD_model[:GMD])
obj_GMD = objective_value(GMD_model)

# extract lorenz-based solution
x_lorenz = Int.(round.(value.(lorenz_model[:x]).data))
y_lorenz = value.(lorenz_model[:y])
X_lorenz = value.(lorenz_model[:X])
Oi_lorenz = value.(lorenz_model[:Oi])
ut_lorenz = value.(lorenz_model[:Ut])
p_lorenz = value.(lorenz_model[:p])
Z_lorenz = value.(lorenz_model[:Z])
G = value.(lorenz_model[:G])
obj_lorenz = objective_value(lorenz_model)

# calculate difference in X
X_diff = round.(X_GMD .- X_lorenz, digits=3)

# print

println("GMD:")
println("   x   = ", [x_GMD[i] for i in instance.I])
println("   y   = ", [y_GMD[i] for i in instance.I])
println("   X   = ", [[sum(X_GMD[j,i,s] for i in instance.I) for j in instance.J] for s in instance.S])
println("   ut   = ", [ut_GMD[s] for s in instance.S])
println("   GMD   = ", [GMD[s] for s in instance.S])
println("   obj = ", obj_GMD)

println("lorenz:")
println("   x   = ", [x_lorenz[i] for i in instance.I])
println("   y   = ", [y_lorenz[i] for i in instance.I])
println("   X   = ", [[sum(X_lorenz[j,i,s] for i in instance.I) for j in instance.J] for s in instance.S])
#println("   Oi   = ", [[Oi_lorenz[j,r,s] for r in instance.J for j in instance.J] for s in instance.S])
#println("   p   = ", [[p_lorenz[j,s] for j in instance.J] for s in instance.S])
#println("   Z   = ", [[Z_lorenz[r,s] for r in instance.J] for s in instance.S])
println("   ut   = ", [ut_lorenz[s] for s in instance.S])
println("   G   = ", [G[s] for s in instance.S])
println("   obj = ", obj_lorenz)

println("difference in X = ", [[sum(X_diff[j,i,s] for i in instance.I) for j in instance.J] for s in instance.S])