using SyntheticGrids
using Test
using JSON

const RUN_PANDAPOWER_TESTS = lowercase(get(ENV, "SYNTHETICGRIDS_RUN_PANDAPOWER_TESTS", "false")) in ("1", "true", "yes")

@testset "SyntheticGrids" begin
    SEED = 666
    LATLIM = (38, 40)
    LONGLIM = (-89, -88)
    GENPATH = joinpath(@__DIR__, "..", "data", "GenData.json")
    CENSUSPATH = joinpath(@__DIR__, "..", "data", "Census_data.dat")
    GENCOORDPATH = joinpath(@__DIR__, "..", "data", "Generator_coord.dat")
    GENDATAPATH = joinpath(@__DIR__, "..", "data", "Generator_data.dat")
    DUMMYPATH = joinpath(@__DIR__, "..", "data", "dummy.json")
    DUMMYPPC = joinpath(@__DIR__, "..", "data", "dummy.p")
    GRIDPATH = joinpath(@__DIR__, "..", "data", "testgrid.json")

    function baseline_grid(seed=666, latlim=LATLIM, longlim=LONGLIM)
        grid = Grid(seed)
        place_loads_from_zips!(grid; latlim=latlim, longlim=longlim)
        place_gens_from_data!(grid; latlim=latlim, longlim=longlim)
        connect!(grid)
        create_lines!(grid)
        return grid
    end

    @testset "Grids" begin
        @testset "Load bus length" begin
            grid = Grid(SEED)
            place_loads_from_zips!(grid; latlim=LATLIM, longlim=LONGLIM)
            @test length(buses(grid)) == 130
        end

        @testset "Gen bus length" begin
            grid = Grid(SEED)
            place_gens_from_data!(grid; latlim=LATLIM, longlim=LONGLIM)
            @test length(buses(grid)) == 17
        end

        @testset "Adjacency sum" begin
            grid = baseline_grid()
            @test sum(adjacency(grid)) == 358
        end

        @testset "Bus type count" begin
            grid = baseline_grid()
            count = SyntheticGrids.count_bus_type(grid)
            @test count == (130, 17)
        end

        @testset "Trans lines" begin
            grid = baseline_grid()
            @test all(t.capacity > 0 for t in trans_lines(grid))
            @test length(trans_lines(grid)) == 179
            @test test_connectivity(grid.bus_conn, false)
            @test total_links(grid.bus_conn) == 179
            @test mean_node_deg(grid.bus_conn) ≈ 2.435374149659
            @test 5.0 <= mean_shortest_path(adjacency(grid)) <= 10.0
            @test 100.0 <= mean_shortest_path(adjacency(grid), distance(buses(grid))) <= 180.0
            @test robustness_line(grid.bus_conn, 10) > 1
            @test robustness_node(grid.bus_conn, 10) > 1
        end

        @testset "Add substation" begin
            grid = Grid(true)
            @test size(grid.bus_conn) == (137, 137)
            @test size(grid.sub_conn) == (43, 43)

            add_gen!(grid, (11., 11.), 100, [11], ["ki"], reconnect = false)
            add_load!(grid, (19.,12.), 100, 100, 100, reconnect = true)
            add_substation!(
                grid,
                (11., 18.),
                [11],
                1000,
                6000,
                500,
                Set(),
                [grid.buses[139], grid.buses[138]]
            )
            @test size(grid.bus_conn) == (139, 139)
            @test size(grid.sub_conn) == (44, 44)
        end

        @testset "Clustering grids" begin
            grid = baseline_grid()
            count = SyntheticGrids.count_bus_type(grid)
            cluster!(
                grid,
                round(Int, 0.3 * count[1]),
                round(Int, 0.05 * count[2]),
                round(Int, 0.5 * count[2])
            )
            @test length(substations(grid)) == 47
            @test grid.substations[1].population == 6193
            @test grid.substations[47].generation == 16.1
            @test test_connectivity(grid.sub_conn, false)
            @test 65 <= total_links(grid.sub_conn) <= 80
            @test 3.0 <= mean_shortest_path(sub_connectivity(grid) .> 0) <= 5.0
            @test mean_shortest_path(
                (sub_connectivity(grid) .> 0),
                distance(substations(grid))
                ) >= 90.0
            @test mean_shortest_path(
                (sub_connectivity(grid) .> 0),
                distance(substations(grid))
                ) <= 140.0
            @test robustness_line(grid.sub_conn, 10) > 1
            @test robustness_node(grid.sub_conn, 10) > 1
        end

        @testset "Test seeding and object comparison" begin
            grid = baseline_grid()
            grid1 = baseline_grid()

            @test grid == grid1
        end
    end

    @testset "Input and Output" begin
        @testset "Pandapower interface" begin
            if RUN_PANDAPOWER_TESTS
                grid = baseline_grid()
                pgrid = to_pandapower(grid, DUMMYPPC)
                ntrafo = length(pgrid.trafo)
                @test ntrafo > 0

                pgrid = SyntheticGrids.load_pp_grid(DUMMYPPC)
                @test length(pgrid.trafo) == ntrafo
                rm(DUMMYPPC)
            else
                @info "Skipping pandapower integration tests. Set SYNTHETICGRIDS_RUN_PANDAPOWER_TESTS=true to enable."
            end
        end

        @testset "Generator data" begin
            SyntheticGrids.prepare_gen_data(GENDATAPATH, GENCOORDPATH, DUMMYPATH)
            genjson = JSON.parsefile(GENPATH)
            dummyjson = JSON.parsefile(DUMMYPATH)
            @test genjson == dummyjson
            rm(DUMMYPATH)
        end

        @testset "Save and Load Grid" begin
            grid = baseline_grid()
            save(grid, GRIDPATH)
            lgrid = load_grid(GRIDPATH)
            @test adjacency(grid) == adjacency(lgrid)
            @test sub_connectivity(grid) == sub_connectivity(lgrid)
            lgrid = 0 # trying to solve issues with Windows locking permissions to GRIDPATH
            rm(GRIDPATH)
        end
    end
end
