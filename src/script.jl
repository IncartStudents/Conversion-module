using FileUtils
using Printf
using ExtractMkp


include("CalcStats.jl")

include("C:/incart_dev/ExtractMkp.jl/src/dict.jl")

filepath = "C:/incart_dev/Myproject/data/AlgResult.xml"


res = readxml_rhythms_arrs(filepath)

arr_pairs = res[1]    # Rhythms in xml-file
arr_tuples = res[2]   # Arrhythmias in xml-file
metadata = res[3]


arrhythmias = Vector{Vector{Enum}}()

for nt in arr_tuples
    codes = split(nt.code, ';')
    for code in codes
        for mod in keys(DICT)
            val = get(DICT[mod], code, nothing)
            if val !== nothing
                push!(arrhythmias, val)
            end
        end
    end
end

println(arrhythmias)

# beats, seg_AG, seg_VF, meta = read_gost47(filepath)
# readxml_dict(filepath)

pqrst = readxml_pqrst_anz(filepath)

calc_qrs_stats(pqrst[1])

calc_qrs_statsv3(pqrst[1])


# ================================================================================


rhythm_hierarchy = Dict{String, Any}(
    "sinus" => Dict(
        "name" => "Синусовый ритм",
        "codes" => ["®;rN", "@;rN"],
        "params" => ["TotalDuration", "TotalDurationPercent"],
        "children" => Dict()
    ),
    "atrial" => Dict(
        "name" => "Предсердные",
        "codes" => ["®;(rSA|rSI)", "@;(rSA|rSI)"],
        "params" => [],
        "children" => Dict(
            "premature" => Dict(
                "name" => "Предсердные экстрасистолы",
                "codes" => ["--"],
                "params" => [],
                "children" => Dict(
                    "single" => Dict(
                        "name" => "Одиночные",
                        "codes" => ["@;(rSA|rSI);nS;pP*"],
                        "params" => ["CmpxCount", "CmpxPercent"],
                        "children" => Dict(
                            "aberrant" => Dict(
                                "name" => "С аберрантным проведением",
                                "codes" => ["@;(rSA|rSI);nS;pP*;vA*"],
                                "params" => ["CmpxCount"],
                                "children" => Dict()
                            )
                        )
                    )
                )
            )
        )
    ),
    "vent-classic" => Dict(
        "name" => "Желудочковые классические",
        "codes" => [],
        "params" => [],
        "children" => Dict(
            "premature" => Dict(
                "name" => "Желудочковые экстрасистолы",
                "codes" => [],
                "params" => [],
                "children" => Dict(
                    "single" => Dict(
                        "name" => "Одиночные",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict(
                            "V" => Dict(
                                "name" => "Неуточненные",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict(
                                    "bi" => Dict(
                                        "name" => "Бигеминия",
                                        "codes" => [],
                                        "params" => [],
                                        "children" => Dict()
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )
    )
)


function find_rhythm_path(code, tree)
    path = []
    current_node = tree
    while true
        matched = false
        # Check if "children" key exists and is a Dict
        if haskey(current_node, "children") && isa(current_node["children"], Dict)
            for (key, node) in current_node["children"]
                # Проверяем совпадение с любым шаблоном в `codes`
                for pattern in node["codes"]
                    if occursin(Regex(pattern), code)
                        push!(path, key)
                        current_node = node
                        matched = true
                        break
                    end
                end
                matched && break
            end
        else
            break
        end
        !matched && break
    end
    # Return params if key exists, else empty array
    return path, haskey(current_node, "params") ? current_node["params"] : []
end


code = "rN;pE"
path, params = find_rhythm_path(code, rhythm_hierarchy)

# Вывод результата
println("Путь: ", join(path, " → "))
println("Параметры: ", params)

