===================================
Using a Custom DIA-NN Version
===================================
This workflow includes DIA-NN version 1.8.1, which is the latest version that may be hosted
in a public cloud container registry due to licensing restrictions. However, **newer versions of DIA-NN
can be used** by building a Docker image on the system where you will run the workflow.

A build script is provided that automates this process. It downloads the necessary files from
this project's GitHub repository and builds the Docker image for you.

.. note::

    These instructions only support **DIA-NN version 2.x** releases.

.. important::

    All commands on this page are typed in the **command line** (also called a terminal). If you
    are on Windows, this means the Ubuntu terminal in WSL2. See :doc:`how_to_install` for how to
    open a command line on your system.


Prerequisites
=============
Before you begin, ensure the following are installed and working on your system:

- **Docker**: Required for building and running container images.
- **Nextflow**: Required for running the workflow.
- **wget**: Used by the build script to download files. Usually pre-installed on Linux.

If you have not yet installed these, see :doc:`how_to_install` for instructions.

You can verify Docker is working by running:

.. code-block:: bash

    docker run hello-world

If you see a "Hello from Docker!" message, Docker is working correctly.


Step 1: Download the Build Script
==================================

.. code-block:: bash

    wget https://raw.githubusercontent.com/mriffle/nf-carafe-ai-ms/main/resources/diann-docker/build_diann_docker.sh


Step 2: Run the Build Script
=============================
Run the script with the DIA-NN version number you want to use. You can find available
versions at https://github.com/vdemichev/DiaNN/releases.

For example, to build DIA-NN version 2.3.2:

.. code-block:: bash

    bash build_diann_docker.sh 2.3.2

The script will download the necessary files, build the Docker image, and print instructions
when it is finished. This may take a few minutes.

.. note::

    If you see an error that the Docker image already exists, you have already built this version.
    If you want to rebuild it, run the command shown in the error message to remove the existing
    image first.

To see all available options, run:

.. code-block:: bash

    bash build_diann_docker.sh -h


Step 3: Configure the Workflow
==============================
After the script completes, it will display the exact line to add to your ``pipeline.config``
file. Open your ``pipeline.config`` (see :doc:`how_to_run` for how to find and edit this file)
and add the line to the ``params`` section. For example, if you built version 2.3.2:

.. code-block:: groovy

    params {
        images.diann = 'diann:2.3.2'

        // ... your other parameters ...
    }

After saving your ``pipeline.config``, run the workflow as you normally would (see :doc:`how_to_run`).
The workflow will automatically use your custom DIA-NN version for the DIA-NN search step.


Verifying the Version
=====================
After the workflow completes, you can confirm which version of DIA-NN was used by checking
the ``versions.txt`` file in the results directory. See :doc:`results` for more information
about output files.
