@testset "Querying" begin
    server = InfluxServer("http://localhost:8086")
    dbname = "NOAA_water_database"

    # Simple query:
    data, = query(server, dbname, SELECT(measurements=["h2o_feet"]))
    @test size(data) == (15258, 4)

    # Simple query with limits:
    for limit in (1, 5, 100)
        data, = query(server, dbname, SELECT(measurements=["h2o_pH"], limit=limit))
        @test size(data) == (limit, 3)
    end

    # Double-measurement query, showing that the columns get merged
    feet_data, pH_data = query(server, dbname, SELECT(measurements=["h2o_feet", "h2o_pH"], limit=10))
    @test size(feet_data) == (10, 5)
    @test size(pH_data) == (10, 5)

    h2o_feet_data, h2o_pH_data = query(server, dbname,
        SELECT(;
            measurements=["h2o_feet", "h2o_pH"],
            limit=10
        ),
    )
    @test size(h2o_feet_data) == (10, 5)
    @test size(h2o_pH_data) == (10, 5)

    # Test WHERE clauses, fields/tags, and sub-limit results
    h2o_feet_data = query(server, dbname,
        SELECT(;
            fields=["water_level"],
            tags=["location"],
            measurements=["h2o_feet"],
            limit=20,
            condition=@querify(:location = "santa_monica" && :water_level > 7.0),
        ),
    )[1]
    @test size(h2o_feet_data) == (13, 3)
    @test mean(h2o_feet_data[!, :water_level]) > 7.0
end
