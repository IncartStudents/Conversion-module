module MyProject

using FileUtils
using ExtractMkp

include("AlgResultParser.jl")
include("CalcStats.jl")
include("C:/incart_dev/ExtractMkp.jl/src/dict.jl")


function save_resumedata()
    parsed_data = AlgResultParser.parse_algresult(filepath)
    stats = CalcStats.calculate_statistics(parsed_data)
end


end # module