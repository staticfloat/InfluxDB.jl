using InfluxDB, Statistics
using Test

container_id = nothing
try
    # First, build the test server
    success(`docker build -t influxdbjl_test_server influx_test_instance`)

    # Next, run it in the background
    global container_id = chomp(String(read(`docker run -d --rm -p 8086:8086 influxdbjl_test_server`)))
    @info("Started testing docker influxdb container, running in container $(container_id)")

    include("querying.jl")
    include("databases.jl")
    include("writing.jl")
finally
    if container_id != nothing
        @info("Stopping docker influxdb container $(container_id)")
        run(`docker stop $(container_id)`)
    end
end