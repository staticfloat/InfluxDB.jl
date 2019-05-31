@testset "Databases" begin
    server = InfluxServer("http://localhost:8086")

    dbs, = list_databases(server)
    @test "NOAA_water_database" in dbs[:name]
    @test !("foofoo" in dbs[:name])

    create_database(server, "foofoo")
    dbs, = list_databases(server)
    @test "NOAA_water_database" in dbs[:name]
    @test "foofoo" in dbs[:name]
end