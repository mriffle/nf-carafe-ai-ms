===================================
Carafe Nextflow Documentation
===================================
This workflow is designed to go from RAW files to an AI-enhanced spectral library using
the Carafe tool for experiment-specific in silico spectral library generation for DIA data
analysis. See https://github.com/Noble-Lab/Carafe for more information.

This workflow supports starting with a RAW and FASTA file and will run msconvert and DIA-NN
to generate a peptide report for input to Carafe; or you may start with a peptide report
previously generated with DIA-NN to skip running DIA-NN. See :doc:`workflow_parameters` for
more information.

Please use the links below to navigate to pages describing how to install and run the workflow,
how to retrieve results, and how to set up AWS Batch to run the workflow in the cloud.

Getting Help, Providing Feedback, or Reporting Problems
=======================================================
If you need help, have ideas for new features, encounter a problem, or have any questions or comments, please contact Michael Riffle at mriffle@uw.edu.

Documentation Sections
=======================================================

.. toctree::
   :maxdepth: 2

   self
   overview
   how_to_install
   how_to_run
   workflow_parameters
   results
   set_up_aws

Funding & Attribution
=======================================================
This work was made possible with funding from IARPA via the TEI-REX program (Contract #: W911NF2220059). The contents of
these documents are purely technical in nature, with no opinions or perspectives of the US Goverment's interests in TEI-REX.
