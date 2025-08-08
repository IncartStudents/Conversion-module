using FileUtils
using YAML
using DataFrames
using TimeSamplings

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

    arr_pairs = res[1] 
    arr_tuples = res[2]   # Arrhythmias in xml-file
    meta = res[3]         # timestart, fs, point_count
    sleep_info = res[4]   # SleepFragments
    hr_trend = res[5]   # HR10 trend

    sleep_frag = []
    for (_, slp) in sleep_info
        push!(sleep_frag, (slp["ECGStartPoints"][1], slp["ECGStartPoints"][1] + slp["ECGDurationPoints"][1]))
    end

    pqrst = readxml_pqrst_anz(filepath)
    form_stats = calc_qrs_stats(pqrst[1])

    bitvec_s = [bitvec2seg(bitvec) for (key, bitvec) in arr_pairs]
    merged_s = [merge_episodes(segments, 1) for segments in bitvec_s] 

    arr_pairs = [
        (
            rhythm_code = pair.rhythm_code,
            bitvec = pair.bitvec,
            title = pair.title,
            starts = [first(seg) for seg in segs],
            len = [length(seg) for seg in segs],
            segm = segs,
            len_segm = length(segs),
            dur = calc_episode_durations(segs, pqrst[1], meta.fs),
            total_dur_s = sum(calc_episode_durations(segs, pqrst[1], meta.fs)),
            max_dur_s = maximum(calc_episode_durations(segs, pqrst[1], meta.fs)),
            min_dur_s = minimum(calc_episode_durations(segs, pqrst[1], meta.fs)),
            dur_avg_s = mean(calc_episode_durations(segs, pqrst[1], meta.fs)),
            is_night = calc_episode_night(segs,  pqrst[1], sleep_frag)[1],
            is_day = calc_episode_night(segs,  pqrst[1], sleep_frag)[2]
        )
        for (pair, segs) in zip(arr_pairs, merged_s)
    ]

    bitvec_s_arrs = [bitvec2seg(t.bitvec) for t in arr_tuples]
    merged_arr_s = [merge_episodes(segments, 0) for segments in bitvec_s_arrs] 

    arr_tuples = [
        (
            code = t.code,
            title = t.title,
            bitvec = t.bitvec,
            starts = t.starts,
            len = t.len,
            segm = segs,
            len_segm = length(segs),
            dur = calc_episode_durations(segs, pqrst[1], meta.fs),
            total_dur_s = sum(calc_episode_durations(segs, pqrst[1], meta.fs)),
            max_dur_s = maximum(calc_episode_durations(segs, pqrst[1], meta.fs)),
            min_dur_s = minimum(calc_episode_durations(segs, pqrst[1], meta.fs)),
            dur_avg_s = mean(calc_episode_durations(segs, pqrst[1], meta.fs)),
            is_night = calc_episode_night(segs,  pqrst[1], sleep_frag)[1],
            is_day = calc_episode_night(segs,  pqrst[1], sleep_frag)[2]
        )
        for (t, segs) in zip(arr_tuples, merged_arr_s)
    ]

    codes = [t.code for t in arr_tuples]
    println("================================================================================")
    println("Codes $(basename(filepath)): ")
    println(codes)
    println("")
    formes = [String(f) for f in form_stats.form]
    println("Forms $(basename(filepath)): ")
    println(formes)
    println("")   
    keys_list = [pair.rhythm_code for pair in arr_pairs]
    println("Rhytms $(basename(filepath)): ")
    println(keys_list)
    println("")

    result = find_all_nodes_v2(data, arr_tuples, arr_pairs, formes)
    combined_result = combine_rhythm_arr_bitvecs(result)

    output = complex_stats(combined_result, sleep_frag, meta.fs, meta.point_count, pqrst, hr_trend)

    output_tree = "C:/incart_dev/Myproject/result/result_datatree_$(basename(filepath)).yaml"
    if !isempty(output)
        result_data = build_structure(output)
        open(output_tree, "w") do f
            YAML.write(f, result_data)
        end
        println("Найдено $(length(output)) узлов. Результат сохранён в $output_tree")
    else
        println("Ни один узел не найден для файла $filepath")
    end
end

# Обработка всех файлов
for filepath in filepaths
    process_file(filepath, data)
end