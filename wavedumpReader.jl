mutable struct wdReader 
    recordLen::Int
    oldTimeTag::Float64
    timeTagRollover::Int
    boardId::Int
    file::IOStream

    function wdReader(filename)
        recordLen = 0 
        oldTimeTag = 0.0
        timeTagRollover = 0 
        boardId = 0 
        #filename=("$(@__DIR__)/led_trg_test.dat") 
        file = open(filename,"r") 
        new(recordLen, oldTimeTag, timeTagRollover, boardId, file)
    end
end 

mutable struct RawTrigger

    pattern::Int
    channel::Int
    eventCounter::Int
    triggerTimeTag::Int
    triggerTime::Float64

    trace::Vector{Float64}
    filePos::Int

    function RawTrigger()
        pattern=0
        channel=0
        eventCounter=0
        triggerTimeTag=0
        triggerTime=0.0

        trace=Array{Float64}(undef,1)
        filePos=0

        new(pattern,channel,eventCounter,triggerTimeTag,triggerTime,trace,filePos)
    end
end 

function getNextTrigger(wr::wdReader)

    header = Vector{Int32}(undef, (6))
    i0,i1,i2,i3,i4,i5 = read!(wr.file,header)

    eventsize = floor(Int32, (i0-24)/2)
    wr.boardId = i1 

    rt = RawTrigger()

    rt.pattern = i2 
    rt.channel = i3 
    rt.eventCounter = i4 
    rt.triggerTimeTag = i5 

    if rt.triggerTimeTag < wr.oldTimeTag
        wr.timeTagRollover += 1 
        wr.oldTimeTag = float(i5)

    else 
        wr.oldTimeTag = float(i5)
    end 

    rt.triggerTimeTag += wr.timeTagRollover*(2^31)
    rt.triggerTime = rt.triggerTimeTag * 8e-3

    header = Vector{UInt16}(undef, (eventsize))
    rt.trace = read!(wr.file,header)

    return rt  
end 


