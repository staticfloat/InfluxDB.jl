using JSON, HTTP
using HTTP.URIs: URI
import HTTP: get
import Base: write

export write, query

"""
    InfluxServer

Object that represents an InfluxDB server endpoint, with optional basic authentication
"""
struct InfluxServer
    # HTTP API endpoints
    endpoint::URI

    # Optional authentication stuffage
    username::Union{String,Nothing}
    password::Union{String,Nothing}

    # Build a server object that we can use in queries from now on
    function InfluxServer(address::AbstractString; username=nothing, password=nothing)
        # If there wasn't a schema defined (we only recognize http/https), default to http
        if match(r"^https?://", address) == nothing
            uri = URI("http://$address")
        else
            uri = URI(address)
        end

        # If we didn't get an explicit port, default to 8086
        if uri.port == 0
            uri =  URI(uri.scheme, uri.host, 8086, uri.path)
        end

        # URIs are the new hotness
        return new(uri, username, password)
    end
end

# Add authentication to a query dict, if we need to
function authenticate!(server::InfluxServer, query::Dict)
    if server.username != nothing && server.password != nothing
        query["u"] = server.username
        query["p"] = server.password
    end
end

function query(server::InfluxServer, query_data::Dict; type::Symbol = :get)
    # Add authentication to a query dict
    authenticate!(server, query_data)

    if type == :get
        response = HTTP.get(string(server.endpoint, "/query"); query=query_data)
    else
        response = HTTP.post(string(server.endpoint, "/query"); query=query_data)
    end
    response_data = String(response.body)
    if response.status != 200
        error(response_data)
    end

    # Grab JSON data
    response = JSON.parse(response_data)

    if !haskey(response, "results") || !haskey(response["results"][1], "series")
        return
    end
    
    # Convert the JSON object's values into a DataFrame
    function series_df(series_dict)
        df = DataFrame()
        for name_idx in 1:length(series_dict["columns"])
            col = Symbol(series_dict["columns"][name_idx])
            df[!, col] = [x[name_idx] for x in series_dict["values"]]
        end
        return df
    end

    # Return a DataFrame for each measurement we requested
    return series_df.(response["results"][1]["series"])
end

# Shortcut for the common case of just a single "q" data element
query(server::InfluxServer, data::AbstractString; kwargs...) = query(server, Dict("q" => data); kwargs...)

# Shortcut for Query objects
query(server::InfluxServer, db::AbstractString, q::Query) = query(server, Dict("q" => payload(q), "db" => db))



function write(server::InfluxServer, db::AbstractString, query_data::Dict, payload::AbstractString)
    # Add authentication to a data dict
    authenticate!(server, query_data)

    response = HTTP.post(string(server.endpoint, "/write"), [], payload; query=query_data)
    response_data = String(response.body)
    if response.status != 204
        error(response_data)
    end
    return nothing
end


function write(server::InfluxServer, db::AbstractString, measurements::Vector{Measurement}; precision = :nanosecond)
    if isempty(measurements)
        return
    end

    # Start by building our query dict, pointing at a particular database and timestamp precision
    prec_dict = Dict(
        :nanosecond => "ns", :ns => "ns", "ns" => "ns",
        :microsecond => "us", :us => "us", "us" => "us",
        :millisecond => "ms", :ms => "ms", "ms" => "ms",
        :second => "s", :s => "s", "s" => "s",
        :minute => "m", :m => "m", "m" => "m",
        :hour => "h", :h => "h", "h" => "h",
    )
    query_data = Dict(
        "db"=>db,
        "precision"=>prec_dict[precision],
    )

    # Next, build payload
    buff = IOBuffer()
    for m in measurements
        payload!(buff, m)
        write(buff, "\n")
    end

    return write(server, db, query_data, String(take!(buff)))
end
