# nf-carafe-ai-ms

A [Nextflow](https://www.nextflow.io/) workflow for generating AI-enhanced spectral libraries for Data-Independent Acquisition (DIA) mass spectrometry analysis using [Carafe](https://github.com/Noble-Lab/Carafe).

## Documentation

**Full documentation:** https://nf-carafe-ai-ms.readthedocs.io/

## What Does This Workflow Do?

This workflow takes your DIA mass spectrometry data and a protein FASTA database and produces an experiment-specific spectral library using AI. The resulting library can be used for peptide identification and quantification in downstream DIA analysis tools.

You provide your spectra files and a FASTA file. The workflow handles everything else automatically -- converting file formats, running peptide identification with DIA-NN, and generating the final spectral library with Carafe.

### Workflow Overview

```
                          ┌─────────────────┐
                          │   Input Files   │
                          │                 │
                          │  Spectra files  │
                          │  (.raw, .mzML,  │
                          │   .d, .d.zip)   │
                          │       +         │
                          │  FASTA database │
                          └────────┬────────┘
                                   │
                      ┌────────────┼────────────┐
                      │            │            │
                      ▼            ▼            ▼
                ┌──────────┐ ┌─────────┐ ┌──────────┐
                │msconvert │ │  unzip  │ │  pass    │
                │.raw→.mzML│ │.d.zip→.d│ │  through │
                └─────┬────┘ └────┬────┘ │  (.mzML) │
                      │           │      └────┬─────┘
                      │           │           │
                      └───────────┼───────────┘
                                  │
                                  ▼
                        ┌──────────────────┐
                        │     DIA-NN       │
                        │                  │
                        │  Peptide ID in   │
                        │  library-free    │
                        │  mode            │
                        └────────┬─────────┘
                                 │
  ┌──────────────────┐           │
  │  User-supplied   │           │
  │  peptide ID file │           │
  │  (optional,      ├───────────┤
  │   skips DIA-NN)  │           │
  └──────────────────┘           │
                                 ▼
                        ┌──────────────────┐
                        │      Carafe      │
                        │                  │
                        │  AI-enhanced     │
                        │  spectral library│
                        │  generation      │
                        └────────┬─────────┘
                                 │
                    ┌────────────┴────────────┐
                    ▼                         ▼
           ┌───────────────┐        ┌────────────────┐
           │  DIA-NN TSV   │        │  EncyclopeDIA  │
           │  format       │        │  DLIB format   │
           └───────────────┘        └────────────────┘
```

## Key Features

- **No software installation required** (beyond Nextflow and Docker) -- all tools run in containers
- **Flexible input**: Thermo RAW, mzML, or Bruker .d/.d.zip files
- **Multiple files**: Process a single file or an entire directory of spectra files
- **PanoramaWeb integration**: Fetch input files directly from PanoramaWeb
- **Variable modifications**: Optional support for phosphorylation and oxidized methionine
- **Custom DIA-NN versions**: Build and use newer DIA-NN releases ([instructions](https://nf-carafe-ai-ms.readthedocs.io/en/latest/custom_diann.html))
- **Multiple execution environments**: Run locally, on a SLURM cluster, or on AWS Batch

## Quick Start

1. Install [Nextflow](https://www.nextflow.io/docs/latest/getstarted.html) and [Docker](https://docs.docker.com/engine/install/)

2. Download and edit the template configuration file:

    ```bash
    wget https://raw.githubusercontent.com/mriffle/nf-carafe-ai-ms/main/resources/pipeline.config
    ```

    At minimum, set `spectra_file` (or `spectra_dir`) and `carafe_fasta_file` to point to your data.

3. Run the workflow:

    ```bash
    nextflow run -resume -r main mriffle/nf-carafe-ai-ms -c pipeline.config
    ```

Results will appear in the `results/nf-carafe-ai-ms/` directory.

For detailed instructions, see the **[full documentation](https://nf-carafe-ai-ms.readthedocs.io/)**.


## License

Apache 2.0 -- see [LICENSE](LICENSE) for details.
