using Test
using TestItems
using TestItemRunner


@run_package_tests

@testitem "*" begin 
    include("../src/FindNodes.jl")
    @test occursin(build_regex_pattern("rV*"), "rV1")
    @test occursin(build_regex_pattern("rV*"), "rV")
end

@testitem "!" begin 
    include("../src/FindNodes.jl")
    @test !occursin(build_regex_pattern("!nD"), "nD")
    @test occursin(build_regex_pattern("!nD"), "bB")
end

@testitem "|" begin 
    include("../src/FindNodes.jl")
    @test occursin(build_regex_pattern("(rSM|rSI)"), "rSM")
    @test occursin(build_regex_pattern("(rSM|rSI)"), "rSI")
end

@testitem "| + часть строки" begin 
    include("../src/FindNodes.jl")
    @test occursin(build_regex_pattern("(rSM|rSI);pP"), "rSM;pP")
    @test occursin(build_regex_pattern("(rSM|rSI);pP"), "rSI;pP")
end

@testitem "строка полностью" begin 
    include("../src/FindNodes.jl")
    @test occursin(build_regex_pattern("(rSM|rSI);nD;pP*;!fT"), "rSM;nD;pP2;fR")
    @test !occursin(build_regex_pattern("(rSM|rSI);nD;pP*;!fT"), "rSI;nD;pP;fT")
end
