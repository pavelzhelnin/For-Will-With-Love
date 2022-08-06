using Pkg;
using JLD2;

@time begin 
include("$(@__DIR__)/wavedumpReader.jl")

#if ARGS[1] == ARGS[2]
    #println("Error:  Output file cannot have same name as input file.")
#end 

infile_name = string("$(@__DIR__)/", ARGS[1])
println(ARGS[1])
wd = wdReader(infile_name)
rt = RawTrigger

println("Processing file: ", infile_name)

tr = getNextTrigger(wd)
event_num = 0 

jldopen("example.jld2","w") do file 
    while tr != nothing 
        trace = tr.trace
        eventID = tr.eventCounter
        trg_time = Int(round(tr.triggerTime*1000))
        global event_num+=1

        group = JLD2.Group(file, string("eventID $eventID"))
        group["trace"] = trace
        group["eventID"] = eventID
        group["trg_time"] = trg_time 

        try 
            global tr = getNextTrigger(wd)
        catch
            println("end of file")
            println("Processing final event ", event_num)
            break 
        end 
        if event_num % 10000 == 0
            println("Processing event ", event_num)
        end  
    end
    file["event_num"] = event_num
end
end