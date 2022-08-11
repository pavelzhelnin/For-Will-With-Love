using Pkg;
using JLD2;

include("$(@__DIR__)/wavedumpReader.jl")

infile_name = "$(ARGS[1])"

wd = wdReader("$(@__DIR__)/$(ARGS[1])")
rt = RawTrigger

const ns_per_sample = 2

println("Processing file: ", infile_name)

function get_trigger(wd::wdReader)
    getNextTrigger(wd)
end

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
end 

function trace_loop(outfile::String)
    jldopen(outfile,"w") do file 
        flag = true 
        while flag == true 
            try 
                tr = getNextTrigger(wd)
                #take this out after testing 

                trace = tr.trace
                eventID = tr.eventCounter + 1 
                event_num = eventID

                trg_time = Int(round(tr.triggerTime*1000))
                
                group = JLD2.Group(file, string("eventID $eventID"))
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

                if event_num % 10000 == 0
                    println("Processing event ", event_num)
                end
            catch 
                println("end of file")
                break
            end
        end
    end
end

trace_loop("output_example.jld2")