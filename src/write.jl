export Measurement

struct Measurement
    name::String
    fields::Dict{String,Union{String,Int,Float64}}
    tags::Dict{String,String}
    timestamp::Float64

    function Measurement(name::AbstractString, fields::Dict, tags::Dict, timestamp::Float64 = time())
        return new(
            String(name),
            Dict(String(k) => v for (k, v) in fields),
            Dict(String(k) => String(v) for (k, v) in tags),
            timestamp,
        )
    end
end

function payload(m::Measurement)
    buff = IOBuffer()
    payload!(buff, m)
    return String(take!(buff))
end

writify(x) = string(x)
writify(x::AbstractString) = string("\"", x, "\"")

function payload!(io::IO, m::Measurement)
    write(io, m.name)
    if !isempty(m.tags)
        join(io, [",$(k)=$(v)" for (k, v) in m.tags])
    end
    write(io, " ")
    join(io, ["$(k)=$(writify(v))" for (k, v) in m.fields], ",")
    write(io, " ")
    write(io, string(round(Int64, m.timestamp*1e9)))
end
