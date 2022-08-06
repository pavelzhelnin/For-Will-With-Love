using JLD2; 

file = jldopen("example.jld2", "r") 

nEvents = file["event_num"] 

ns_per_sample = 2
spe_run = false 

function calc_baseline(w::Vector{Float64},xmin::Int,width::Int)
    calc_integral(w,xmin,width) / width 
end 

function check_saturation(w::Vector{Float64})
    for i in eachindex(w)
        if w[i] == 0 
            return true 
        end 
    end 
    return false 
end 

function calc_integral(w::Vector{Float64},xmin::Int,width::Int)
    integral = 0.0 
    for i in xmin:width+xmin
        try 
            integral += w[i]
        catch 
            return -999999
            break 
        end 
    end 
    return integral 
end 

function calc_CFD_sample(w::Vector{Float64}, pct_threshold::Float64)
    max = maximum(w) 
    i_max = findall(x -> x == max, w)

    for i in 1:i_max[1]
        if w[reverseind(w,i)] < pct_threshold*max
            return i
        end
    end 

    return -1 
end 

function calc_qmt(w::Vector{Float64},xmin::Int,width::Int)
    qmt = 0.0; 

    for i in xmin:width+xmin 
        try 
            qmt += w[i]*i
        catch 
            return -999999
        end 
    end 

    return qmt 

end 

jldopen("output_example.jld2","w") do output_file

for eventID in 1:nEvents-1
    event = file["eventID $eventID"]
    trace = event["trace"]
    trg_time = event["trg_time"]

    group = JLD2.Group(output_file, string("eventID $eventID"))
    group["trace"] = trace
    group["eventID"] = eventID
    group["trg_time"] = trg_time

    saturated = check_saturation(trace)

    group["saturated"] = saturated 

    baseline_width = 500

    if spe_run == true 
        baseline_width = 250
    end 

    baseline_xmin = 0

    baseline = calc_baseline(trace,baseline_xmin,baseline_width)

    group["baseline"] = baseline 

    for i in eachindex(trace)
        trace[i] = -1 * (trace[i] - baseline)
    end 

    waveform_max_time = findall(x->x == maximum(trace), trace) * ns_per_sample
    waveform_max = maximum(trace) - first(trace)

    group["waveform_max_time"] = waveform_max_time
    group["waveform_max"] = waveform_max

    CFD_threshold = 0.2; # Set thres. at 20%
	event_time = ns_per_sample * calc_CFD_sample(trace, CFD_threshold)

    group["event_time"] = event_time


    integral_xmin = 700
	integral_width = 2500
    integral_xmin_dy = integral_xmin 
	integral_width_dy = 750

    if spe_run == true 
        integral_xmin = 275
        integral_width = 75
    end 

    integral = calc_integral(trace, integral_xmin, integral_width)

    group["integral"] = integral 

    pretrace_integral_xmin = baseline_xmin + baseline_width
    pretrace_integral_width = 200

    pretrace_integral = calc_integral(trace, pretrace_integral_xmin, pretrace_integral_width)

    group["pretrace_integral"] = pretrace_integral

    if spe_run == true 
        pretrace_integral = -999
    end 

    posttrace_integral = 0

    group["posttrace_integral"] = posttrace_integral

    fast_xmin = integral_xmin
	fast_width = 200 / ns_per_sample
	psd = calc_integral(trace, fast_xmin, Int(fast_width)) / integral

    group["psd"] = psd 

    integral_xmin = 700
    integral_width = 2500

    qmt = ns_per_sample * calc_qmt(trace, integral_xmin, integral_width)

    group["qmt"] = qmt 

    if saturated == true 
        prev_evt_sat = true
    else 
        prev_evt_sat = false
    end 

    if eventID%10000 == 0 
        println("Processing event $eventID")
    end 
end 

end 

println("Processing complete!")
