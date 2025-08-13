
"""
Чтение из AlgResult.xml - битсетов ритмов и аритмий в привязке к комплексам
"""
function readxml_rhythms_arrs(file::AbstractString)
    doc = readxml(file)
    getxml_rhythms_arrs(doc.root)
end

# после открытия файла получаем узлы по getxml
function getxml_rhythms_arrs(root::EzXML.Node)

    node_info = findfirst("/ComparisonData/Examination/ExamInfo", root)
    info = xmlnode2dict(node_info)["ExamInfo"]
    timestart = parse(DateTime, info["Start"])
    fs = info["ECGFd"][1]
    point_count = info["PointCount"][1]

    sleep = findfirst("/ComparisonData/Examination/ExamFragments", root)
    sleep_info = xmlnode2dict(sleep)["ExamFragments"]
    sleep_info_res = Dict()
    for (k, v) in sleep_info
        filtered_v = Dict()
        for (k1, v1) in v
            if k1 == "ECGStartPoints" || k1 == "ECGDurationPoints"
                filtered_v[k1] = v1
            end
        end
        if !isempty(filtered_v)
            sleep_info_res[k] = filtered_v
        end 
    end

    hr_node = findfirst("/ComparisonData/Examination/HR", root)
    hr_trend_info = xmlnode2dict(hr_node)["HR"]
    hr_trend_info_res = Dict()
    for (k, v) in hr_trend_info
        if k == "HR10"
            hr_trend_info_res[k] = v
        end
    end

    motion_node = findfirst("/ComparisonData/Examination/Motion", root)
    motion_trend_info = xmlnode2dict(motion_node)["Motion"]

    rhythms = get_rhythms(root)
    arrs = getxml_arrs(root) # разные объединения аритмий - это все от лукавого...
    
    return rhythms, arrs, (; timestart, fs, point_count), sleep_info_res, 
    hr_trend_info_res["HR10"]["Trend"], motion_trend_info["MotionBitSet10"]
end

# gvg: все что ниже - внутренние функции, ими никто не будет пользоваться
# все что надо - один раз прочитать все данные о ритмах и аритмиях из xml-файла


"""
Извлечь ритмы из XML - структуры
"""
function get_rhythms(doc) # ::Vector{CodeBitset}
    rhythms = get_rhythms_xml(doc)

    rhythm_codes = map(rhythms) do rhythm
        (
        rhythm_code = rhythm["info"]["code"],
        bitvec = _split_bitset_to_bitvector(rhythm["BitSet"]),
        title = rhythm["info"]["title"]
        )
    end

    if (isempty(rhythm_codes)) return Vector{Pair{String, BitVector}}() end;

    return rhythm_codes
end

function get_rhythms_xml(root::EzXML.Node)
    node_rhythms = findfirst("/ComparisonData/Examination/Rhythms", root)
    xml_rhythms = xmlnode2dict(node_rhythms)["Rhythms"]
    rhythm_keys = filter(rhythm_key -> occursin("Rhythm", rhythm_key), collect(keys(xml_rhythms)))
    if (isempty(rhythm_keys)) return Vector{Dict{String, Any}}() end

    rhythms = getindex.(Ref(xml_rhythms), rhythm_keys)

    return rhythms
end

# TODO: поправить нижележащие функции
# сначала ВСЕГДА конвертируем рутинные типы данных (строки в битсеты и т.д.)
# а потом уже решаем, что нам по смыслу преобразовывать (или нет)
function getxml_arrs(root::EzXML.Node)
    arrs = get_arrhythmias_xml(root)

    leaf_arrs = filter(arr -> get(arr["info"], "is_leave", "false") == "true", arrs)
    if isempty(leaf_arrs)
        return Vector{NamedTuple}()
    end

    map(leaf_arrs) do arr
        bitvec = _split_bitset_to_bitvector(arr["BitSet"])
        rhythm_code = arr["info"]["rhythm_code"]
        code = arr["info"]["code"]
        title = arr["info"]["title"]
        len = arr["EpisodesInfo"]["Lengths"]
        starts = arr["EpisodesInfo"]["Starts"]
        (; rhythm_code, code, bitvec, len, starts, title, is_leaf=true)
    end
end

"""
Извлечь аритмии из XML - структуры
+ объединить одинаковые аритмии, принадлежащие разным ритмам
"""
function get_arrhythmias(root::EzXML.Node)#::Vector{CodeBitset}

    arrs = get_arrhythmias_xml(root)
    if (isempty(arrs)) return Vector{Pair{String, BitVector}}() end

    arrhythmias_tree_leafs = _find_leafs(arrs)


    # могут встречаться маски с одинаковыми кодами аритмий, но принадлежащих к разным ритмам => маски нужно объединить логическим или
    equal_arrs = unique(
        filter(
            equal_arrs -> length(equal_arrs.idxs) > 1,
            map(
                srch_arr -> (
                    code = srch_arr["info"]["code"],
                    idxs = findall(arr -> arr["info"]["code"] == srch_arr["info"]["code"],
                    arrhythmias_tree_leafs)
                ),
                arrhythmias_tree_leafs
            )
        )
    )


    equal_arr_bitsets = map(equal_arrs) do equal_arr
        code = equal_arr.code
        idxs = equal_arr.idxs
        bitsets = map(idx -> _split_bitset_to_bitvector(arrhythmias_tree_leafs[idx]["BitSet"]), idxs) # много времени занимает
        bitset = mapreduce(bitset -> bitset, .|, bitsets)

        code => bitset
        #CodeBitset(code, bitset)
        # (code = code, bitset = bitset)
    end

    if (!isempty(equal_arr_bitsets))
        arrs_equals_idxs = sort(unique(mapreduce(arr -> arr.idxs, append!, equal_arrs)))
        deleteat!(arrhythmias_tree_leafs, arrs_equals_idxs)
    end

    # перевести строку 0 и 1 в логический вектор
    arrs_code_bitsets = map(
        arr -> arr["info"]["code"] => _split_bitset_to_bitvector(arr["BitSet"]),
        arrhythmias_tree_leafs
    )

    # arrs_code_bitsets = map(arr -> (code = arr["info"]["code"], bitset = arr["BitSet"]), arrhythmias_tree_leafs);

    append!(arrs_code_bitsets, equal_arr_bitsets)

    return arrs_code_bitsets
end

function get_arrhythmias_xml(root::EzXML.Node)
    node_arrhythmias = findfirst("/ComparisonData/Examination/Arrhythmias", root)
    arrhythmias = xmlnode2dict(node_arrhythmias)["Arrhythmias"]

    arr_keys = filter(arr_key -> occursin("Arrhythmia", arr_key), collect(keys(arrhythmias)))
    if (isempty(arr_keys)) return Vector{Dict{String, Any}}() end

    arrs = getindex.(Ref(arrhythmias), arr_keys)

    return arrs
end
_split_bitset_to_bitvector(bitset::String) = collect(bitset) .== '1'


"""
поиск крайнего кода в дереве XML - структуры
"""
function _find_leafs(tree_nodes::StructVector)
    leafs = Vector{eltype(tree_nodes)}()

    for node in tree_nodes
        node_childs = find_childs(tree_nodes, node)
        if (isempty(node_childs)) push!(leafs, node) end
    end

    return leafs
end


function find_childs(tree_nodes::StructVector, node)
    node_childs = Vector{typeof(node)}()
    for tree_node in tree_nodes
        if (!(tree_node.idx == node.idx) && (tree_node.parent_idx == node.idx)) push!(node_childs, tree_node) end
    end

    return node_childs;
end

function _find_leafs(tree_nodes::Vector{Dict{String, Any}})
    leafs = Vector{eltype(tree_nodes)}()

    for node in tree_nodes
        has_childs = _node_has_childs(tree_nodes, node["info"])
        if (!has_childs) push!(leafs, node) end
    end

    return leafs
end

"""
Есть дочерние узлы
"""
function _node_has_childs(tree_nodes::Vector{Dict{String, Any}}, node::Dict{String, String})
    for tree_node in tree_nodes
        tree_node = tree_node["info"]
        if (!(tree_node["idx"] == node["idx"]) && (tree_node["parent_idx"] == node["idx"])) return true end
    end

    return false;
end
