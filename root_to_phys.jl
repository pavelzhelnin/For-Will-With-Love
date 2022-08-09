using JLD2; 

file = jldopen("example.jld2", "r") 

const nEvents = file["event_num"] 
const ns_per_sample = 2

"""
Calculates the first part of the 
"""
function calc_baseline(w::Vector{Float64},xmin::Int,width::Int)
    calc_integral(w,xmin,width) / width 
end 


"""
Determines if PMT saturates out (if the PMT readout goes to zero)
"""
function check_saturation(w::Vector{Float64})
    any(w.==0)

    #element-wise compares w to zero 
    #if any of those are True return true 

end 

function calc_integral(w::Vector{Float64},xmin::Int,width::Int)

    if xmin+width > length(w)
        return -1.0
    end

    #sum(@inbounds w[xmin:xmin+width])
    #@inbounds actually doesn't check if your memory is inbounds 
    #if you mess up indexing you start grabbing random memory 
    #check if this works 

    sum(w[xmin:xmin+width])
end 

function calc_CFD_sample(w::Vector{Float64}, pct_threshold::Float64)
    thresh = maximum(w) * pct_threshold
    i_max = argmax(w) 
    idx = findlast(w[1:i_max] .< thresh)
    if idx == nothing
        idx = -1
    end
    idx, i_max
    # for i in 1:i_max

    #     if w[reverseind(w,i)] < pct_threshold*max
    #         return i
    #     end
    # end 

    # return -1 
end 

function event_loop()
    event_loop("output_example.jld2", nEvents)
end

function event_loop(nEvents::Int)
    event_loop("output_example.jld2", nEvents)
end

function event_loop(outfile::String)
    event_loop(outfile, nEvents)
end

function event_loop(outfile::String, nEvents::Int)
    trace = ones(250)
    jldopen(outfile,"w") do output_file
    for eventID in 1:nEvents-1
        event = file["eventID $eventID"]
        trace .= event["trace"]
        trg_time = event["trg_time"]

        group = JLD2.Group(output_file, string("eventID $eventID"))
        group["trace"] = trace
        group["eventID"] = eventID
        group["trg_time"] = trg_time

        saturated = check_saturation(trace)

        group["saturated"] = saturated 

        baseline_width = 80
        baseline_xmin = 1

        baseline = calc_baseline(trace,baseline_xmin,baseline_width)

        group["baseline"] = baseline 

        #trace is a vector, .- is a broadcast subtraction 
        #this is equal to trace = trace - baseline 
        trace .-= baseline 

        CFD_threshold = 0.2; # Set thres. at 20%
        idx_thresh, idx_max = calc_CFD_sample(trace, CFD_threshold)
        waveform_max_time = idx_max * ns_per_sample
        event_time = ns_per_sample * idx_thresh
        waveform_max = trace[idx_max] - first(trace)
        # waveform_max_time = findall(x->x == maximum(trace), trace) * ns_per_sample

        group["waveform_max_time"] = waveform_max_time
        group["waveform_max"] = waveform_max
        group["event_time"] = event_time

        integral_xmin = 87
        integral_width = 35

        integral = calc_integral(trace, integral_xmin, integral_width)

        group["integral"] = integral 

        pretrace_integral_xmin = 1
        pretrace_integral_width = 8

        pretrace_integral = calc_integral(
            trace,
            pretrace_integral_xmin,
            pretrace_integral_width
        )

        group["pretrace_integral"] = pretrace_integral

        fast_xmin = integral_xmin
        fast_width = 20 / ns_per_sample
        psd = calc_integral(trace, fast_xmin, Int(fast_width)) / integral

        group["psd"] = psd 
        prev_evt_sat = saturated
        # if saturated == true 
        #     prev_evt_sat = true
        # else 
        #     prev_evt_sat = false
        # end 

        group["prev_evt_sat"] = prev_evt_sat

        if eventID % 10000 == 0 
            println("Processing event $eventID")
        end 
    end 
end 
end

println("Processing complete!")
