# GenX Morris Sensitivity Analysis and BFPS–Optimal Transport Enhancements

Developed by: Shane Menezes
E-mail: smenezes@binghamton.edu
Institution: Binghamton University – Systems Science

## 1. Overview

This package contains enhancements to the GenX capacity expansion modeling workflow for Morris global sensitivity analysis and BFPS–Optimal Transport screening.

It is intended to support technical review, testing, and potential integration of these enhancements into GenX. The package includes modified Julia source files, relevant configuration settings, parameter-range data, a technical walkthrough, and an NY-specific example system.

The workflow evaluates how variations in selected model parameters influence model outputs and supports the screening of influential parameters.

## 2. Package Contents

| Path | Description |
|---|---|
|`src/additional_tools/method_of_morris.jl`     |          Contains the modified method_of_morris.jl implementing the Morris redesign. Replace the corresponding file in the existing GenX repository after reviewing the changes.|
|`src/configure_settings/configure_settings.jl`   |          Contains the modified configure_settings.jl. Replace the corresponding file in the existing GenX repository after reviewing the changes.|
|`src/load_inputs/load_demand_data.jl`          |            Contains the modified demand input-loading Julia file. Update the corresponding file in the existing GenX repository after reviewing the changes.|
|`src/load_inputs/load_fuels_data.jl`          |            Contains the modified fuel input-loading Julia file. Update the corresponding file in the existing GenX repository after reviewing the changes.|
|`src/load_inputs/load_resources_data.jl`          |            Contains the resource input-loading Julia file. Update the corresponding file in the existing GenX repository after reviewing the changes.|
| `settings/` | Relevant GenX configuration settings |
| `Method_of_morris_range_zone.csv` | Parameter-range and zone definitions used by the Morris workflow. Should be placed in the inputs directory for the scenario run such as inputs_p3 |
| `Method_of_Morris_GenX_Package.pptx` | Technical walkthrough of the implementation |
| `example_systems/NY_v11/` | NY-specific model configuration and example inputs |

Integration note: These directories contain targeted modifications, not a complete copy of the GenX source tree. Review and integrate the modified files into the corresponding locations in the existing GenX repository, preserving the original directory structure and validating compatibility with the target GenX version.

The example system includes policy configurations, model settings, and input files used in the demonstrated NY workflow.

## 3. Implementation Areas

The package includes changes associated with:

- Morris sensitivity-analysis execution.
- Parameter-range and zone configuration.
- Demand, fuel, and resource input loading.
- GenX settings and configuration handling.
- Generation of sensitivity-analysis and BFPS–Optimal Transport screening outputs.

The exact behavior and dependencies of these changes should be verified against the included source code during technical review.

## 4. Example System and Scenarios

The included example is based on the NY model configuration.

The following scenario directories contain the files used by the demonstrated Morris workflow:

- `example_systems/NY_v11/Current_Policy/inputs/inputs_p3/`
- `example_systems/NY_v11/Current_Policy/inputs/inputs_p3_ESR_CapResMar/`

Each directory contains the following Morris-related files:

- `Current_Policy.jl` — Julia entry point for the current-policy workflow.
- `Current_Policy_morris.sh` — batch submission script used to launch the Morris workflow.
- `Method_of_morris_range_zone.csv` — parameter-range and zone definitions.

The scenario directories also contain model inputs and configuration files required by the associated NY setup.

The example is NY-specific. Its compatibility with other GenX example systems has not been established solely by including these files.

## 5. Running the Morris Workflow

The demonstrated workflow uses a computing cluster with a batch scheduler.

### Step 1: Navigate to the scenario input directory

For the baseline scenario:

```bash
cd example_systems/NY_v11/Current_Policy/inputs/inputs_p3
```

For the ESR and capacity-reserve-margin scenario:

```bash
cd example_systems/NY_v11/Current_Policy/inputs/inputs_p3_ESR_CapResMar
```

These paths are relative to the package's parent directory. Adjust them if your working directory differs.

### Scenario-Specific GenX Settings

When running the `inputs_p3_ESR_CapResMar` scenario, activate both the Energy Share Requirement and Capacity Reserve Margin settings in `settings/genx_settings.yml` before submitting the run.

Set the following parameters:

EnergyShareRequirement: 1 # Minimum qualifying renewables penetration; 0 = not active; 1 = active systemwide

CapacityReserveMargin: 1 # Number of capacity reserve margin constraints; 0 = not active; 1 = active systemwide
```
**Important:** These settings activate the corresponding systemwide policy constraints for this scenario. 


### Step 2: Verify required files

Confirm that the selected scenario directory contains:

- `Current_Policy.jl`
- `Current_Policy_morris.sh`
- `Method_of_morris_range_zone.csv`

Also confirm that the other required GenX inputs, configuration files, Julia environment, and solver are available.

### Step 3: Submit the Morris workflow

Submit the batch job using:

```bash
sbatch Current_Policy_morris.sh
```

The batch script is responsible for launching the configured workflow. Review the script to verify its working directory, resource requests, Julia environment, and command used to invoke `Current_Policy.jl`.

### Step 4: Monitor execution

Monitor the submitted job using the computing cluster's job-status tools and inspect the associated logs for errors or successful completion.

Confirm that the expected GenX model evaluations and Morris analysis steps execute.

### Step 5: Verify outputs

After execution, inspect the generated sensitivity-analysis and screening outputs. Confirm that the outputs were generated by the current run and contain valid results.

All GenX outputs including the morris outputs results are under the results folder.

The Key Morris Output results:
morris.csv
** morris_means_all_outputs.csv		
** morris_variances_all_outputs.csv
** morris_bfps_all_outputs.csv		
** morris_outputs_all_design_points.csv
** morris_effect_diagnostics.csv		-- Optional
** morris_input_labels.csv			-- Optional

** New Morris outputs as part of this code change.

## 6. Testing and Validation

The recommended validation sequence is:

1. Confirm that the selected GenX scenario runs successfully without the Morris workflow, where applicable.
2. Verify that the parameter-range CSV and required input files are available.
3. Run a small Morris test design, if supported by the implementation's configuration.
4. Inspect the generated Morris/BFPS outputs.


## 7. Dependencies and Compatibility

The package contains Julia-based GenX source code and associated configuration files. Python supporting tools may be present in the broader repository.

Before execution, confirm the required Julia version, package environment, GenX version, solver, and any Python dependencies used by the supporting tools.

Exact dependency and execution requirements should be confirmed against the source code, scripts, and target computing environment.

## 8. Scope and Limitations

- The included example uses NY-specific zones, policies, and model inputs.
- The example may require adaptation before it can be used with other GenX example systems.
- Execution depends on the configuration, dependencies, solver, and file paths expected by the scripts.
- Test results should be generated from fresh runs when validating the implementation.
- Changes to GenX core functionality should be reviewed for compatibility with the upstream codebase.

## 9. Attribution and Citation

For research publications, presentations, or reports that use or build upon the original methods and enhancements developed by Shane Menezes, please acknowledge the relevant contribution and cite the associated research publication:

Menezes, S., & Patankar, N. (2026). *Zonal Global Sensitivity Analysis for Policy-Constrained Capacity Expansion Planning in New York.* 11th North American International Conference on Industrial Engineering and Operations Management.

https://doi.org/10.46254/NA11.20260328

Please also preserve and follow all applicable GenX copyright notices and software license terms.

## 10. Contribution and Review

This package is provided for technical review of the Morris sensitivity-analysis and BFPS–Optimal Transport enhancements. The included example_systems/NY_v11/ materials are provided to support reviewer testing and validation of the submitted enhancements. They are not intended as general-purpose GenX example systems.

Potential integration into GenX should follow the GenX project's contribution, code review, testing, and licensing requirements.
