using InfluxDB
using Base.Test

# write your own tests here
#@test 1 == 1
server = InfluxDB.InfluxServer("http://localhost:8086")
InfluxDB.create_db(server, "stats")
InfluxDB.query_series(server, "mydb", "cpu")
InfluxDB.write(server, "stats", "test", Dict("A" => 9, "B" => 5))
