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


# ================================================================================

@testitem "merge_episodes_v2 tests" begin
    include("../src/FindNodes.jl")
    
    # Тест 1: Нет разрыва
    @testset "No gap: merge segments" begin
        segments = [1:3, 5:7]
        form_pairs = [1=>"N", 2=>"N", 3=>"N", 4=>"N", 5=>"N", 6=>"N", 7=>"N"]
        merged = merge_episodes_v2(segments, form_pairs)
        @test merged == [1:7]
    end

    # Тест 2: 3 желудочковых -> разрыв
    @testset "3 ventricular: no merge" begin
        segments = [1:2, 6:7]
        form_pairs = [1=>"N", 2=>"N", 3=>"S1", 4=>"S2", 5=>"S3", 6=>"N", 7=>"N"]
        merged = merge_episodes_v2(segments, form_pairs)
        @test merged == [1:2, 6:7]
    end

    # Тест 3: 5 наджелудочковых -> разрыв
    @testset "5 supraventricular: no merge" begin
        segments = [1:2, 8:9]
        form_pairs = [1=>"N", 2=>"N", 3=>"V1", 4=>"V2", 5=>"V3", 6=>"V4", 7=>"V5", 8=>"N", 9=>"N"]
        merged = merge_episodes_v2(segments, form_pairs)
        @test merged == [1:2, 8:9]
    end

    # Тест 4: 2 желудочковых + 4 наджелудочковых -> объединение
    @testset "2 ventricular + 4 supraventricular: merge" begin
        segments = [1:2, 9:10]
        form_pairs = [1=>"N", 2=>"N", 3=>"S1", 4=>"S2", 5=>"V1", 6=>"V2", 7=>"V3", 8=>"V4", 9=>"N", 10=>"N"]
        merged = merge_episodes_v2(segments, form_pairs)
        @test merged == [1:10]
    end

    # Тест 5: 3 желудочковых + 4 наджелудочковых -> разрыв
    @testset "3 ventricular + 4 supraventricular: no merge" begin
        segments = [1:2, 10:11]
        form_pairs = [1=>"N", 2=>"N", 3=>"S1", 4=>"S2", 5=>"S3", 6=>"V1", 7=>"V2", 8=>"V3", 9=>"V4", 10=>"N", 11=>"N"]
        merged = merge_episodes_v2(segments, form_pairs)
        @test merged == [1:2, 10:11]
    end

    # Тест 6: Невалидные формы игнорируются
    @testset "Invalid forms ignored" begin
        segments = [1:2, 8:9]
        form_pairs = [1=>"N", 2=>"N", 3=>"X", 4=>"Z1", 5=>"Y", 6=>"V1", 7=>"V2", 8=>"N", 9=>"N"]
        merged = merge_episodes_v2(segments, form_pairs)
        @test merged == [1:2, 8:9]
    end

    # Тест 7: Комбинация валидных и невалидных
    @testset "Mixed valid/invalid" begin
        segments = [1:2, 10:11]
        form_pairs = [1=>"N", 2=>"N", 3=>"S1", 4=>"X", 5=>"S2", 6=>"Z", 7=>"S3", 8=>"V1", 9=>"V2", 10=>"F", 11=>"N", 12=>"N"]
        merged = merge_episodes_v2(segments, form_pairs)
        @test merged == [1:2, 10:11]
    end
end