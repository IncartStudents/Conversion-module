# Project Overview

This project processes XML and YAML data files to generate analytical results. It includes Julia modules for XML parsing, data tree manipulation, statistical calculations, and node operations. Processed results are stored in the `result/` directory.

# Project Structure

```plaintext
MyProject/
├── data/                   # Raw input data (XML/YAML)
│   ├── AlgResult (1).xml   # Ishem_Arithm.ver
│   ├── AlgResult (2).xml   # ReoBreath.avt
│   ├── AlgResult (3).xml   # Seminar_AD_FP.ver
│   ├── AlgResult.xml       # ChildArithm.ver
│   ├── datatree_v2.yaml    # Datatree configuration
│   └── new_datatree.yaml   # Updated datatree schema
│   
│
├── result/                # Processed output files
│   ├── result_datatree_AlgResult_*.xml    # Generated results (4 files)
│   └── ResumeData*.yaml   # Example output for AlgResult*.xml (4 files)
│
└── src/                   # Source code
    ├── ReadXML/           # XML processing utilities
    │   ├── ReadXML.jl     # Main XML reader
    │   ├── xml_array.jl   # Array operations for XML (from FileUtiles)
    │   └── xml.jl         # XML parsing internals (from FileUtiles)
    │
    ├── CalcStats.jl       # Statistical calculations
    ├── FindNodes.jl       # Node search operations
    ├── MyProject.jl       # Project entry point
    ├── struct.jl          # Datastructure definitions for RhythmArrs/Pauses
    │
    ├── test/              # Unit tests
    │   └── runtests.jl    # Test runner
    │
    ├── runfile.jl         # Execution script
    ├── Project.toml       # Julia dependencies
    ├── Manifest.toml      # Dependency versions
    └── .gitignore         # Ignored files/directories
```

# Key Features

- **XML Processing**: Parse and transform XML data (`src/ReadXML/`)
- **Data Tree Operations**: Handle YAML-based tree structures (`data/*.yaml`)
- **Statistical Analysis**: Calculate metrics from processed data (`src/CalcStats.jl`)
- **Node Navigation**: Find and extract tree nodes (`src/FindNodes.jl`)