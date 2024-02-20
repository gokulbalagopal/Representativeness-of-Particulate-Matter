using Pkg
Pkg.activate("representativenss")
using Dates,StatsPlots,StatsBase,CSV,DataFrames,Plots,LaTeXStrings
using Impute,RollingFunctions,OrderedCollections,Random,Distributions

function data_cleaning( path_to_csv)
    data_frame = CSV.read(path_to_csv,DataFrame)
    ms = [parse(Float64,x[20:26]) for x in data_frame[!,:dateTime]]
    data_frame.ms  = Second.(round.(Int,ms))
    data_frame.dateTime = [x[1:19] for x in data_frame[!,:dateTime]]
    data_frame.dateTime = DateTime.(data_frame.dateTime,"yyyy-mm-dd HH:MM:SS")
    data_frame.dateTime = data_frame.dateTime + data_frame.ms
    data_frame = select!(data_frame, Not(:ms))
    col_symbols = Symbol.(names(data_frame))
    data_frame = DataFrames.combine(DataFrames.groupby(data_frame, :dateTime), col_symbols[2:end] .=> mean)
    return data_frame,col_symbols
end

path_to_ips7100 = "D:\\UTD\\UTDFall2022\\VariogramsLoRa\\firmware\\data\\001e0636e547\\2023\\01\\02\\MINTS_001e0636e547_IPS7100_2023_01_02.csv"
col_symbols = data_cleaning(path_to_ips7100)[2]
data_frame = data_cleaning(path_to_ips7100)[1]


df = DataFrame()
df.dateTime = collect(data_frame.dateTime[1]:Second(1):data_frame.dateTime[length(data_frame.dateTime)])
df = outerjoin( df,data_frame, on = :dateTime)
df = sort!(df, (:dateTime))
df = DataFrames.rename!(df, col_symbols)
df = Impute.locf(df)|>Impute.nocb()
cols = ["dateTime","pc0.1","pc0.3","pc0.5","pc1.0","pc2.5","pc5.0","pc10.0","pm0.1","pm0.3","pm0.5","pm1.0","pm2.5","pm5.0","pm10.0"]
df = DataFrames.rename!(df, cols)
# df = df[1:86400,:]

latex_PM= ["PM"*latexstring("_{0.1}"),"PM"*latexstring("_{0.3}"),"PM"*latexstring("_{0.5}"),
            "PM"*latexstring("_{1.0}"),"PM"*latexstring("_{2.5}"),"PM"*latexstring("_{5.0}"),
            "PM"*latexstring("_{10.0}")]

latex_PC = ["Particle Count for "*s for s in latex_PM]
latex_ylabel = vcat(latex_PC,latex_PM)


df_hist = DataFrame()
df_hist.dateTime = collect(df.dateTime[1]+Minute(15):Second(1):df.dateTime[end]+Second(1))

for i in names(df)[2:end]
    h = []
    for j in 0:1:size(df)[1]-900
        println(j)
        push!(h,StatsBase.fit(Histogram,Float64.(df[!,i][1+j:900+j])))
    end
    df_hist[!,i] = h   
end

rep_csv_path = mkpath("D:\\UTD\\UTDSpring2023\\RepresentativenessofPM\\data\\")
#CSV.write(rep_csv_path*"/hist.csv",df_hist)################### okay till here #####################
dict_labels = OrderedDict(names(df_hist)[2:end].=>latex_ylabel)
#df = CSV.read("D:\\UTD\\UTDSpring2023\\RepresentativenessofPM\\data\\hist.csv",DataFrame)

# We can use the below code to plot the PDF of any pc, pm values
# h = StatsBase.fit(Histogram, randn(1000)) 
# r = h.edges[1]
# x = first(r)+step(r)/2:step(r):last(r)
# plot(h)
# plot!(x, h.weights)


function MeanSD(v)
    return sum(abs.(v .- mean(v)))/length(v)
end
#masd = MeanSD(df)
df_masd = DataFrame()
df_mean = DataFrame()
df_std = DataFrame()
ts = collect(df.dateTime[1]+Minute(15):Second(1):df.dateTime[end]+Second(1))
df_masd.RollingTime = ts
df_mean.RollingTime = ts
df_std.RollingTime = ts

for i in names(df[:,2:end])
    df_mean[!,i] = round.(rolling(mean,df[!,i],Int(900)),digits= 2) 
    df_std[!,i] = round.(rolling(std,df[!,i],Int(900)) ,digits= 2) 
    df_masd[!,i] = round.(rolling(MeanSD,df[!,i],Int(900)),digits= 2) 

end

df_hist[!,i][end]

pm_unit = "(μg/m"*latexstring("^3")*")"

for i in names(df_hist)[2:8]
    plot()
    h = df_hist[!,i][end]
    r = h.edges[1]
    x = first(r)+step(r)/2:step(r):last(r)
    display(plot!(h,ylabel ="Count",xlabel= dict_labels[i],
            label= "μ: "*string(df_mean[!,i][end])*"\n"*"σ: "*string(df_std[!,i][end])*"\n"*"mad: "*string(df_masd[!,i][end]), 
            markersize  = 5,
            markeralpha = 1.0,title = "2023-01-02"))
    png("D:\\UTD\\UTDSpring2023\\RepresentativenessofPM\\Plots\\dist_plots\\"*i)
    #display(plot!(x,h.weights))#Use a gaussian fit function here for the curve
end

for i in names(df_hist)[9:end]
    plot()
    h = df_hist[!,i][end]
    r = h.edges[1]
    x = first(r)+step(r)/2:step(r):last(r)
    display(plot!(h,ylabel ="Count",xlabel= dict_labels[i]*pm_unit,
            label= "μ: "*string(df_mean[!,i][end])*"\n"*"σ: "*string(df_std[!,i][end])*"\n"*"mad: "*string(df_masd[!,i][end]), 
            markersize  = 5,
            markeralpha = 1.0,title = "2023-01-02"))
    png("D:\\UTD\\UTDSpring2023\\RepresentativenessofPM\\Plots\\dist_plots\\"*i)
    #display(plot!(x,h.weights))#Use a gaussian fit function here for the curve
end



xrange = Time(round(df_masd.RollingTime[1],Dates.Hour(1))):Hour(3):Time(floor(df_masd.RollingTime[end-2],Dates.Minute(1)))


for i in names(df_masd)[2:8]
    scatter(Dates.Time.(df_masd.RollingTime)[1:end-2],df_masd[!,i][1:end-2], xlabel ="DateTime Rolling Window" ,
    ylabel= "Average Deviation of "*dict_labels[i],xrotation = 45,legend = false,xticks = xrange
    ,markerstrokewidth=0, title = "2023-01-02")
    png("D:\\UTD\\UTDSpring2023\\RepresentativenessofPM\\Plots\\mad_plots\\"*i)
end


for i in names(df_masd)[9:end]
    scatter(Dates.Time.(df_masd.RollingTime)[1:end-2],df_masd[!,i][1:end-2], xlabel ="DateTime Rolling Window" ,
    ylabel= "Average Deviation of "*dict_labels[i]*pm_unit,xrotation = 45,legend = false,
    xticks = xrange,markerstrokewidth=0, title = "2023-01-02")
    png("D:\\UTD\\UTDSpring2023\\RepresentativenessofPM\\Plots\\mad_plots\\"*i)
end

