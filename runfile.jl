using .MyProject
using YAML


INPUT_DIR = joinpath(@__DIR__, "data")
OUTPUT_DIR = joinpath(@__DIR__, "result")

FILEPATHS = [
    joinpath(INPUT_DIR, "AlgResult.xml"),
    joinpath(INPUT_DIR, "AlgResult (1).xml"),
    joinpath(INPUT_DIR, "AlgResult (2).xml"),
    joinpath(INPUT_DIR, "AlgResult (3).xml")
]

# Загрузка дерева данных
input_tree = "C:/incart_dev/Myproject/data/datatree_v2.yaml"
data = YAML.load(open(input_tree, "r"))

for filepath in FILEPATHS
    MyProject.process_file(filepath, data)
end