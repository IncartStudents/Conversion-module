module MyProject

export process_file

using YAML, ..ReadXML, TimeSamplings

include("FindNodes.jl")
include("CalcStats.jl")


function write_result_to_yaml(output, filepath)
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


function process_file(filepath, data)
    res = ReadXML.readxml_rhythms_arrs(filepath)

    arr_pairs = res[1]      # Rhythms in xml-file
    arr_tuples = res[2]     # Arrhythmias in xml-file
    meta = res[3]           # timestart, fs, point_count
    sleep_info = res[4]     # SleepFragments
    hr_trend = res[5]       # HR10 trend
    motion_trend = res[6]   # MotionBitSet10

    sleep_frag = []
    for (_, slp) in sleep_info
        push!(sleep_frag, (slp["ECGStartPoints"][1], slp["ECGStartPoints"][1] + slp["ECGDurationPoints"][1]))
    end

    pqrst = ReadXML.readxml_pqrst_anz(filepath)
    form_stats = calc_qrs_stats(pqrst[1])
    form_pairs = [i => string(element.form) for (i, element) in enumerate(pqrst[1])]

    bitvec_s = [bitvec2seg(bitvec) for (key, bitvec) in arr_pairs]
    merged_s = [merge_episodes_v2(segments, form_pairs) for segments in bitvec_s]

    arr_pairs = [
        (
            rhythm_code = pair.rhythm_code,
            bitvec = pair.bitvec,
            title = pair.title,
            compute_episode_stats(segs, pqrst[1], meta.fs, sleep_frag)...
        )
        for (pair, segs) in zip(arr_pairs, merged_s)
    ]

    bitvec_s_arrs = [bitvec2seg(t.bitvec) for t in arr_tuples]
    merged_arr_s = [merge_episodes_v2(segments, form_pairs) for segments in bitvec_s_arrs] 

    arr_tuples = [
        (
            code = t.code,
            title = t.title,
            bitvec = t.bitvec,
            compute_episode_stats(segs, pqrst[1], meta.fs, sleep_frag)...
        )
        for (t, segs) in zip(arr_tuples, merged_arr_s)
    ]

    result = find_all_nodes_v2(data, arr_tuples, arr_pairs, [String(f) for f in form_stats.form])
    combined_result = combine_rhythm_arr_bitvecs(result)
    output = complex_stats(combined_result, sleep_frag, meta.fs, meta.point_count, pqrst, hr_trend)
    write_result_to_yaml(output, filepath)

end

end # module