# Словарь словарей для Rhythms с дефолтными значениями
rhythms_defaults = Dict{String, Any}(
    "CustomName" => "",
    "OriginalArrTitles" => "",
    "TotalDuration" => "",
    "TotalDurationPercent" => 0.0,
    "CmpxCount" => 0,
    "CmpxPercent" => 0.0,
    "CmpxOccurence" => "",
    "EpisodeCount" => 0,
    "EpisodeCountDay" => 0,
    "EpisodeCountNight" => 0,
    "EpisodeDurationAvg" => "",
    "EpisodeDurationMax" => "",
    "EpisodeDurationMin" => "",
)

# Словарь для ЧСС
hr = Dict{String, Any}(
    "HRIntervalSec" => 0,
    "EpisodeHRAvg" => 0,
    "EpisodeHRMax" => 0,
    "EpisodeHRMin" => 0,
    "EpisodeHRMaxTime" => "",
    "EpisodeHRMinTime" => ""
)

# Словарь словарей для Pauses с дефолтными значениями
pauses_defaults = Dict{String, Any}(
    "CustomName" => "",
    "OriginalArrTitles" => "",
    "TotalDuration" => "",
    "TotalDurationPercent" => 0.0,
    "CmpxCount" => 0,
    "CmpxCountDay" => 0,
    "CmpxCountNight" => 0,
    "CmpxPercent" => 0.0,
    "CmpxOccurence" => "",
    "CmpxCount2s" => 0,
    "CmpxCount3s" => 0,
    "EpisodeCount" => 0,
    "EpisodeCountDay" => 0,
    "EpisodeCountNight" => 0,
    "EpisodeDurationAvg" => "",
    "EpisodeDurationMax" => "",
    "EpisodeDurationMin" => "",
    "RRMinMs" => 0.0,
    "RRMaxMs" => 0.0
)


res_struct = Dict{String, Dict{String, Any}}(
    "Rhythms" => rhythms_defaults,
    "Pauses" => pauses_defaults
)


