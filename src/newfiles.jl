using FileUtils
using YAML
using DataFrames
using BenchmarkTools

include("CalcStats.jl")
include("FindNodes.jl")

# Загрузка дерева данных
input_tree = "C:/incart_dev/Myproject/data/datatree_v2.yaml"
data = YAML.load(open(input_tree, "r"))

# Список файлов
filepaths = [
    "C:/incart_dev/Myproject/data/AlgResult.xml",
    "C:/incart_dev/Myproject/data/AlgResult (1).xml",
    "C:/incart_dev/Myproject/data/AlgResult (2).xml",
    "C:/incart_dev/Myproject/data/AlgResult (3).xml"
]

# Функция обработки одного файла
function process_file(filepath, data)
    res = readxml_rhythms_arrs(filepath)

    arr_tuples = res[2]   # Arrhythmias in xml-file
    meta = res[3]         # timestart, fs, point_count
    sleep_info = res[4]   # SleepFragments

    sleep_frag = []
    for (_, slp) in sleep_info
        push!(sleep_frag, (slp["ECGStartPoints"][1], slp["ECGStartPoints"][1] + slp["ECGDurationPoints"][1]))
    end

    pqrst = readxml_pqrst_anz(filepath)
    form_stats = calc_qrs_stats(pqrst[1])

    codes = [t.code for t in arr_tuples]
    println("================================================================================")
    println("Codes $(basename(filepath)): ")
    println(codes)
    println("")
    formes = [String(f) for f in form_stats.form]
    println("Forms $(basename(filepath)): ")
    println(formes)
    println("")
    result = find_all_nodes(data, arr_tuples, formes)
    
    # @btime find_all_nodes($data, $arr_tuples, $formes)

    output_tree = "C:/incart_dev/Myproject/result/output_datatree_$(basename(filepath)).yaml"
    if !isempty(result)
        result_data = build_structure(result)
        open(output_tree, "w") do f
            YAML.write(f, result_data)
        end
        println("Найдено $(length(result)) узлов. Результат сохранён в $output_tree")
    else
        println("Ни один узел не найден для файла $filepath")
    end

    # Cmpx Stats
    calc = calc_cmpx_stats(result, sleep_frag, meta.fs)
    stats_dicts = [item[2] for item in calc]
    df = DataFrame(stats_dicts)
    new_column_order = vcat(["Path"], setdiff(names(df), ["Path"]))
    select!(df, new_column_order)
    println("=== Cmpx Stats for $filepath ===")
    println(df)

    # Episodes Stats
    # calc1 = calc_episode_stats(result, sleep_frag, meta.fs)
    # stats_dicts1 = [item[2] for item in calc1]
    # df1 = DataFrame(stats_dicts1)
    # new_column_order1 = vcat(["Path"], setdiff(names(df1), ["Path"]))
    # select!(df1, new_column_order1)
    # println("=== Episodes Stats for $filepath ===")
    # println(df1)

    # return df, df1
end

# Обработка всех файлов
for filepath in filepaths
    process_file(filepath, data)
end