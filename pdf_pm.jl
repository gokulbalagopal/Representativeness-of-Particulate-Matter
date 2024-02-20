using StatsBase, Random, StatsPlots;
Random.seed!(1234)
println("values",randn(1000))
println("minimum: ",minimum(randn(1000)))
println("maximum: ",maximum(randn(1000)))
h = StatsBase.fit(Histogram, randn(1000)) 
r = h.edges[1]
x = first(r)+step(r)/2:step(r):last(r)
plot(h)
plot!(x, h.weights)