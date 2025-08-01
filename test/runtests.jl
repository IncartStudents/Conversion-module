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
    
    @test occursin(build_regex_pattern("(rV|rVM);nD;(pP*|!pE*)"), "rV;nD;pP2")
    @test !occursin(build_regex_pattern("(rV|rVM);nD;(pP*|!pE*)"), "rVM;nD;pE")

    @test occursin(build_regex_pattern("(rV|rVM|rVP|rVD);nS;(pP*|!pE*)"), "rV;pP;nS")
    
    @test occursin(build_regex_pattern("(rV|rVM);nG;fR|(pP*&!fT)"), "rV;nG;fR")
    @test occursin(build_regex_pattern("(rV|rVM);nG;fR|(pP*&!fT)"), "rVM;nG;pP2;fR")
    @test !occursin(build_regex_pattern("(rV|rVM);nG;fR|(pP*&!fT)"), "rVM;nG;pP;fT")
end

@testitem "случаи ошибочного нахождения" begin 
    include("../src/FindNodes.jl")
    @test occursin(build_regex_pattern("(rS|rM);nS;pP*"), "rSA;pP;nS")
    @test occursin(build_regex_pattern("rF"), "rFA;pP;nP")
    @test occursin(build_regex_pattern("(rV|rVM);nD;(pP*|!pE*)"), "rVD;vV;pP;nD")
end


# ================================================================================

@testitem "тесты для новой функции" begin 
    include("../src/FindNodes.jl")

    @test occursin(build_regex_pattern_v2("rV*"), "rV1")
    @test occursin(build_regex_pattern_v2("rV*"), "rV")

    @test !occursin(build_regex_pattern_v2("!nD"), "nD")
    @test occursin(build_regex_pattern_v2("!nD"), "bB")

    @test occursin(build_regex_pattern_v2("(rSM|rSI)"), "rSM")
    @test occursin(build_regex_pattern_v2("(rSM|rSI)"), "rSI")

    @test occursin(build_regex_pattern_v2("(rSM|rSI);pP"), "rSM;pP")
    @test occursin(build_regex_pattern_v2("(rSM|rSI);pP"), "rSI;pP")

    @test occursin(build_regex_pattern_v2("(rSM|rSI);nD;pP*;!fT"), "rSM;nD;pP2;fR")
    @test !occursin(build_regex_pattern_v2("(rSM|rSI);nD;pP*;!fT"), "rSI;nD;pP;fT")
    
    @test occursin(build_regex_pattern_v2("(rV|rVM);nD;(pP*|!pE*)"), "rV;nD;pP2")
    @test !occursin(build_regex_pattern_v2("(rV|rVM);nD;(pP*|!pE*)"), "rVM;nD;pE")

    @test occursin(build_regex_pattern_v2("(rV|rVM|rVP|rVD);nS;(pP*|!pE*)"), "rV;pP;nS")
    
    @test occursin(build_regex_pattern_v2("(rV|rVM);nG;fR|(pP*&!fT)"), "rV;nG;fR")
    @test occursin(build_regex_pattern_v2("(rV|rVM);nG;fR|(pP*&!fT)"), "rVM;nG;pP2;fR")
    @test !occursin(build_regex_pattern_v2("(rV|rVM);nG;fR|(pP*&!fT)"), "rVM;nG;pP;fT")

    @test !occursin(build_regex_pattern_v2("(rS|rM);nS;pP*"), "rSA;pP;nS")
    @test !occursin(build_regex_pattern_v2("rF"), "rFA;pP;nP")
    @test !occursin(build_regex_pattern_v2("(rV|rVM);nD;(pP*|!pE*)"), "rVD;vV;pP;nD")
end