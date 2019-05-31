using MacroTools

export query, SELECT, @querify

# Recursively translate an Expr (garnered through `@where`) and turn it into a String
querify(e) = string(e)
querify(e::Symbol) = string("\"", e, "\"")
querify(e::AbstractString) = string("'", e, "'")
querify(e::QuoteNode) = querify(e.value)
function querify(e::Expr)
    args = e.args
    head = e.head

    # Peel :call and :macrocall nodes first
    if head == :call
        head = args[1]
        args = args[2:end]
    elseif head == :macrocall && length(args) == 3 && args[2] == nothing
        head = args[1]
        args = args[3:end]
    end

    if head == :&&
        head = "AND"
    elseif head == :||
        head = "OR"
    elseif head == Symbol("==")
        head = "="
    elseif head == :~
        head = "=~"
    elseif head == Symbol("@r_str")
        return string("/", args[1], "/")
    else
        head = string(head)
    end

    return string(querify(args[1]), " ", head, " ", querify(args[2]))
end

macro querify(ex)
    return querify(MacroTools.striplines(ex))
end

# A structure describing a database query
struct Query
    # "SELECT", "UPDATE", etc...
    verb::String

    # Fields and tags, e.g. what we're selecting
    fields::Vector{String}
    tags::Vector{String}

    # Measurements, e.g. what we're selecting from
    measurements::Vector{String}

    # QueryCondition, e.g. limiting our selection's scope
    condition::Union{String,Nothing}

    limit::Union{Int,Nothing}
end

function Query(verb::String; fields::Vector = String[],
                             tags::Vector = String[],
                             measurements::Vector = String[],
                             condition::Union{String,Nothing} = nothing,
                             limit::Union{Int,Nothing} = nothing)
    if isempty(fields) && !isempty(tags)
        @warn(
            "InfluxDB has strange behavior when 'fields' is empty but 'tags' is not!",
            "https://docs.influxdata.com/influxdb/v1.7/query_language/data_exploration/#selecting-tag-keys-in-the-select-clause",
        )
    end

    # Canonicalize everything, get correct types, etc...
    return Query(
        verb,
        String.(fields),
        String.(tags),
        String.(measurements),
        condition,
        limit,
    )
end


SELECT(;kwargs...) = Query("SELECT"; kwargs...)

function join_typed(io, v::Vector, type_name, delim = ",")
    if isempty(v)
        return
    end

    # Write out the first one
    write(io, "\"", v[1], "\"", "::", type_name)
    for idx in 2:length(v)
        write(io, delim, "\"", v[idx], "\"", "::", type_name)
    end
end

function payload(q::Query)
    buff = IOBuffer()
    payload!(buff, q)
    return String(take!(buff))
end

function payload!(io::IO, q::Query)
    write(io, q.verb, " ")

    # Start with fields/tags, e.g. what we're selecting
    if isempty(q.fields)
        write(io, "*")
    else
        join_typed(io, q.fields, "field")
        if !isempty(q.tags)
            write(io, ",")
            join_typed(io, q.tags, "tag")
        end
    end

    # If we have measurements, specify them here:
    if !isempty(q.measurements)
        write(io, " FROM ")
        join(io, [string("\"", m, "\"") for m in q.measurements], ",")
    end

    if q.condition != nothing
        write(io, " WHERE ")
        write(io, q.condition)
    end

    if q.limit != nothing
        write(io, " LIMIT ", string(q.limit))
    end
end

