# GenX.jl AI Coding Agent Instructions

## Project Overview
GenX is a **Julia-based electricity capacity expansion model** using JuMP for optimization. It determines cost-optimal generation, storage, transmission, and demand-side resource investments while respecting operational constraints, policies, and emissions limits.

**Key Technologies**: Julia (≥1.6, recommend 1.9), JuMP (≥1.1.1), HiGHS/Gurobi/CPLEX solvers, CSV/DataFrames for I/O

## Architecture & Code Organization

### Core Pipeline (src/)
GenX follows a **five-stage workflow** executed by `run_genx_case!()`:
1. **Configure Settings** (`configure_settings/`) - Load YAML configs from `settings/genx_settings.yml`
2. **Load Inputs** (`load_inputs/`) - Parse CSV files from `resources/`, `system/`, `policies/`
3. **Generate Model** (`model/`) - Build JuMP optimization model with variables/constraints/objective
4. **Solve Model** - Execute solver and check feasibility
5. **Write Outputs** (`write_outputs/`) - Export results to `results/` directory

### Model Structure (src/model/)
- **`generate_model.jl`**: Entry point that initializes two critical expressions progressively built by modules:
  - `EP[:eObj]` - Objective function accumulating investment, O&M, fuel, startup, transmission costs
  - `EP[:ePowerBalance]` - Zonal power balance constraint (generation = demand + losses ± storage ± transmission)
- **`core/`**: System-wide constraints (power balance, reserves, CO2, fuel, transmission, unit commitment)
- **`resources/`**: Resource-specific modules (thermal, VRE, hydro, storage, electrolyzers, VRE+storage, fusion, Allam cycle)
- **`policies/`**: Policy constraints (CO2 caps, capacity reserve margins, energy share requirements, min/max capacity)

### Resource System
**All resources inherit from `AbstractResource`**. Key concepts:
- Resource types defined in `resource_types` tuple: `:Thermal`, `:Vre`, `:Hydro`, `:Storage`, `:FlexDemand`, `:VreStorage`, `:Electrolyzer`, etc.
- Input files auto-discovered via `load_resource_data.jl` (e.g., `Thermal.csv` → `Thermal` type)
- **Each CSV row creates a resource instance**; columns become attributes
- Use **getter functions** (e.g., `existing_cap_mw(r)`) defined in `resources.jl` over direct dot access
- Helper functions: `ids_with()`, `ids_with_positive()`, `ids_with_policy()` for filtering resources

### Multi-Stage Modeling (src/multi_stage/)
- Supports **myopic** or **dual dynamic programming (DDP)** for multi-period planning
- Each stage has separate input folder: `inputs/inputs_p1/`, `inputs/inputs_p2/`, etc.
- Configured via `settings/multi_stage_settings.yml`

### Time Domain Reduction (src/time_domain_reduction/)
- **K-means clustering** of time series to reduce 8760 hours → representative periods
- Settings: `settings/time_domain_reduction_settings.yml`
- Output stored in `TimeDomainReductionFolder` (default: `TDR_results/`)

## Development Conventions

### Style & Formatting
- Use `CamelCase` for type names (e.g., `NewResource`), `snake_case` for functions/variables
- Functions modifying model: `function_name!(EP::Model, ...)` (note the `!`)

### JuMP Expression Patterns
**Critical**: Use GenX utility functions to manipulate JuMP expressions safely:
- `create_empty_expression!(EP, :exprname, dims)` - Initialize expression
- `add_similar_to_expression!()` - Add array to existing expression
- `add_term_to_expression!()` - Add single term
- **Never** directly assign `EP[:expr] = value` except for initialization

### Adding New Resources
1. Add type to `resource_types` in `src/model/resources/resources.jl`
2. Add filename mapping in `_get_resource_info()` in `src/load_inputs/load_resources_data.jl`
3. Create getter functions for resource attributes
4. Add resource-specific constraints in `src/model/resources/new_resource/` folder
5. Register module in `generate_model.jl` to call during model building

### Testing
- Run tests: `julia --project=. test/runtests.jl`
- Tests in `test/` mirror `src/` structure
- Example systems in `example_systems/` serve as integration tests
- Each example has `Run.jl` that calls `run_genx_case!(dirname(@__FILE__))`

## Common Workflows

### Running a Case
```julia
using GenX
run_genx_case!("path/to/case")  # Uses HiGHS by default
using Gurobi
run_genx_case!("path/to/case", Gurobi.Optimizer)  # With Gurobi
```

### Case Structure
```
case_folder/
├── resources/        # Resource input CSVs (Thermal.csv, Vre.csv, Storage.csv, etc.)
├── system/           # System data (Demand_data.csv, Generators_variability.csv, Fuels_data.csv)
├── policies/         # Policy constraints (CO2_cap.csv, Energy_share_requirement.csv, etc.)
├── settings/         # YAML configurations (genx_settings.yml, output_settings.yml)
└── Run.jl           # Entry point
```

### Modifying Objective Function
All cost components append to `EP[:eObj]` in respective modules:
- Investment costs: `investment_discharge!()`, `investment_energy!()`, `investment_charge!()`
- Operational costs: Resource-specific operational modules
- Transmission: `transmission_expansion!()` in `core/transmission.jl`

### Accessing Model Data
```julia
inputs = load_inputs(setup, case_path)
gen = inputs["RESOURCES"]  # Vector of all resources
thermal_indices = thermal(gen)  # Indices of thermal resources
thermal_resources = gen.Thermal  # Or gen[thermal(gen)]
```

## Key Settings (genx_settings.yml)
- `NetworkExpansion`: Enable transmission expansion (0/1)
- `UCommit`: Unit commitment mode (0=off, 1=integer, 2=linearized)
- `TimeDomainReduction`: Enable clustering (0/1)
- `ParameterScale`: Scale to GW instead of MW (0/1)
- `CO2Cap`: Emissions constraint type (0=none, 1=mass, 2=demand+rate, 3=generation+rate)
- `MultiStage`: Multi-period planning (0/1)

## Debugging Tips
- Check `EP` model object: `@show EP[:eObj]`, `@show EP[:ePowerBalance]`
- Examine solver logs for infeasibility/unboundedness
- Validate inputs: Ensure CSV files match expected schema (see docs)
- Time domain reduction issues: Delete TDR folder to force regeneration
- Use `ParameterScale=1` for numerical stability on large cases
- Julia version matters: **Use Julia 1.9** for best performance (1.10 has known slowdowns)

## Documentation
- Full docs: https://genxproject.github.io/GenX.jl/dev
- Input file specs: See `docs/src/User_Guide/`
- Mathematical formulation: See `docs/src/Model_Reference/`
- Developer guide: See `docs/src/developer_guide.md`

## Critical Dependencies
- Delete `Manifest.toml` when switching Julia versions
- Use `Pkg.instantiate()` to sync dependencies from `Project.toml`
- Commercial solvers (Gurobi/CPLEX) require valid licenses

## Code Philosophy
GenX prioritizes **modularity and extensibility**. Each resource/policy module is self-contained, only interacting through `EP[:eObj]` and `EP[:ePowerBalance]`. This design allows easy addition of new resources, technologies, and constraints without touching core code.

## Pull Request Requirements (Critical for CI)

### 1. CHANGELOG.md Updates (REQUIRED)
**All PRs must update `CHANGELOG.md`** unless labeled `Skip-Changelog` or `skip changelog`. Follow [Keep a Changelog](https://keepachangelog.com) format:

```markdown
## Unreleased

### Added
- New feature description (#PR_NUMBER).

### Changed
- Modified behavior description (#PR_NUMBER).

### Fixed
- Bug fix description (#PR_NUMBER).
```

**Categories**: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`

### 2. Documentation Requirements
**All code changes require documentation updates:**

#### New Functions/Methods
- Add docstrings following Julia conventions
- Use `@doc raw"""` for mathematical notation (LaTeX/KaTeX)
- Document parameters with `# Arguments` section
- Include `# Returns` section

#### New Input Files or Columns
- Update `docs/src/User_Guide/model_input.md`
- Specify: column names, data types, units, default values
- Add table entries following existing format
- Include examples from `example_systems/`

#### New Output Files or Columns
- Update `docs/src/User_Guide/model_output.md`
- Document: variable names, descriptions, units
- Specify when output is generated (which settings enable it)

#### New Resources
- Add documentation in `docs/src/Model_Reference/Resources/`
- Include mathematical formulation
- Document all CSV input columns
- Provide example usage

### 3. Testing Requirements
**All PRs must pass CI tests:**
- Tests run on Julia 1.6, 1.9, 1.10, and latest stable
- Tests run on Ubuntu (all versions) + Windows (latest)
- All tests in `test/runtests.jl` must pass
- Example systems in `example_systems/` must run successfully

#### Adding Tests
- Add test file in `test/` matching `src/` structure
- Use `@testset` blocks for organization
- Include in `test/runtests.jl` if needed
- Tests should be written as functions within each test file. Use the **test-writer** agent to create or modify tests.

### 4. PR Template Checklist
Complete all items in `.github/PULL_REQUEST_TEMPLATE.md`:
- [ ] Code sufficiently documented (docstrings + .md updates)
- [ ] Conflicts resolved with target branch
- [ ] Code tested and functionality verified
- [ ] CHANGELOG.md updated
- [ ] GPL consent given

### 5. Common PR Patterns

#### Adding New Resource Type
1. Update `resource_types` in `src/model/resources/resources.jl`
2. Add filename mapping in `src/load_inputs/load_resources_data.jl`
3. Create module in `src/model/resources/new_resource/`
4. Add to `generate_model.jl` dispatch
5. Create `docs/src/Model_Reference/Resources/new_resource.md`
6. Update `docs/src/User_Guide/model_input.md` with CSV schema
7. Add example in `example_systems/` (optional but recommended)
8. Add test in `test/test_new_resource.jl`
9. Update `CHANGELOG.md` under `### Added`

#### Modifying Input/Output Schema
1. Update CSV processing in `load_inputs/` or `write_outputs/`
2. Update corresponding documentation in `docs/src/User_Guide/`
3. Update ALL example systems with new schema
4. Update tests to reflect new schema
5. Update `CHANGELOG.md` under `### Changed`
6. **Breaking changes**: Mark clearly in CHANGELOG and docs

#### Performance Improvements
1. Use `add_to_expression!` and `add_similar_to_expression!` instead of `+=`
2. Pre-process sets before `@expression` loops
3. Document performance impact in PR description
4. Update `CHANGELOG.md` under `### Changed` or `### Added`
