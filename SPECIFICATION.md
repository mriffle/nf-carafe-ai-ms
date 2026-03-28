# nf-carafe-ai-ms: Project Specification

## What This Project Is

nf-carafe-ai-ms is a **Nextflow DSL2 workflow** for generating AI-enhanced experiment-specific spectral libraries for Data-Independent Acquisition (DIA) mass spectrometry analysis. It uses the [Carafe](https://github.com/Noble-Lab/Carafe) tool, which leverages AI to produce in silico spectral libraries from a protein FASTA database and DIA experiment data.

The workflow automates the full pipeline: acquiring input files (locally, from S3, or from PanoramaWeb), converting raw mass spectrometry data to mzML (or unzipping Bruker `.d.zip` archives to `.d` directories), running DIA-NN for peptide identification, and feeding those results to Carafe for enhanced spectral library generation. Output libraries can be produced in either DIA-NN TSV or EncyclopeDIA DLIB format.

**Author:** Michael Riffle
**License:** Apache 2.0
**Documentation:** https://nf-carafe-ai-ms.readthedocs.io/
**Source:** https://github.com/mriffle/nf-carafe-ai-ms
**Requires:** Nextflow >= 21.10.3

---

## Workflow Pipeline

The workflow executes these steps in order:

```
1. Parameter Validation
   - Either spectra_file or spectra_dir is required (mutually exclusive)
   - spectra_file may be a .raw, .mzML, .d directory, or .d.zip file
   - spectra_dir files (after glob matching) must all be the same type: .raw, .mzML, .d, or .d.zip
   - Bruker .d directories cannot be downloaded from PanoramaWeb; use .d.zip files instead
   - carafe_fasta_file (required)
   - output_format must be 'diann' or 'encyclopedia'

2. AWS Secrets Setup (conditional)
   - Only when profile='aws' AND PanoramaWeb URLs are used
   - GET_AWS_USER_ID -> BUILD_AWS_SECRETS

3. get_input_files (subworkflow)
   - Downloads FASTA files and peptide reports from PanoramaWeb if URLs provided
   - Otherwise passes through local file paths

4. get_mzmls (subworkflow)
   - Supports single file (spectra_file) or directory of files (spectra_dir + spectra_dir_glob)
   - For spectra_dir: globs the directory for matching files (using `type: 'any'` to match directories), validates all are .raw, .mzML, .d, or .d.zip
   - For PanoramaWeb directories: uses PANORAMA_GET_RAW_FILE_LIST to list and filter files, then downloads each. Rejects .d directory globs (only .d.zip allowed from Panorama).
   - Converts RAW -> mzML via msconvert (skipped if input is already mzML or Bruker data)
   - Unzips .d.zip -> .d via UNZIP_BRUKER_DATA (ubuntu container)
   - Passes .mzML and .d inputs through directly
   - Supports caching of converted mzML files
   - Emits a channel of one or more mzML files or .d directories

5. diann_search (subworkflow, conditional)
   - Skipped if peptide_results_file parameter is provided
   - Runs DIA-NN in library-free mode for peptide identification
   - Produces precursor TSV used as Carafe input

6. carafe (subworkflow)
   - Collects all mzML files and/or .d directories and runs Carafe AI tool with `-ms "."` to process them all
   - Outputs carafe_spectral_library.tsv

7. ENCYCLOPEDIA_TSV_TO_DLIB (conditional)
   - Only when output_format='encyclopedia'
   - Converts Carafe TSV output to EncyclopeDIA DLIB format

8. Email notification on workflow completion (if configured)
```

---

## Project Structure

```
nf-carafe-ai-ms/
├── main.nf                        # Main workflow entry point
├── nextflow.config                # Primary configuration (params, profiles, reporting)
├── container_images.config        # Docker/container image version mappings
├── conf/
│   └── base.config                # Process resource labels and retry logic
├── modules/                       # Nextflow process definitions (one per tool)
│   ├── aws.nf                     # GET_AWS_USER_ID, BUILD_AWS_SECRETS
│   ├── bruker.nf                  # UNZIP_BRUKER_DATA (.d.zip -> .d)
│   ├── carafe.nf                  # CARAFE process
│   ├── diann.nf                   # DIANN_SEARCH_LIB_FREE, BLIB_BUILD_LIBRARY
│   ├── encyclopedia.nf            # ENCYCLOPEDIA_TSV_TO_DLIB
│   ├── msconvert.nf               # MSCONVERT (RAW to mzML)
│   └── panorama.nf                # PANORAMA_GET_FILE, PANORAMA_GET_RAW_FILE, etc.
├── workflows/                     # Subworkflows composing modules
│   ├── carafe.nf                  # Carafe execution subworkflow
│   ├── diann_search.nf            # DIA-NN search subworkflow
│   ├── get_input_files.nf         # Input file acquisition subworkflow
│   ├── get_mzmls.nf               # mzML preparation subworkflow
│   └── save_run_details.nf        # Run metadata collection (currently disabled)
├── lib/
│   └── EmailTemplate.groovy       # Groovy class for email notification rendering
├── assets/
│   └── email_template.html        # HTML email template
├── resources/
│   └── pipeline.config            # Example user configuration file
├── docs/                          # Sphinx documentation for ReadTheDocs
│   ├── source/
│   │   ├── conf.py                # Sphinx config (RTD theme, autosectionlabel)
│   │   ├── index.rst              # Documentation index
│   │   ├── overview.rst           # Workflow overview
│   │   ├── how_to_install.rst     # Installation guide
│   │   ├── how_to_run.rst         # Execution guide
│   │   ├── workflow_parameters.rst# Parameter reference
│   │   ├── results.rst            # Output file descriptions
│   │   ├── set_up_aws.rst         # AWS setup reference
│   │   └── _static/               # CSS and images
│   ├── Makefile
│   ├── make.bat
│   └── requirements.txt           # sphinx==7.1.2, sphinx_rtd_theme==1.3.0
├── .readthedocs.yaml              # ReadTheDocs build configuration
├── .github/
│   └── workflows/
│       └── stub-tests.yml         # GitHub Actions CI: stub tests on every push
├── tests/
│   ├── run_stub_tests.sh          # Stub test runner (7 scenarios)
│   ├── stub_test.config           # Nextflow config for stub testing
│   └── data/                      # Minimal dummy input files for stub tests
│       ├── test.mzML
│       ├── test.fasta
│       ├── test_peptides.tsv
│       ├── test.raw
│       ├── test.d/               # Empty Bruker .d directory for spectra_file tests
│       ├── test.d.zip            # Zip containing test.d/ for spectra_file tests
│       ├── mzml_dir/             # Directory with multiple mzML files for spectra_dir tests
│       │   ├── test1.mzML
│       │   └── test2.mzML
│       ├── raw_dir/              # Directory with multiple RAW files for spectra_dir tests
│       │   ├── test1.raw
│       │   └── test2.raw
│       ├── bruker_d_dir/         # Directory with multiple Bruker .d directories for spectra_dir tests
│       │   ├── test1.d/
│       │   └── test2.d/
│       └── bruker_zip_dir/       # Directory with multiple Bruker .d.zip files for spectra_dir tests
│           ├── test1.d.zip
│           └── test2.d.zip
├── README.md
└── LICENSE                        # Apache 2.0
```

---

## Key Files in Detail

### `main.nf`
The workflow entry point. Validates parameters (requiring either `spectra_file` or `spectra_dir`, but not both), conditionally sets up AWS secrets for PanoramaWeb access, orchestrates all subworkflows, and handles email notifications on completion. Contains helper functions `is_panorama_used()` and `panorama_auth_required_for_url()` for determining when AWS Secrets Manager credentials are needed. Also defines a `dummy` workflow for testing.

### `nextflow.config`
Defines all workflow parameters, execution profiles (standard/aws/slurm), AWS Batch settings, Nextflow reporting (timeline, report, trace), and the `check_max()` utility function for capping resource requests. Includes `conf/base.config` and `container_images.config`.

Note: The file header comment references `nf-maccoss-trex`, which is a legacy name; the actual project is `nf-carafe-ai-ms`.

### `container_images.config`
Maps logical image names to versioned container URIs on Quay.io (`quay.io/protio/*`). All tools run in containers, so no local tool installation is required.

### `conf/base.config`
Defines default process resources and resource labels used throughout modules.

**Default process behavior**: 1 CPU, 4 GB, 1h (scaling with retry attempts). Retries up to 3 times on exit codes 143, 137, 104, 134, 139, 5, 6, null; otherwise finishes on error.

**Resource labels** (resources scale with retry attempts via `check_max()` unless noted as "constant"):
- `process_low_constant`: 2 CPUs, 8 GB, 1h (fixed, no scaling)
- `process_low`: 2 CPUs, 8 GB, 2h
- `process_medium`: 4 CPUs, 15 GB, 8h
- `process_high`: 32 CPUs, 60 GB, 8h
- `process_high_constant`: 128 CPUs, 128 GB, 24h (fixed, no scaling)
- `process_memory_high_constant`: 16 CPUs, 128 GB, 24h (fixed, no scaling)
- `process_long`: 20h time override
- `process_short`: 1h time override
- `process_high_memory`: 60 GB memory override

**Error handling labels**:
- `error_retry`: Unconditional retry on any failure, max 2 retries
- `error_ignore`: Ignores errors entirely

---

## Modules

Each module file in `modules/` defines one or more Nextflow processes wrapping a containerized tool.

| Module | Processes | Container | Purpose |
|--------|-----------|-----------|---------|
| `aws.nf` | `GET_AWS_USER_ID`, `BUILD_AWS_SECRETS` | (no container; runs locally) | AWS identity and Secrets Manager for PanoramaWeb API keys |
| `bruker.nf` | `UNZIP_BRUKER_DATA` | ubuntu:22.04 | Unzip Bruker `.d.zip` archives to `.d` directories |
| `panorama.nf` | `PANORAMA_GET_FILE`, `PANORAMA_GET_RAW_FILE`, `PANORAMA_GET_RAW_FILE_LIST` | panorama-client:1.1.0 | Download files from PanoramaWeb via WebDAV, with caching. `PANORAMA_GET_RAW_FILE_LIST` is used by `get_mzmls` when `spectra_dir` is a PanoramaWeb URL. |
| `msconvert.nf` | `MSCONVERT` | proteowizard:3.0.24172 | Convert RAW files to mzML (runs via wine) |
| `diann.nf` | `DIANN_SEARCH_LIB_FREE`, `BLIB_BUILD_LIBRARY` | diann:1.8.1 (note: `BLIB_BUILD_LIBRARY` references `params.images.bibliospec` which is not defined in `container_images.config`) | Library-free DIA-NN peptide identification |
| `carafe.nf` | `CARAFE` | carafe:2.0.0 | AI-enhanced spectral library generation (Java JAR). Uses `-ms "."` to process all mzML files and Bruker `.d` directories in the working directory. |
| `encyclopedia.nf` | `ENCYCLOPEDIA_TSV_TO_DLIB` | encyclopedia:2.12.30-2 | Convert Carafe TSV to EncyclopeDIA DLIB format |

### Notable Implementation Details

- **Bruker module**: Unzips `.d.zip` files using the `ubuntu` container. Output is the `.d` directory (derived from `zip_file.baseName`).
- **Carafe module**: Detects Apptainer/Singularity vs Docker and conditionally activates a conda environment. Allocates Java heap as `(task.memory - 1 GB)`. Accepts both mzML files and Bruker `.d` directories as input (staged into the work directory and discovered via `-ms "."`).
- **Panorama module**: Uses `PanoramaClient.jar` for WebDAV access. On AWS, retrieves API keys from Secrets Manager. `PANORAMA_GET_RAW_FILE` uses `storeDir` for file caching; `PANORAMA_GET_FILE` does not cache (used for FASTA, report, and spectra file downloads). `PANORAMA_GET_RAW_FILE_LIST` lists files on a PanoramaWeb directory, filters by a glob-derived regex, and outputs `download_files.txt` with full download URLs. The `panorama_auth_required_for_url()` helper is duplicated across `main.nf`, `get_input_files.nf`, and `get_mzmls.nf`.
- **msconvert module**: Caches output mzML files using `storeDir` keyed by `workflow.commitId` and demux/simasspectra settings.
- **All modules**: Include `stub` blocks for dry-run testing of workflow structure.

---

## Subworkflows

| Subworkflow | File | Purpose |
|-------------|------|---------|
| `get_input_files` | `workflows/get_input_files.nf` | Acquires FASTA files and peptide reports; handles PanoramaWeb downloads vs local files. Exports `param_to_list()` utility. |
| `get_mzmls` | `workflows/get_mzmls.nf` | Acquires spectra files (single via `spectra_file` or multiple via `spectra_dir` + glob), converts RAW to mzML if needed, and unzips `.d.zip` to `.d` if needed. For PanoramaWeb directories, uses `PANORAMA_GET_RAW_FILE_LIST` to list and filter files, then `PANORAMA_GET_FILE` to download each (`.d` directories rejected for Panorama; only `.d.zip` allowed). For local directories, globs files/directories (with `type: 'any'`) and validates extensions. |
| `diann_search` | `workflows/diann_search.nf` | Runs DIA-NN in library-free mode; outputs precursor TSV and spectral library. |
| `carafe` | `workflows/carafe.nf` | Collects all mzML files and/or Bruker `.d` directories and runs Carafe with `-ms "."` to process them all, along with FASTA and peptide results. |
| `save_run_details` | `workflows/save_run_details.nf` | Collects version info and run metadata (currently disabled in main.nf). Also defines the `WRITE_VERSION_INFO` process inline (not in a module file). |

---

## Configuration and Parameters

### Required Parameters
| Parameter | Description |
|-----------|-------------|
| `spectra_file` | Path to a single RAW, mzML, Bruker `.d` directory, or `.d.zip` file (local path, S3 URI, or PanoramaWeb URL). Bruker `.d` directories cannot be used with PanoramaWeb URLs. Mutually exclusive with `spectra_dir`. |
| `spectra_dir` | Path to a directory containing RAW, mzML, Bruker `.d`, or `.d.zip` files (local path or PanoramaWeb WebDAV URL). Bruker `.d` directories cannot be used with PanoramaWeb URLs. Mutually exclusive with `spectra_file`. |
| `carafe_fasta_file` | Protein FASTA file for Carafe (local path or PanoramaWeb URL) |

*Note: Either `spectra_file` or `spectra_dir` must be provided, but not both.*

### Optional Parameters
| Parameter | Default | Description |
|-----------|---------|-------------|
| `spectra_dir_glob` | `'*.raw'` | Glob pattern to select files from `spectra_dir`. All matched files must have the same extension (.raw, .mzML, .d, or .d.zip). |
| `output_format` | `'diann'` | Output format: `'diann'` (TSV) or `'encyclopedia'` (DLIB) |
| `peptide_results_file` | `null` | Pre-computed DIA-NN results; skips DIA-NN search if provided |
| `diann_fasta_file` | `null` | Separate FASTA for DIA-NN; uses `carafe_fasta_file` if null |
| `diann_params` | `'--unimod4 --qvalue 0.01 --cut \'K*,R*,!*P\' --reanalyse --smart-profiling'` | DIA-NN CLI options |
| `carafe_cli_options` | `''` | Additional Carafe CLI options (do not set `-ms`, `-db`, `-i`, `-se`, `-lf_type`, or `-device` as the workflow sets these) |
| `msconvert.do_demultiplex` | `true` | Enable demultiplexing in msconvert |
| `msconvert.do_simasspectra` | `true` | Enable simAsSpectra in msconvert |
| `email` | `null` | Email address for completion notifications |

### Execution Profiles
- **`standard`** (default): Local execution, 1 task at a time, 12 GB / 8 CPU limits
- **`aws`**: AWS Batch execution, 250 GB / 32 CPU limits, S3 caching
- **`slurm`**: HPC SLURM cluster execution, 12 GB / 8 CPU limits

Users provide configuration via a `pipeline.config` file (see `resources/pipeline.config` for an example) passed with `-c pipeline.config`.

---

## Container Images

All tools run in Docker containers from the `quay.io/protio/` registry:

| Image Key | Image URI | Tool |
|-----------|-----------|------|
| `ubuntu` | `ubuntu:22.04` | General utilities (Bruker .d.zip extraction) |
| `diann` | `quay.io/protio/diann:1.8.1` | DIA-NN |
| `carafe` | `quay.io/protio/carafe:2.0.0` | Carafe |
| `panorama_client` | `quay.io/protio/panorama-client:1.1.0` | PanoramaWeb client |
| `encyclopedia` | `quay.io/protio/encyclopedia:2.12.30-2` | EncyclopeDIA |
| `proteowizard` | `quay.io/protio/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.24172-63d00b1` | msconvert |

Image versions are centralized in `container_images.config` and referenced throughout modules as `params.images.<key>`.

---

## Outputs

Results are written to `results/nf-carafe-ai-ms/` by default:

```
results/nf-carafe-ai-ms/
├── carafe/
│   ├── carafe_spectral_library.tsv      # Main output (DIA-NN format)
│   ├── carafe_spectral_library.dlib     # If output_format='encyclopedia'
│   ├── carafe_version.txt
│   ├── parameter.txt                    # Carafe parameters used
│   ├── carafe.stdout / carafe.stderr
│   └── encyclopedia-convert-*.stdout/stderr  # If encyclopedia conversion ran
├── diann/                               # If DIA-NN search ran
│   ├── report.tsv                       # Precursor-level results
│   ├── report.tsv.speclib
│   ├── lib.predicted.speclib
│   ├── *.quant
│   ├── diann_version.txt
│   └── diann.stdout / diann.stderr
└── panorama/                            # If PanoramaWeb files were downloaded
    └── *.stdout / *.stderr
```

Nextflow execution reports (timeline, trace, HTML report) are written to `reports/nf-carafe-ai-ms/`.

---

## Documentation System

Documentation is built with Sphinx using the ReadTheDocs theme and hosted at https://nf-carafe-ai-ms.readthedocs.io/.

- **Source files**: `docs/source/*.rst` (reStructuredText)
- **Sphinx config**: `docs/source/conf.py`
- **Build config**: `.readthedocs.yaml` (Python 3.12, Ubuntu 22.04)
- **Dependencies**: `docs/requirements.txt`
- **Extensions**: `sphinx_rtd_theme`, `sphinx.ext.autosectionlabel`, `readthedocs-sphinx-search`

To build docs locally:
```bash
cd docs && make html
```

---

## Running the Workflow

```bash
# Local execution
nextflow run -resume -r main mriffle/nf-carafe-ai-ms -c pipeline.config

# AWS Batch execution
nextflow run -resume -r main mriffle/nf-carafe-ai-ms -profile aws -c pipeline.config

# From a local clone
nextflow run -resume main.nf -c pipeline.config
```

---

## PanoramaWeb Integration

The workflow supports fetching input files from [PanoramaWeb](https://panoramaweb.org/) via WebDAV URLs. When running on AWS Batch, PanoramaWeb API keys are stored in AWS Secrets Manager and retrieved at runtime. Authentication is skipped for files in the `Panorama Public` folder. The `panorama.nf` module uses a Java-based `PanoramaClient.jar` for all WebDAV operations.

---

## Testing

### Stub Tests

Every process in the project **must** have a `stub:` block that produces all declared outputs using only basic shell commands (`touch`, `echo`, `mkdir`). Stubs must **not** depend on container-specific binaries (e.g., `diann`, `java`) so they can run without Docker.

Stub tests verify that all workflow paths are correctly wired together by running every process's `stub` block end-to-end.

**Test infrastructure:**

```
tests/
├── run_stub_tests.sh        # Test runner script (18 test scenarios)
├── stub_test.config          # Nextflow config: disables Docker and reporting
└── data/
    ├── test.mzML             # Minimal mzML for stub input
    ├── test.fasta            # Minimal FASTA for stub input
    ├── test_peptides.tsv     # Minimal DIA-NN report for stub input
    ├── test.raw              # Empty RAW file for msconvert path
    ├── test.d/               # Empty Bruker .d directory for spectra_file tests
    ├── test.d.zip            # Zip containing test.d/ for spectra_file tests
    ├── mzml_dir/             # Directory with multiple mzML files for spectra_dir tests
    │   ├── test1.mzML
    │   └── test2.mzML
    ├── raw_dir/              # Directory with multiple RAW files for spectra_dir tests
    │   ├── test1.raw
    │   └── test2.raw
    ├── bruker_d_dir/         # Directory with multiple Bruker .d directories for spectra_dir tests
    │   ├── test1.d/
    │   └── test2.d/
    └── bruker_zip_dir/       # Directory with multiple Bruker .d.zip files for spectra_dir tests
        ├── test1.d.zip
        └── test2.d.zip
```

**Test scenarios** (in `tests/run_stub_tests.sh`):

| # | Scenario | Processes exercised |
|---|----------|-------------------|
| 1 | Default: mzML + DIA-NN + Carafe (diann output) | `DIANN_SEARCH_LIB_FREE`, `CARAFE` |
| 2 | Encyclopedia output format | `DIANN_SEARCH_LIB_FREE`, `CARAFE`, `ENCYCLOPEDIA_TSV_TO_DLIB` |
| 3 | Pre-computed peptide results (skip DIA-NN) | `CARAFE` |
| 4 | Pre-computed peptides + encyclopedia output | `CARAFE`, `ENCYCLOPEDIA_TSV_TO_DLIB` |
| 5 | RAW input (triggers msconvert) | `MSCONVERT`, `DIANN_SEARCH_LIB_FREE`, `CARAFE` |
| 6 | Separate DIA-NN FASTA file | `DIANN_SEARCH_LIB_FREE`, `CARAFE` |
| 7 | Custom Carafe CLI options | `DIANN_SEARCH_LIB_FREE`, `CARAFE` |
| 8 | spectra_dir with multiple mzML files | `DIANN_SEARCH_LIB_FREE`, `CARAFE` (multiple inputs) |
| 9 | spectra_dir with multiple RAW files | `MSCONVERT`, `DIANN_SEARCH_LIB_FREE`, `CARAFE` (multiple inputs) |
| 10 | spectra_dir + pre-computed peptides | `CARAFE` (multiple inputs, DIA-NN skipped) |
| 11 | Bruker .d directory as spectra_file | `DIANN_SEARCH_LIB_FREE`, `CARAFE` |
| 12 | Bruker .d.zip file as spectra_file | `UNZIP_BRUKER_DATA`, `DIANN_SEARCH_LIB_FREE`, `CARAFE` |
| 13 | spectra_dir with multiple Bruker .d directories | `DIANN_SEARCH_LIB_FREE`, `CARAFE` (multiple inputs) |
| 14 | spectra_dir with multiple Bruker .d.zip files | `UNZIP_BRUKER_DATA`, `DIANN_SEARCH_LIB_FREE`, `CARAFE` (multiple inputs) |
| 15 | Panorama spectra_dir with RAW glob | `PANORAMA_GET_RAW_FILE_LIST`, `PANORAMA_GET_FILE` (x3), `MSCONVERT` (x3), `DIANN_SEARCH_LIB_FREE`, `CARAFE` |
| 16 | Panorama spectra_dir with mzML glob | `PANORAMA_GET_RAW_FILE_LIST`, `PANORAMA_GET_FILE` (x3), `DIANN_SEARCH_LIB_FREE`, `CARAFE` |
| 17 | Panorama spectra_dir with specific glob | `PANORAMA_GET_RAW_FILE_LIST`, `PANORAMA_GET_FILE` (x1), `MSCONVERT`, `DIANN_SEARCH_LIB_FREE`, `CARAFE` |
| 18 | Panorama spectra_dir with Bruker .d.zip glob | `PANORAMA_GET_RAW_FILE_LIST`, `PANORAMA_GET_FILE` (x3), `UNZIP_BRUKER_DATA` (x3), `DIANN_SEARCH_LIB_FREE`, `CARAFE` |

**Running locally:**
```bash
bash tests/run_stub_tests.sh          # run all stub tests (auto-cleans on completion)
bash tests/run_stub_tests.sh clean    # remove leftover test artifacts manually
```

### CI/CD

Stub tests run automatically on every push and pull request via GitHub Actions (`.github/workflows/stub-tests.yml`). The CI installs Nextflow, then runs the full stub test suite.

### Requirements When Changing or Adding Processes

When modifying existing processes or adding new ones:

1. **Every process must have a `stub:` block.** The stub must create all files declared in the process `output:` block. Use only basic shell commands — no container-specific binaries.
2. **Update stub tests if workflow paths change.** If a new process adds a workflow branch (e.g., a new conditional path), add a corresponding test scenario to `tests/run_stub_tests.sh`.
3. **Run stub tests locally before pushing.** Execute `bash tests/run_stub_tests.sh` to verify all workflow paths still work.
4. **CI must pass.** The GitHub Actions stub test workflow must pass on every push.

---

## Documentation Update Requirements

When implementing new features or making changes that affect user-facing behavior, the following documentation **must** be updated as part of the same change:

1. **`SPECIFICATION.md`** — Update all affected sections: workflow pipeline, project structure, modules, subworkflows, parameters, test scenarios, container images, and known notes.
2. **`docs/source/workflow_parameters.rst`** — Update parameter descriptions if input types, defaults, or validation rules change.
3. **`docs/source/overview.rst`** — Update the workflow components section if new tools or processing steps are added.
4. **`docs/source/index.rst`** — Update the introductory description if the scope of supported input types changes.
5. **`docs/source/results.rst`** — Update if new output files or directories are produced.
6. **`README.md`** — Update if the project scope or high-level description changes significantly.
7. **`tests/run_stub_tests.sh`** — Add test scenarios covering new workflow paths (already required by "Requirements When Changing or Adding Processes").

Failure to update documentation alongside code changes results in specification drift and user confusion. Treat documentation as a first-class deliverable, not a follow-up task.

---

## Known Notes

- The `save_run_details` subworkflow is included but currently disabled (commented out in `main.nf`).
- The `BLIB_BUILD_LIBRARY` process exists in `modules/diann.nf` but is not used in the current workflow. Its container image (`params.images.bibliospec`) is not defined in `container_images.config`.
- The `PANORAMA_GET_RAW_FILE_LIST` process is used by `get_mzmls` when `spectra_dir` is a PanoramaWeb URL. It lists files, filters by glob, and outputs download URLs.
- The `DESTROY_AWS_SECRETS` process in `modules/aws.nf` is commented out.
- The header comment in `nextflow.config` references `nf-maccoss-trex`, which is a legacy project name.
- The `panorama_auth_required_for_url()` function is duplicated in three files: `main.nf`, `workflows/get_input_files.nf`, and `workflows/get_mzmls.nf`.
- The Carafe process hardcodes `-se "DIA-NN"` (search engine), `-device cpu`, and `-ms "."` (processes all mzML files and Bruker `.d` directories in the working directory). It renames Carafe's native output (`SkylineAI_spectral_library.tsv`) to `carafe_spectral_library.tsv`.
