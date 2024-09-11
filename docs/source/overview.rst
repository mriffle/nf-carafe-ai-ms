===================================
Workflow Overview
===================================

These documents describe a standardized Nextflow workflow for running **the Carafe tool for experiment-specific in silico spectral library generation for DIA data
analysis**. The source code for the workflow can be found at: https://github.com/mriffle/nf-carafe-ai-ms.

How to Run
===================
This workflow uses the Nextflow standardized workflow platform. The Nextflow platform emphasizes ease of use, workflow portability,
and containerization of the individual steps. To run this workflow, **you do not need to install any of the software components of
the workflow**. There is no need to worry about installing necessary software libraries, version incompatibilities, or compiling or
installing complex and fickle software.

To run the workflow you need only install Nextflow, which is relatively simple. To run the individual steps of the workflow on your
own computer, you will need to install Docker. After these are installed, you will need to edit the pipeline configuration file to
supply the locations of your data and execute a simple Nextflow command, such as:

.. code-block:: bash

    nextflow run -resume -r main mriffle/nf-carafe-ai-ms -c pipeline.config

The entire workflow will be run automatically, downloading Docker images as necessary, and the results output to
the ``results`` directory. See :doc:`how_to_install` for more details on how to install Nextflow and Docker. See
:doc:`how_to_run` for more details on how to run the workflow. And see :doc:`results` for more details on how to
retrieve the results.


Workflow Components
===================
The workflow is made up of the following software components, each may be run multiple times for different tasks.

*  **PanoramaWeb** (https://panoramaweb.org/home/project-begin.view)

   Users may optionally use WebDAV URLs as locations for input data files in PanoramaWeb. The workflow will automatically download files as necessary.

*  **msconvert** (https://proteowizard.sourceforge.io/)

   If users supply RAW files as input, they will be converted to mzML using *msconvert*.

*  **DIA-NN** (https://github.com/vdemichev/DiaNN)

   DIA-NN (1.8.1) is used to generate data as input to Carafe.

*  **Carafe** (https://github.com/Noble-Lab/Carafe)

   Carafe uses AI to generate an enhanced spectral library for the supplied FASTA.
