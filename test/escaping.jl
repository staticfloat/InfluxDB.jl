@testset "Escaping" begin
    import InfluxDB: escape_field, escape_tag, escape_field_key, escape_tag_key, escape_measurement
    dontescape = join(['a':'z'; 'A':'Z'; '0':'9'; "!#\$%&'()*+-./:;<>?@[]^_`{|}~"; "ᕙ༼*◕_◕*༽ᕤ😆😎😵😗😈🐻💓🌼🎁🎂📱💻"])

    server = InfluxServer("http://localhost:8086")
    create_database(server, "escape_test")
    
    @testset "Escaping measurement" begin
        #@test_throws ErrorException escape_measurement("\n")
        @test_throws ErrorException escape_measurement("a\\")

        tests = [
            dontescape => dontescape
            "a\\a"     => "a\\a"
            "b "       => "b\\ "
            "c,"       => "c\\,"
            "d="       => "d\\="
            "e\""      => "e\\\""
            "f\\\\f"   => "f\\\\f"
            "g\\ "     => "g\\\\\\ "
            "h\\,"     => "h\\\\\\,"
            "i\\="     => "i\\\\\\="
            "j\\\""    => "j\\\\\\\""
        ]
        write(server, "escape_test", Measurement.(first.(tests), Ref(Dict("a"=>"1")), Ref(Dict("b"=>"2"))))
        meas, = InfluxDB.list_measurements(server, "escape_test")

        for (str, exp) in tests
            @test escape_measurement(str) == exp
            @test str ∈ meas.name
        end
    end

    @testset "Escaping field" begin

        tests = [
            dontescape*'\n' => '"' * dontescape*'\n' * '"'
            "a\\"      => "\"a\\\\\""
            "b "       => "\"b \""
            "c,"       => "\"c,\""
            "d="       => "\"d=\""
            "e\""      => "\"e\\\"\""
            "f\\\\"    => "\"f\\\\\\\\\""
            "g\\ "     => "\"g\\\\ \""
            "h\\,"     => "\"h\\\\,\""
            "i\\="     => "\"i\\\\=\""
            "j\\\""    => "\"j\\\\\\\"\""
        ]
        for (i, (str, exp)) in enumerate(tests)
            @test escape_field(str) == exp
            write(server, "escape_test", [Measurement("test_field", Dict("a" => str, "i" => i), Dict("b"=>"1"), i)])
            df, = query(server, "escape_test", SELECT(;measurements=["test_field"], condition="\"i\"=$i"))
            @test df.a[1] == str
        end
        
        @test escape_field(123) == "123"
        @test escape_field(1.0) == "1.0"
        @test escape_field(true) == "true"

        m = Measurement(
            "test_field",
            Dict("c" => 123, "d" => 1.4, "e" => false, "i" => 1000),
            Dict("b" => "1"),
            1000
        )

        write(server, "escape_test", [m])
        df, = query(server, "escape_test", SELECT(;measurements=["test_field"], condition="\"i\"=1000"))
        @test df.c[1] == 123
        @test df.d[1] == 1.4
        @test df.e[1] == false
    end

    @testset "Escaping tag" begin
        @test_throws ErrorException escape_tag("\n")
        @test_throws ErrorException escape_tag("a\\")
        tests = [
            dontescape => dontescape
            "a\\a"     => "a\\a"
            "b "       => "b\\ "
            "c,"       => "c\\,"
            "d="       => "d\\="
            "e\""      => "e\""
            "f\\\\f"   => "f\\\\f"
            "g\\ "     => "g\\\\ "
            "h\\,"     => "h\\\\,"
            "i\\="     => "i\\\\="
            "j\\\""    => "j\\\""
        ]
        for (i, (str, exp)) in enumerate(tests)
            @test escape_tag(str) == exp
            write(server, "escape_test", [Measurement("test_tag", Dict("i" => i), Dict("a"=>str), i)])
            df, = query(server, "escape_test", SELECT(;measurements=["test_tag"], condition="\"i\"=$i"))
            @test df.a[1] == str
        end
    end

    @testset "Escaping field key" begin
        @test_throws ErrorException escape_field_key("\n")
        @test_throws ErrorException escape_field_key("a\\")

        tests = [
            dontescape => dontescape
            "a\\a"     => "a\\a"
            "b "       => "b\\ "
            "c,"       => "c\\,"
            "d="       => "d\\="
            "e\""      => "e\\\""
            "f\\\\f"   => "f\\\\f"
            # "g\\ "     => "g\\\\ " # ???
            # "h\\,"     => "h\\\\," # ???
            # "i\\="     => "i\\\\=" # ???
            # "j\\\""    => "j\\\"" # ???
        ]

        for (i, (str, exp)) in enumerate(tests)
            @test escape_field_key(str) == exp
            write(server, "escape_test", [Measurement("test_field_key", Dict("i" => i, str => true), Dict("a"=>"1"), i)])
            df, = query(server, "escape_test", SELECT(;measurements=["test_field_key"], condition="\"i\"=$i"))
            @test str ∈ names(df) && df[1,str] == true
        end
    end

    @testset "Escaping tag key" begin
        @test_throws ErrorException escape_tag_key("\n")
        @test_throws ErrorException escape_tag_key("a\\")

        tests = [
            dontescape => dontescape
            "a\\a"     => "a\\a"
            "b "       => "b\\ "
            "c,"       => "c\\,"
            "d="       => "d\\="
            "e\""      => "e\""
            "f\\\\f"   => "f\\\\f"
            # "g\\ "     => "g\\\\ " # ???
            # "h\\,"     => "h\\\\," # ???
            # "i\\="     => "i\\\\=" # ???
            # "j\\\""    => "j\\\"" # ???
        ]

        for (i, (str, exp)) in enumerate(tests)
            @test escape_tag_key(str) == exp
            write(server, "escape_test", [Measurement("test_tag_key", Dict("i" => i), Dict("a"=>"1", str => "1"), i)])
            df, = query(server, "escape_test", SELECT(;measurements=["test_tag_key"], condition="\"i\"=$i"))
            @test str ∈ names(df) && df[1,str] == "1"
        end
    end
end
