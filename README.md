# MakeGNU
Snakemake pipeline for implementing WhatsGNU
This workflow allows for downloading of microbial genome sequences, annotation with [prokka](https://github.com/tseemann/prokka), pangenome analysis with [Roary](https://github.com/sanger-pathogens/Roary) and investigation of proteomic novelty with [WhatsGNU](https://github.com/ahmedmagds/WhatsGNU)

## Set Up

### Installing the pipeline

    git clone https://github.com/ArwaAbbas/MakeGNU

### Creating the environment

For most of the tools used in the pipeline, a separate conda environment is created when the rule runs. However, because of [this issue](https://github.com/tseemann/prokka/issues/453) in prokka, a little bit of finagling is necessary at the moment. First, we'll create the base snakemake environment:

    conda create -c bioconda -c conda-forge -n EnvironmentName snakemake
    conda activate EnvironmentName
    
Then we'll add prokka to the base environment and manually replace the outdated script. 

    conda install -c conda-forge -c bioconda -c defaults prokka=1.14.5
    wget ftp://ftp.ncbi.nih.gov/toolbox/ncbi_tools/converters/by_program/tbl2asn/linux64.tbl2asn.gz -O linux64.tbl2asn.gz 
    gunzip linux64.tbl2asn.gz
    mv linux64.tbl2asn ~/miniconda3/envs/EnvironmentName/bin/tbl2asn
    chmod +x ~/miniconda3/envs/prokka/EnvironmentName/tbl2asn

The path to the location of the script to replace may be slightly different depending on whether you're using anaconda, miniconda, conda, etc.

### Preparing inputs and configuration files

The pipeline currently needs these inputs from the user:
1. A `config.yaml` that contains a list of genomes to be downloaded and a list of queries to be analyzed.
2. Query proteome .faa files in  (file names must match those in config file)
3. Two CSV files that map names of .faa and .gff files (usually something like "GCA_#########.#.faa/gff" to a biologist-friendly strain name). See documentation in WhatsGNU for more details.
4. A reference proteome for the organism of interest
    

   
   
 

