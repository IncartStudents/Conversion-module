"""
чтение xml-файла в абстрактный словарь
"""
function readxml_dict(xmlfilepath::String)
    doc = readxml(xmlfilepath)
    AllXmlData = xmlnode2dict(doc.root)
end

"""
конвертация xml-узла в абстрактный словарь
"""
function xmlnode2dict(onenode::EzXML.Node, d::Dict{String, Any} = Dict{String, Any}())
    nodeName = onenode.name
    newName = split(onenode.path, '/')[end]
    if occursin("[",newName)
        nodeName = replace(newName,"[" => ".(")
        nodeName = replace(nodeName,"]" => ")")
        n = tryparse(Int, split(nodeName, '(')[end][1:end-1])
        nodeName = replace(nodeName,string(n) => string(n-1))
    end

    if haselement(onenode) #если есть дети
        d_new = Dict{String,Any}()
        for genus in eachelement(onenode)
            d_new = xmlnode2dict(genus,d_new)
        end
        push!(d, nodeName => d_new)
    else
        data = onenode.content
        t = occursin(";",data) ? split(data, ';') : Vector{String}()
        data =  !isempty(t) &&  tryparse(Int, t[1]) !== nothing ? tryparse.(Int, t) : data
        data =  !isempty(t) &&  typeof(data[1]) == Char  ? Vector{String}(t) : data
        data = typeof(data)==String && tryparse(Int, data) !== nothing ? tryparse(Int, data) : data
        data = typeof(data)== Int ? [data] : data
        push!(d, nodeName => data)
    end

    if haskey(onenode,"Code") && haskey(onenode,"RhythmCode") && haskey(onenode,"ParentIndex")
        info = Dict("code"=>onenode["Code"],
                    "rhythm_code"=>onenode["RhythmCode"],
                    "idx"=>onenode["Index"],
                    "parent_idx"=>onenode["ParentIndex"],
                    "title"=>onenode["Title"])
        if haskey(onenode, "IsLeave")
            info["is_leave"] = onenode["IsLeave"] == "true" ? "true" : "false"
        end
        push!(d[nodeName],"info"=>info)
    
    elseif haskey(onenode,"Code") && haskey(onenode,"RhythmCode")
        info = Dict("code"=>onenode["Code"],
                    "rhythm_code"=>onenode["RhythmCode"],
                    "idx"=>onenode["Index"],
                    "title"=>onenode["Title"])
        if haskey(onenode, "IsLeave")
            info["is_leave"] = onenode["IsLeave"] == "true" ? "true" : "false"
        end
        push!(d[nodeName],"info"=>info)
    
    elseif haskey(onenode,"Code")
        info = Dict("code"=>onenode["Code"],
                    "idx"=>onenode["Index"],
                    "title"=>onenode["Title"])
        if haskey(onenode, "IsLeave")
            info["is_leave"] = onenode["IsLeave"] == "true" ? "true" : "false"
        end
        push!(d[nodeName],"info"=>info)
    end
    return d
end

function xmlnode2dict_(onenode::EzXML.Node, d::Dict{String, Any} = Dict{String, Any}())
    nodeName = onenode.name
    newName = split(onenode.path, '/')[end]
    if occursin("[",newName)
        nodeName = replace(newName,"[" => ".(")
        nodeName = replace(nodeName,"]" => ")")
        n = tryparse(Int, split(nodeName, '(')[end][1:end-1])
        nodeName = replace(nodeName,string(n) => string(n-1))
    end

    if haselement(onenode) #если есть дети
        d_new = Dict{String,Any}()
        for genus in eachelement(onenode)
            d_new = xmlnode2dict(genus,d_new)
        end
        push!(d, nodeName => d_new)
    else
        data = onenode.content
        t = occursin(";",data) ? split(data, ';') : Vector{String}()
        data =  !isempty(t) &&  tryparse(Int, t[1]) !== nothing ? tryparse.(Int, t) : data
        data =  !isempty(t) &&  typeof(data[1]) == Char  ? Vector{String}(t) : data
        data = typeof(data)==String && tryparse(Int, data) !== nothing ? tryparse(Int, data) : data
        data = typeof(data)== Int ? [data] : data
        push!(d, nodeName => data)
    end
    return d
end

"""
Чтение всех возможных параметров QRS из AlgResult.xml:
[timeQ, timeS, form, prem, timePstart, timeTendmax, RR_ms, QS_ms, PQ_ms, QT_ms, QTmask]
"""
function readxml_pqrst_anz(file::AbstractString)
    doc = readxml(file)
    getxml_pqrst_anz(doc.root)
end

# добавить ли prem из аритмий, если его нет?
function getxml_pqrst_anz(root::EzXML.Node)

    node_info = findfirst("/ComparisonData/Examination/ExamInfo", root)
    info = xmlnode2dict(node_info)["ExamInfo"]
    timestart = parse(DateTime, info["Start"])
    fs = info["ECGFd"][1]

    node_qs = findfirst("/ComparisonData/Examination/QRSComplexes", root)
    dict = xmlnode2dict(node_qs)["QRSComplexes"]
    Q = dict["AllQRSStarts"] #.|> Int
    S = Q + dict["AllQRSWidths"] #.|> Int

    # gvg: пустая форма не является причиной обрезки, т.к. может встречаться посреди комплексов.
    # Вставим на пустых - Z
    # сделать в нашей форме: см. convert_toml2csv.jl
    form = dict["AllQRSTypeNames"]
    for k in eachindex(form)
        if isempty(form[k])
            form[k] = "Z"
        end
    end
    L = min(length(Q), length(S), length(form))
    # L = findfirst(x->isempty(x), form) # до первой пустой формы
    # if L === nothing
    #     L = length(form) #длину определяем по форме, тк она мб короче Q
    # else
    #     L = L-1 # предыдущий перед пустым
    # end
    form = Symbol.(form)

    # В CmpxQTs значения для комплексов отделяются символом "|", а значения для разных отведений одного комплекса отделяются симвлом ";"
    # В CmpxQTMasks хранятся маски отведений для которых представлены значения QT.
    try
        node_qt = findfirst("/ComparisonData/Examination/QRSComplexes/CmpxQTs", root)
        data = node_qt.content
        t = occursin("|",data) ? split(data, '|') : Vector{String}()
        QTs = map(x->occursin(";",x) ? maximum(tryparse.(Int,split(x, ';'))) : 0, t) #-1 или nothing??
    catch
        println("Вероятно, отсутствуют данные о CmpxQTs")
        QTs = Int[]
    end

    # правим длины векторов
    # если данных нет, то заполняем 0
    L_QTs = length(QTs)
    if L>L_QTs
        addVec = fill(zero(eltype(QTs)), L-L_QTs)
        QTs = [QTs; addVec]
    end
    try
        QTMasks = dict["CmpxQTMasks"]
    catch
        println("Вероятно, отсутствуют данные о CmpxQTMasks")
        QTMasks = Int[]
    end

    if isempty(QTMasks)
        QTMasks = Int[] #поправляем, если QTMasks = ""
    end

    # правим длины векторов
    L_QTMasks = length(QTMasks)
    if L>L_QTMasks
        addVec = fill(zero(eltype(QTMasks)), L-L_QTMasks)
        QTMasks = [QTMasks; addVec] #тк тут UInt, то не -1, а 0
    end
    # В CmpxPQs отсутствие значения кодируется -1
    try
        PQs = dict["CmpxPQs"] #  PQ в точках
    catch
        println("Вероятно, отсутствуют данные о CmpxPQs")
        PQs = Int[] #  PQ в точках
    end
    # правим длины векторов
    L_PQs = length(PQs)
    if L>L_PQs
        addVec = fill(zero(eltype(PQs)), L-L_PQs)
        PQs = [PQs; addVec] #тк тут UInt, то не -1, а 0
    end

    try
        node_prem = findfirst("/ComparisonData/Examination/PrematurityComplexes", root)
        dict = xmlnode2dict(node_prem)["PrematurityComplexes"]
        prem = dict["Prematurity"] #.|> Symbol
    catch
        println("Вероятно, отсутствуют данные о PrematurityComplexes")
        prem = String[]
    end

    if L>length(prem)
        prem = [prem; fill("", L-length(prem))]
    end

    timeQ = Q[1:L]
    timeS = S[1:L]
    form = form[1:L]
    prem = prem[1:L]
    QTs = QTs[1:L]
    QTmask = QTMasks[1:L]
    PQs = PQs[1:L] #map(x->x[1:L],[Q,S,form,QTs,QTMasks,PQs])
    # gvg: нужно ли считать помимо Q, S, timePstart, timeTendmax
    # производные поля width, PQ, QT?
    # пока примем, что мы все посчитаем сами в миллисекундах

    timePstart = timeQ .- PQs
    timeTendmax = timeQ .+ QTs
    QS_ms = (timeS .- timeQ) .* 1000 ./ fs
    PQ_ms = PQs .* 1000 ./ fs
    QT_ms = QTs .* 1000 ./ fs

    ind = .! Descriptors.Analyzer.FormsQRS.is_pseudobeat.(form) # map(f->!(f in (:ZX, :X, :XZ, :XC)), form)
    RR_ms = calc_RR_ms(timeQ, ind, fs)
    #@info length(form), length(prem), length(RR_ms)
    tab = StructVector((;
        timeQ, timeS, form, prem = Symbol.(prem),
        timePstart, timeTendmax,
        RR_ms, QS_ms, PQ_ms, QT_ms, QTmask,
    )) # class_id отсутствует!

    return tab, (; timestart, fs)
end

"""
функция для расчета RR-интрвалов по времени и типу событий
(включать ли в расчет, или пропускать)
"""
# TODO: заменить все остальые фукнции calc_rr в HotBox и т.д.
# оставил здесь, чтобы не зависеть от другого пакета ради 1-й функции
function calc_RR_ms(times, include_flag, fs) # include_flag = считать ли RR для этой точки
    RR_ms = fill(NaN, length(times))
    t0 = 0
    for (i, t) in enumerate(times)
        if include_flag[i]
            dt = t - t0
            t0 = t
            RR_ms[i] = round(dt / fs * 1000)
        end
    end
    # функциональный способ расчета разностей:
    # diff = reduce(vec, init = (Float64[], NaN)) do (out, x0), x1
    #     (push!(out, x1 - x0), x1)
    # end
    return RR_ms
end
