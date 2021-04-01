export Measurement

struct Measurement
    name::String
    fields::Dict{String,Union{String,Int,Float64,Bool}}
    tags::Dict{String,String}
    timestamp::Float64

    function Measurement(name, fields, tags, timestamp = time())
        return new(
            String(name),
            Dict(String(k) => v for (k, v) in fields),
            Dict(String(k) => String(v) for (k, v) in tags),
            Float64(timestamp),
        )
    end
end

function payload(m::Measurement)
    buff = IOBuffer()
    payload!(buff, m)
    return String(take!(buff))
end

function check_allowed(x)
    contains(x, '\n') && error("'\\n' not allowed in " * repr(x))
    endswith(x, '\\') && error("'\\\\' not allowed at the end of " * repr(x))
    return true
end

function escape_measurement(x)
    check_allowed(x)
    x = replace(x, r"(\\[ ,=\"])" => s"\\\1")
    x = replace(x, r"([ ,=\"])" => s"\\\1")
    return x
end

escape_tag(x)           = (check_allowed(x) && replace(x, r"([ ,=])" => s"\\\1"))
escape_tag_key(x)       = (check_allowed(x) && replace(x, r"([ ,=])" => s"\\\1"))
escape_field_key(x)     = (check_allowed(x) && replace(x, r"([ ,=\"])" => s"\\\1"))
escape_field(x::String) = '"' * replace(x, r"([\"\\])" => s"\\\1") * '"'
escape_field(x::Number) = string(x)

function payload!(io::IO, m::Measurement)
    write(io, escape_measurement(m.name))
    if !isempty(m.tags)
        join(io, [",$(escape_tag_key(k))=$(escape_tag(v))" for (k, v) in m.tags])
    end
    write(io, " ")
    join(io, ["$(escape_field_key(k))=$(escape_field(v))" for (k, v) in m.fields], ",")
    write(io, " ")
    write(io, string(round(Int64, m.timestamp*1e9)))
end
