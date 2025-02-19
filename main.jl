include("helpers.jl")
include("gini.jl")
include("mandell.jl")
using JuMP

TotalFacilities = 2
TotalClients = 4
TotalScenarios = 4

# Solving the full space problem for reference
instance = generate_instance(TotalFacilities, TotalClients, TotalScenarios)
print_instance(instance)

# Solving 2SSP
mandell_model = generate_full_problem_mandell(instance)
f = open("mandell_model.lp", "w")
print(f, mandell_model)
close(f)
gini_model = generate_full_problem_gini(instance)
f = open("gini_model.lp", "w")
print(f, gini_model)
close(f)

optimize!(mandell_model)
optimize!(gini_model)

x_mandell = Int.(round.(value.(mandell_model[:x]).data))
y_mandell = value.(mandell_model[:y])
u_mandell = value.(mandell_model[:u])
X_mandell = value.(mandell_model[:X])
obj_mandell = objective_value(mandell_model)

x_gini = Int.(round.(value.(gini_model[:x]).data))
y_gini = value.(gini_model[:y])
X_gini = value.(gini_model[:X])
Oi_gini = value.(gini_model[:Oi])
ut_gini = value.(gini_model[:Ut])
p_gini = value.(gini_model[:p])
Z_gini = value.(gini_model[:Z])
obj_gini = objective_value(gini_model)

X_diff = round.(X_mandell .- X_gini, digits=3)

println("Mandell:")
println("   x   = ", [x_mandell[i] for i in instance.I])
println("   y   = ", [y_mandell[i] for i in instance.I])
#println("   D   = ", [[instance.D[j,s] for j in instance.J] for s in instance.S])
println("   X   = ", [[sum(X_mandell[j,i,s] for i in instance.I) for j in instance.J] for s in instance.S])
println("   obj = ", obj_mandell)

println("Gini:")
println("   x   = ", [x_gini[i] for i in instance.I])
println("   y   = ", [y_gini[i] for i in instance.I])
println("   X   = ", [[sum(X_gini[j,i,s] for i in instance.I) for j in instance.J] for s in instance.S])
#println("   Oi   = ", [[Oi_gini[j,r,s] for r in instance.J for j in instance.J] for s in instance.S])
#println("   p   = ", [[p_gini[j,s] for j in instance.J] for s in instance.S])
#println("   Z   = ", [[Z_gini[r,s] for r in instance.J] for s in instance.S])
#println("   ut   = ", [ut_gini[s] for s in instance.S])
println("   obj = ", obj_gini)

println("difference in X = ", [[sum(X_diff[j,i,s] for i in instance.I) for j in instance.J] for s in instance.S])

# write_to_file(
#     gini_model,
#     "ginimodeeeellllll.lp"
# )