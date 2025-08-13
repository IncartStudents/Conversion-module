module ReadXML

using EzXML
using StructArrays
using Dates
using Descriptors

export readxml_rhythms_arrs, readxml_pqrst_anz

include("xml.jl")
include("xml_arrs.jl")

end # module
