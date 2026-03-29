===================================
Using a Custom DIA-NN Version
===================================
This workflow includes DIA-NN version 1.8.1, which is the latest version that may be hosted
in a public cloud container registry due to licensing restrictions. However, **newer versions of DIA-NN
can be used** by building a Docker image yourself on the system where you will run the workflow.

This page walks you through the process step by step. If you have not yet installed Nextflow
and Docker, please see :doc:`how_to_install` first.

.. important::

    All commands on this page are typed in the **command line** (also called a terminal). If you
    are on Windows, this means the Ubuntu terminal in WSL2. See :doc:`how_to_install` for how to
    open a command line on your system.


Prerequisites
=============
Before you begin, ensure the following are installed and working:

- **Docker**: Required for building and running the DIA-NN container image. If Docker is not
  installed, follow the Docker install guide at https://docs.docker.com/engine/install/. If you
  are on Windows using WSL2, install Docker Desktop for Windows and enable the WSL2 integration
  (see https://docs.docker.com/desktop/features/wsl/).

  You can verify Docker is working by running:

  .. code-block:: bash

      docker run hello-world

  If you see a "Hello from Docker!" message, Docker is working correctly.

- **Nextflow**: Required for running the workflow. See :doc:`how_to_install` for installation
  instructions.


Step 1: Download the DIA-NN Release
====================================
Visit the DIA-NN releases page at https://github.com/vdemichev/DiaNN/releases and find the
version you would like to use.

Download the file whose name ends with ``-Academia.Linux.zip``. For example, for version 2.3.2
the file would be named ``DIA-NN-2.3.2-Academia.Linux.zip``.

You can download it using your web browser and then move it to your working directory, or you
can download it directly from the command line. For example:

.. code-block:: bash

    cd
    wget https://github.com/vdemichev/DiaNN/releases/download/2.3.2/DIA-NN-2.3.2-Academia.Linux.zip

.. note::

    The URL above is an example for version 2.3.2. Replace the version number in the URL
    with the version you want to use.

**Windows users:** If you downloaded the file using your web browser, you will need to copy
it into your WSL2 environment. The easiest way is to use the command line. For example, if
the file was downloaded to your Windows Downloads folder:

.. code-block:: bash

    cp /mnt/c/Users/YourUsername/Downloads/DIA-NN-2.3.2-Academia.Linux.zip ~/

Replace ``YourUsername`` with your actual Windows username.


Step 2: Unzip the Release
=========================
Unzip the downloaded file:

.. code-block:: bash

    cd
    unzip DIA-NN-2.3.2-Academia.Linux.zip

This will create a directory named something like ``diann-2.3.2``. You can verify by listing
your directories:

.. code-block:: bash

    ls -d diann-*

You should see the directory name printed.

.. note::

    If ``unzip`` is not installed, you can install it by running:

    .. code-block:: bash

        sudo apt update && sudo apt install -y unzip


Step 3: Build the Docker Image
==============================
Navigate into the unzipped directory and build the Docker image:

.. code-block:: bash

    cd ~/diann-2.3.2
    docker build --no-cache -t diann_docker .

.. important::

    Do not forget the ``.`` at the end of the ``docker build`` command. It tells Docker to
    look for the build instructions in the current directory.

This may take a few minutes. When it is finished, you should see a message that includes
``Successfully tagged diann_docker:latest``.

You can verify the image was built by running:

.. code-block:: bash

    docker images diann_docker

You should see one row listed for the ``diann_docker`` image.


Step 4: Configure the Workflow
==============================
To use your custom DIA-NN image, you need to tell the workflow to use it instead of the
default. Open your ``pipeline.config`` file (see :doc:`how_to_run` for how to find and
edit this file) and add the following line inside the ``params`` section:

.. code-block:: groovy

    params {
        // ... your other parameters ...

        images.diann = 'diann_docker'
    }

This overrides the default DIA-NN container image with the one you just built.

.. note::

    The value ``'diann_docker'`` must match the name you used in the ``docker build -t`` command
    in Step 3. If you used a different name, use that name here instead.

After saving your ``pipeline.config``, run the workflow as you normally would (see :doc:`how_to_run`).
The workflow will automatically use your custom DIA-NN version for the DIA-NN search step.


Verifying the Version
=====================
After the workflow completes, you can confirm which version of DIA-NN was used by checking
the ``versions.txt`` file in the results directory. See :doc:`results` for more information
about output files.
