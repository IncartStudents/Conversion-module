
# Создаем структуру иерархии ритмов
rhythm_hierarchy = Dict{String, Any}(
    "sinus" => Dict(
        "name" => "Синусовый ритм",
        "codes" => ["®;rN", "@;rN"],
        "params" => [],
        "children" => Dict()
    ),
    "paced-undefined" => Dict(
        "name" => "Ритм стимуляции (неуточненный)",
        "codes" => ["®;rC"],
        "params" => [],
        "children" => Dict()
    ),
    "paced-dual" => Dict(
        "name" => "Ритм двухкамерной стимуляции",
        "codes" => ["®;rCD"],
        "params" => [],
        "children" => Dict()
    ),
    "paced-atrial" => Dict(
        "name" => "Ритм предсердной стимуляции",
        "codes" => ["®;rCA"],
        "params" => [],
        "children" => Dict()
    ),
    "paced-vent" => Dict(
        "name" => "Ритм желудочковой стимуляции",
        "codes" => ["®;rCV"],
        "params" => [],
        "children" => Dict()
    ),
    "paced-fail" => Dict(
        "name" => "Ритм безответной стимуляции",
        "codes" => ["®;rCU"],
        "params" => [],
        "children" => Dict()
    ),
    "paced-sensed" => Dict(
        "name" => "Р-синхронизированная стимуляция желудочков",
        "codes" => ["®;rN;vC"],
        "params" => [],
        "children" => Dict()
    ),
    "atrial-fib" => Dict(
        "name" => "Фибрилляция предсердий",
        "codes" => ["®;rF", "@;rF"],
        "params" => [],
        "children" => Dict()
    ),
    "atrial-flutter" => Dict(
        "name" => "Трепетание предсердий",
        "codes" => ["®;rFA", "@;rFA"],
        "params" => [],
        "children" => Dict()
    ),
    "irregular" => Dict(
        "name" => "Нерегулярный ритм",
        "codes" => ["®;rFN", "@;rFN"],
        "params" => [],
        "children" => Dict()
    ),
    "atrial-poly" => Dict(
        "name" => "Эпизоды миграции водителя ритма по предсердиям",
        "codes" => ["®;(rSM|rSP)", "@;(rSM|rSP);nP"],
        "params" => [],
        "children" => Dict()
    ),
    "atrial" => Dict(
        "name" => "Предсердные",
        "codes" => ["®;(rSA|rSI)", "@;(rSA|rSI)"],
        "params" => [],
        "children" => Dict(
            "premature" => Dict(
                "name" => "Предсердные экстрасистолы",
                "codes" => ["®;(rSA|rSI)", "@;(rSA|rSI)"],
                "params" => [],
                "children" => Dict(
                    "single" => Dict(
                        "name" => "Одиночные",
                        "codes" => ["@;(rSA|rSI);nS;pP*"],
                        "params" => [],
                        "children" => Dict(
                            "aberrant" => Dict(
                                "name" => "С аберрантным проведением",
                                "codes" => ["@;(rSA|rSI);nS;pP*;vA*"],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "bi" => Dict(
                                "name" => "Бигеминия",
                                "codes" => ["@;(rSA|rSI);nS;pP*;gB"],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "tri" => Dict(
                                "name" => "Тригеминия",
                                "codes" => ["@;(rSA|rSI);nS;pP*;gT"],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "qu" => Dict(
                                "name" => "Квадригеминия",
                                "codes" => ["-"],
                                "params" => [],
                                "children" => Dict()
                            )
                        )
                    ),
                    "pair" => Dict(
                        "name" => "Парные",
                        "codes" => ["@;(rSA|rSI);nD;pP*"],
                        "params" => [],
                        "children" => Dict(
                            "aberrant" => Dict(
                                "name" => "С аберрантным проведением",
                                "codes" => ["@;(rSA|rSI);nD;pP*;vA*"],
                                "params" => [],
                                "children" => Dict()
                            )
                        )
                    ),
                    "group" => Dict(
                        "name" => "Групповые",
                        "codes" => ["@;(rSA|rSI);nG;pP*"],
                        "params" => [],
                        "children" => Dict(
                            "aberrant" => Dict(
                                "name" => "С аберрантным проведением",
                                "codes" => ["@;(rSA|rSI);nG;pP*;vA*"],
                                "params" => [],
                                "children" => Dict()
                            )
                        )
                    ),
                    "blocked" => Dict(
                        "name" => "блокированные",
                        "codes" => ["@;(rSA|rSI);bB"],
                        "params" => [],
                        "children" => Dict()
                    )
                )
            ),
            "escape" => Dict(
                "name" => "Предсердные замещающие комплексыы",
                "codes" => ["®;(rSA|rSI)", "@;(rSA|rSI)"],
                "params" => [],
                "children" => Dict(
                    "single" => Dict(
                        "name" => "Одиночные",
                        "codes" => ["@;(rSA|rSI|rSM);nS;pE*"],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "pair" => Dict(
                        "name" => "Парные",
                        "codes" => ["@;(rSA|rSI|rSM);nD;pE*"],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "group" => Dict(
                        "name" => "Групповые",
                        "codes" => ["@;(rSA|rSI|rSM);nG;pE*"],
                        "params" => [],
                        "children" => Dict()
                    )
                )
            ),
            "tachy" => Dict(
                "name" => "Эпизоды предсердной тахикардии",
                "codes" => ["®;rSA(;pP*|;fT)", "@;rSA;nP;pP*;!fR"],
                "params" => [],
                "children" => Dict()
            ),
            "rhythm" => Dict(
                "name" => "Эпизоды предсердного ритма",
                "codes" => ["®;rSA(;!pP*&!fT)", "@;rSA;nP;fR|(;!pP*&!fT)"],
                "params" => [],
                "children" => Dict()
            ),
            "rhythm-low" => Dict(
                "name" => "Эпизоды нижнепредсердного ритма",
                "codes" => ["®;rSI", "@;rSI;nP"],
                "params" => [],
                "children" => Dict()
            )
        )
    ),
    "nodal" => Dict(
        "name" => "Узловые",
        "codes" => ["®;(rSN|rSR)", "@;(rSN|rSR)"],
        "params" => [],
        "children" => Dict(
            "premature" => Dict(
                "name" => "Узловые экстрасистолы",
                "codes" => ["®;(rSN|rSR)", "@;(rSN|rSR)"],
                "params" => [],
                "children" => Dict()
            ),
            "escape" => Dict(
                "name" => "Узловые замещающие комплексы",
                "codes" => ["®;(rSN|rSR)", "@;(rSN|rSR)"],
                "params" => [],
                "children" => Dict()
            ),
            "tachy" => Dict(
                "name" => "Эпизоды узловой тахикардии",
                "codes" => ["®;rSN(;pP*|;fT)", "@;rSN;nP;pP*;!fR"],
                "params" => [],
                "children" => Dict()
            ),
            "rhythm" => Dict(
                "name" => "Эпизоды узлового ритма",
                "codes" => ["®;rSN(;!pP*&!fT)", "@;rSN;nP;fR|(;!pP*&!fT)"],
                "params" => [],
                "children" => Dict()
            ),
            "rhythm-reentry" => Dict(
                "name" => "Эпизоды узлового реципрокного ритма / тахи",
                "codes" => ["®;rSR", "@;rSR;nP"],
                "params" => [],
                "children" => Dict()
            )
        )
    ),
    "supravent" => Dict(
        "name" => "Наджелудочковые",
        "codes" => ["®;rS", "@;(rS|rM)"],
        "params" => [],
        "children" => Dict(
            "premature" => Dict(
                "name" => "Наджелудочковые экстрасистолы",
                "codes" => ["®;rS", "@;(rS|rM)"],
                "params" => [],
                "children" => Dict()
            ),
            "escape" => Dict(
                "name" => "Наджелудочковые замещающие комплексы",
                "codes" => ["®;rS", "@;(rS|rM)"],
                "params" => [],
                "children" => Dict()
            ),
            "combined-VS" => Dict(
                "name" => "В сочетаниях с желудочковыми",
                "codes" => ["®;rS", "@;(rS|rM)"],
                "params" => [],
                "children" => Dict(
                    "pair" => Dict(
                        "name" => "В парах",
                        "codes" => ["@;rM;nD"],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "group" => Dict(
                        "name" => "В группах",
                        "codes" => ["@;rM;nG"],
                        "params" => [],
                        "children" => Dict()
                    )
                )
            ),
            "tachy" => Dict(
                "name" => "Эпизоды наджелудочковой тахикардии",
                "codes" => ["®;rS(;pP*|;fT)", "@;rS;nP;pP*;!fR"],
                "params" => [],
                "children" => Dict()
            ),
            "rhythm" => Dict(
                "name" => "Эпизоды наджелудочкового ритма",
                "codes" => ["®;rS(;!pP*&!fT)", "@;rS;nP;fR|(;!pP*&!fT)"],
                "params" => [],
                "children" => Dict()
            )
        )
    ),
    "vent-by-form" => Dict(
        "name" => "Желудочковые (с группировкой по формам)",
        "codes" => ["®;(rV|rVM|rVP|rVD|rM)", "@;(rV|rVM|rVP|rVD|rM)"],
        "params" => [],
        "children" => Dict(
            "V" => Dict(
                "name" => "Желудочковые (неуточненные)",
                "codes" => ["®;(rV|rVM|rVP|rVD|rM)", "@;(rV|rVM|rVP|rVD|rM)"],
                "params" => [],
                "children" => Dict(
                    "premature" => Dict(
                        "name" => "Желудочковые экстрасистолы",
                        "codes" => ["®;(rV|rVM|rVP|rVD|rM)", "@;(rV|rVM|rVP|rVD|rM)"],
                        "params" => [],
                        "children" => Dict(
                            "single" => Dict(
                                "name" => "Одиночные",
                                "codes" => ["@;(rV|rVM|rVP|rVD);nS;(pP*|!pE*)"],
                                "params" => [],
                                "children" => Dict(
                                    "bi" => Dict(
                                        "name" => "Бигеминии",
                                        "codes" => ["@;(rV|rVM|rVP|rVD);nS;(pP*|!pE*);gB"],
                                        "params" => [],
                                        "children" => Dict()
                                    ),
                                    "tri" => Dict(
                                        "name" => "Тригеминии",
                                        "codes" => ["@;(rV|rVM|rVP|rVD);nS;(pP*|!pE*);gT"],
                                        "params" => [],
                                        "children" => Dict()
                                    ),
                                    "qu" => Dict(
                                        "name" => "Квадригеминии",
                                        "codes" => ["-"],
                                        "params" => [],
                                        "children" => Dict()
                                    )
                                )
                            ),
                            "pair-mono" => Dict(
                                "name" => "Парные мономорфные",
                                "codes" => ["@;(rV|rVM);nD;(pP*|!pE*)"],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "pair-poly" => Dict(
                                "name" => "Парные полиморфные",
                                "codes" => ["@;(rVP|rVD);nD;(pP*|!pE*)"],
                                "params" => [],
                                "children" => Dict()
                            )
                        )
                    ),
                    "escape" => Dict(
                        "name" => "Желудочковые замещающие комплексы",
                        "codes" => ["®;(rV|rVM|rVP|rVD|rM)", "@;(rV|rVM|rVP|rVD|rM)"],
                        "params" => [],
                        "children" => Dict(
                            "single" => Dict(
                                "name" => "Одиночные",
                                "codes" => ["@;(rV|rVM|rVP|rVD);nS;pE*"],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "pair-mono" => Dict(
                                "name" => "Парные мономорфные",
                                "codes" => ["@;(rV|rVM);nD;pE*"],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "pair-poly" => Dict(
                                "name" => "Парные полиморфные",
                                "codes" => ["@;(rVP|rVD);nD;pE*"],
                                "params" => [],
                                "children" => Dict()
                            )
                        )
                    ),
                    "combined-VS" => Dict(
                        "name" => "В сочетаниях с наджелудочковыми",
                        "codes" => ["®;(rV|rVM|rVP|rVD|rM)", "@;(rV|rVM|rVP|rVD|rM)"],
                        "params" => [],
                        "children" => Dict(
                            "pair" => Dict(
                                "name" => "В парах",
                                "codes" => ["@;rM;nD"],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "group" => Dict(
                                "name" => "В группах",
                                "codes" => ["@;rM;nG"],
                                "params" => [],
                                "children" => Dict()
                            )
                        )
                    ),
                    "tachy-unstable-mono" => Dict(
                        "name" => "Эпизоды неустойчивой мономорфной желудочковой тахикардии",
                        "codes" => ["@;(rV|rVM);nG;pP*;!fR"],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "tachy-unstable-poly" => Dict(
                        "name" => "В эпизодах неустойчивой полиморфной желудочковой тахикардии",
                        "codes" => ["@;(rVP|rVD);nG;pP*;!fR"],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "tachy-stable-mono" => Dict(
                        "name" => "Эпизоды устойчивой мономорфной желудочковой тахикардии",
                        "codes" => ["®;(;rV|;rVM)(;pP*|;fT)", "@;(rV|rVM);nP;pP*;!fR"],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "tachy-stable-poly" => Dict(
                        "name" => "В эпизодах устойчивой полиморфной желудочковой тахикардии",
                        "codes" => ["®;(rVP|rVD)(;pP*|;fT)", "@;(rVP|rVD);nP;pP*;!fR"],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "rhythm-unstable-mono" => Dict(
                        "name" => "Эпизоды неустойчивого мономорфного желудочкового ритма",
                        "codes" => ["@;(rV|rVM);nG;fR|(;!pP*&!fT)"],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "rhythm-unstable-poly" => Dict(
                        "name" => "В эпизодах неустойчивого полиморфного желудочкового ритма",
                        "codes" => ["@;(rVP|rVD);nG;fR|(;!pP*&!fT)"],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "rhythm-stable-mono" => Dict(
                        "name" => "Эпизоды устойчивого мономорфного желудочкового ритма",
                        "codes" => ["®;(rV|rVM)(;!pP*&!fT)", "@;(rV|rVM);nP;fR|(;!pP*&!fT)"],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "rhythm-stable-poly" => Dict(
                        "name" => "В эпизодах устойчивого полиморфного желудочкового ритма",
                        "codes" => ["®;(rVP|rVD)(;!pP*&!fT)", "@;(rVP|rVD);nP;fR|(;!pP*&!fT)"],
                        "params" => [],
                        "children" => Dict()
                    )
                )
            ),
            "VR" => Dict(
                "name" => "C морфологией блокады правой ножки пучка Гиса",
                "codes" => [],
                "params" => [],
                "children" => Dict()
            ),
            "VL" => Dict(
                "name" => "С морфологией блокады левой ножки пучка Гиса",
                "codes" => [],
                "params" => [],
                "children" => Dict()
            ),
            "V1" => Dict(
                "name" => "Первого типа",
                "codes" => [],
                "params" => [],
                "children" => Dict()
            ),
            "V2" => Dict(
                "name" => "Второго типа",
                "codes" => [],
                "params" => [],
                "children" => Dict()
            ),
            "V3" => Dict(
                "name" => "Третьего типа",
                "codes" => [],
                "params" => [],
                "children" => Dict()
            ),
            "V4" => Dict(
                "name" => "Четвертого типа",
                "codes" => [],
                "params" => [],
                "children" => Dict()
            ),
            "V5" => Dict(
                "name" => "Пятого типа",
                "codes" => [],
                "params" => [],
                "children" => Dict()
            ),
            "F" => Dict(
                "name" => "Сливные",
                "codes" => [],
                "params" => [],
                "children" => Dict()
            ),
            "poly" => Dict(
                "name" => "Желудочковые полиморфные",
                "codes" => ["®;(rV|rVM|rVP|rVD|rM)", "@;(rV|rVM|rVP|rVD|rM)"],
                "params" => [],
                "children" => Dict(
                    "premature-pair-F" => Dict(
                        "name" => "Парные полиморфные экстрасистолы со сливным комплексом",
                        "codes" => ["@;(rVP|rVD);nD;(pP*|!pE*);vF"],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "escape-pair-F" => Dict(
                        "name" => "Парные полиморфные замещающие комплексы со сливным",
                        "codes" => ["@;(rVP|rVD);nD;pE*;vF"],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "premature-pair" => Dict(
                        "name" => "Парные полиморфные экстрасистолы",
                        "codes" => ["@;(rVP|rVD);nD;(pP*|!pE*);!vF"],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "escape-pair" => Dict(
                        "name" => "Парные полиморфные замещающие комплексы",
                        "codes" => ["@;(rVP|rVD);nD;pE*;!vF"],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "tachy-unstable" => Dict(
                        "name" => "Эпизоды неустойчивой полиморфной желудочковой тахикардии",
                        "codes" => ["@;(rVP|rVD);nG;pP*;!fR"],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "tachy-stable" => Dict(
                        "name" => "Эпизоды устойчивой полиморфной желудочковой тахикардии",
                        "codes" => ["®;(rVP|rVD)(;pP*|;fT)", "@;(rVP|rVD);nP;pP*;!fR"],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "rhythm-unstable" => Dict(
                        "name" => "Эпизоды неустойчивого полиморфного желудочкового ритма",
                        "codes" => ["@;(rVP|rVD);nG;fR|(;!pP*&!fT)"],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "rhythm-stable" => Dict(
                        "name" => "Эпизоды устойчивого полиморфного желудочкового ритма",
                        "codes" => ["®;(rVP|rVD)(;!pP*&!fT)", "@;(rVP|rVD);nP;fR|(;!pP*&!fT)"],
                        "params" => [],
                        "children" => Dict()
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
                                    ),
                                    "tri" => Dict(
                                        "name" => "Тригеминия",
                                        "codes" => [],
                                        "params" => [],
                                        "children" => Dict()
                                    ),
                                    "qu" => Dict(
                                        "name" => "Квадригеминия",
                                        "codes" => [],
                                        "params" => [],
                                        "children" => Dict()
                                    )
                                )
                            ),
                            "VR" => Dict(
                                "name" => "Правожелудочковые",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "VL" => Dict(
                                "name" => "Левожелудочковые",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "V1" => Dict(
                                "name" => "В форме V1",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "V2" => Dict(
                                "name" => "В форме V2",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "V3" => Dict(
                                "name" => "В форме V3",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "V4" => Dict(
                                "name" => "В форме V4",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "V5" => Dict(
                                "name" => "В форме V5",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "F" => Dict(
                                "name" => "Фибрилляция желудочков",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            )
                        )
                    ),
                    "pair-mono" => Dict(
                        "name" => "Мономорфные парные",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict(
                            "VR" => Dict(
                                "name" => "Правожелудочковые",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "VL" => Dict(
                                "name" => "Левожелудочковые",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "V1" => Dict(
                                "name" => "В форме V1",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "V2" => Dict(
                                "name" => "В форме V2",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "V3" => Dict(
                                "name" => "В форме V3",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "V4" => Dict(
                                "name" => "В форме V4",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "V5" => Dict(
                                "name" => "В форме V5",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "F" => Dict(
                                "name" => "Фибрилляция желудочков",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            )
                        )
                    ),
                    "pair-poly" => Dict(
                        "name" => "Полиморфные парные",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    )
                )
            ),
            "escape" => Dict(
                "name" => "Желудочковые выскакивающие комплексы",
                "codes" => [],
                "params" => [],
                "children" => Dict(
                    "single" => Dict(
                        "name" => "Одиночные",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict(
                            "VR" => Dict(
                                "name" => "Правожелудочковые",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "VL" => Dict(
                                "name" => "Левожелудочковые",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "V1" => Dict(
                                "name" => "В форме V1",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "V2" => Dict(
                                "name" => "В форме V2",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "V3" => Dict(
                                "name" => "В форме V3",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "V4" => Dict(
                                "name" => "В форме V4",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "V5" => Dict(
                                "name" => "В форме V5",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "F" => Dict(
                                "name" => "Фибрилляция желудочков",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            )
                        )
                    ),
                    "pair-mono" => Dict(
                        "name" => "Мономорфные парные",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict(
                            "VR" => Dict(
                                "name" => "Правожелудочковые",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "VL" => Dict(
                                "name" => "Левожелудочковые",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "V1" => Dict(
                                "name" => "В форме V1",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "V2" => Dict(
                                "name" => "В форме V2",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "V3" => Dict(
                                "name" => "В форме V3",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "V4" => Dict(
                                "name" => "В форме V4",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "V5" => Dict(
                                "name" => "В форме V5",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            ),
                            "F" => Dict(
                                "name" => "Фибрилляция желудочков",
                                "codes" => [],
                                "params" => [],
                                "children" => Dict()
                            )
                        )
                    ),
                    "pair-poly" => Dict(
                        "name" => "Полиморфные парные",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    )
                )
            ),
            "combined-VS" => Dict(
                "name" => "Смешанные желудочково-предсердные",
                "codes" => [],
                "params" => [],
                "children" => Dict(
                    "pair" => Dict(
                        "name" => "Парные",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "group" => Dict(
                        "name" => "Групповые",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    )
                )
            ),
            "tachy-unstable-mono" => Dict(
                "name" => "Мономорфная нестабильная желудочковая тахикардия",
                "codes" => [],
                "params" => [],
                "children" => Dict(
                    "VR" => Dict(
                        "name" => "Правожелудочковые",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "VL" => Dict(
                        "name" => "Левожелудочковые",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "V1" => Dict(
                        "name" => "В форме V1",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "V2" => Dict(
                        "name" => "В форме V2",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "V3" => Dict(
                        "name" => "В форме V3",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "V4" => Dict(
                        "name" => "В форме V4",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "V5" => Dict(
                        "name" => "В форме V5",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "F" => Dict(
                        "name" => "Фибрилляция желудочков",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    )
                )
            ),
            "tachy-unstable-poly" => Dict(
                "name" => "Полиморфная нестабильная желудочковая тахикардия",
                "codes" => [],
                "params" => [],
                "children" => Dict()
            ),
            "tachy-stable-mono" => Dict(
                "name" => "Мономорфная стабильная желудочковая тахикардия",
                "codes" => [],
                "params" => [],
                "children" => Dict(
                    "VR" => Dict(
                        "name" => "Правожелудочковые",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "VL" => Dict(
                        "name" => "Левожелудочковые",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "V1" => Dict(
                        "name" => "В форме V1",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "V2" => Dict(
                        "name" => "В форме V2",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "V3" => Dict(
                        "name" => "В форме V3",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "V4" => Dict(
                        "name" => "В форме V4",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "V5" => Dict(
                        "name" => "В форме V5",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "F" => Dict(
                        "name" => "Фибрилляция желудочков",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    )
                )
            ),
            "tachy-stable-poly" => Dict(
                "name" => "Полиморфная стабильная желудочковая тахикардия",
                "codes" => [],
                "params" => [],
                "children" => Dict()
            ),
            "rhythm-unstable-mono" => Dict(
                "name" => "Мономорфный нестабильный желудочковый ритм",
                "codes" => [],
                "params" => [],
                "children" => Dict(
                    "VR" => Dict(
                        "name" => "Правожелудочковые",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "VL" => Dict(
                        "name" => "Левожелудочковые",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "V1" => Dict(
                        "name" => "В форме V1",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "V2" => Dict(
                        "name" => "В форме V2",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "V3" => Dict(
                        "name" => "В форме V3",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "V4" => Dict(
                        "name" => "В форме V4",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "V5" => Dict(
                        "name" => "В форме V5",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "F" => Dict(
                        "name" => "Фибрилляция желудочков",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    )
                )
            ),
            "rhythm-unstable-poly" => Dict(
                "name" => "Полиморфный нестабильный желудочковый ритм",
                "codes" => [],
                "params" => [],
                "children" => Dict()
            ),
            "rhythm-stable-mono" => Dict(
                "name" => "Мономорфный стабильный желудочковый ритм",
                "codes" => [],
                "params" => [],
                "children" => Dict(
                    "VR" => Dict(
                        "name" => "Правожелудочковые",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "VL" => Dict(
                        "name" => "Левожелудочковые",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "V1" => Dict(
                        "name" => "В форме V1",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "V2" => Dict(
                        "name" => "В форме V2",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "V3" => Dict(
                        "name" => "В форме V3",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "V4" => Dict(
                        "name" => "В форме V4",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "V5" => Dict(
                        "name" => "В форме V5",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    ),
                    "F" => Dict(
                        "name" => "Фибрилляция желудочков",
                        "codes" => [],
                        "params" => [],
                        "children" => Dict()
                    )
                )
            ),
            "rhythm-stable-poly" => Dict(
                "name" => "Полиморфный стабильный желудочковый ритм",
                "codes" => [],
                "params" => [],
                "children" => Dict()
            )
        )
    )
)

# Добавляем паузы как отдельный корневой узел
rhythm_hierarchy["pause"] = Dict(
    "name" => "Паузы",
    "params" => [],
    "children" => Dict(
        "blocked-atrial-premature" => Dict(
            "name" => "Паузы за счет блокированных предсердных экстрасистол, в том числе с замещающими комплексами",
            "codes" => ["@;rN;bB"],
            "params" => [],
            "children" => Dict()
        ),
        "sinus-arrhythmia" => Dict(
            "name" => "Паузы за счет синусовой аритмии",
            "codes" => ["@;rN;pE*;(bN|!b*)"],
            "params" => [],
            "children" => Dict()
        ),
        "SA-block" => Dict(
            "name" => "Паузы за счет СА блокады, в том числе с замещающими комплексами (предположительно невозможная аритмия)",
            "codes" => ["@;rN;bS"],
            "params" => [],
            "children" => Dict()
        ),
        "sinus-arrest" => Dict(
            "name" => "Паузы за счет отказа синусового узла, в том числе с замещающими комплексами",
            "codes" => ["@;rN;bA"],
            "params" => [],
            "children" => Dict()
        ),
        "AV-block-degree2-Mobitz-type1" => Dict(
            "name" => "Паузы за счет АВ блокады 2 степени типа Мобитц 1, в том числе с замещающими комплексами",
            "codes" => ["@;bV1"],
            "params" => [],
            "children" => Dict()
        ),
        "AV-block-degree2-Mobitz-type2" => Dict(
            "name" => "Паузы за счет АВ блокады 2 степени типа Мобитц 2, в том числе с замещающими комплексами",
            "codes" => ["@;bV2"],
            "params" => [],
            "children" => Dict()
        ),
        "AV-block-degree2-2to1" => Dict(
            "name" => "Паузы за счет АВ блокады 2 степени 2:1, в том числе с замещающими комплексами",
            "codes" => ["@;bVP"],
            "params" => [],
            "children" => Dict()
        ),
        "AV-block-degree2-highgrade" => Dict(
            "name" => "Паузы за счет далеко зашедшей АВ блокады 2 степени, в том числе с замещающими комплексами",
            "codes" => ["@;(bVS|bVT)"],
            "params" => [],
            "children" => Dict()
        ),
        "binodal-block" => Dict(
            "name" => "Паузы за счет бинодальной блокады",
            "codes" => ["@;bW"],
            "params" => [],
            "children" => Dict()
        ),
        "AV-varying-supravent-tachy" => Dict(
            "name" => "Паузы за счет нерегулярного АВ-проведения наджелудочковых тахикардий, в том числе на фоне ФП, ТП или предсердных тахикардий, в том числе с замещающими комплексами (в т.ч. нерегулярное проведение АВ-блокад 1:1, 2:1, 3:1, 4:1)",
            "codes" => ["®bT*", "@bT*"],
            "params" => [],
            "children" => Dict()
        ),
        "paced-high-rate" => Dict(
            "name" => "Паузы на фоне работы кардиостимулятора с превышением базовой частоты, в том числе с замещающими комплексами",
            "codes" => ["@;pSL"],
            "params" => [],
            "children" => Dict()
        ),
        "miopotential-inhibition" => Dict(
            "name" => "Паузы на фоне миопотенциальной ингибиции, в том числе с замещающими комплексами",
            "codes" => ["@;pSE"],
            "params" => [],
            "children" => Dict()
        ),
        "undefined" => Dict(
            "name" => "Недифференцированные паузы",
            "codes" => ["*"],
            "params" => [],
            "children" => Dict()
        )
    )
)