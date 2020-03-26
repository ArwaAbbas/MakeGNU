# MakeGNU
Snakemake pipeline for implementing WhatsGNU.
This [Snakemake](https://snakemake.readthedocs.io/en/stable/index.html) workflow allows for downloading of microbial genome sequences, annotation with [prokka](https://github.com/tseemann/prokka), pangenome analysis with [Roary](https://github.com/sanger-pathogens/Roary) and investigation of proteomic novelty with [WhatsGNU](https://github.com/ahmedmagds/WhatsGNU).

## Set Up

### Installing the pipeline

    git clone https://github.com/ArwaAbbas/MakeGNU
    cd MakeGNU

### Creating the environment

For most of the tools used in the pipeline, a separate conda environment is created when the rule runs. These dependencies are listed in  `Envs/`. However, because of [this issue](https://github.com/tseemann/prokka/issues/453) in prokka, a little bit of finagling is necessary at the moment. First, we'll create the base snakemake environment:

    conda create -c bioconda -c conda-forge -n MakeGNU snakemake
    conda activate MakeGNU
    
Then we'll add prokka to the base environment and manually replace the outdated script. 

    conda install -c conda-forge -c bioconda -c defaults prokka=1.14.5
    wget ftp://ftp.ncbi.nih.gov/toolbox/ncbi_tools/converters/by_program/tbl2asn/linux64.tbl2asn.gz -O linux64.tbl2asn.gz 
    gunzip linux64.tbl2asn.gz
    mv linux64.tbl2asn ~/anaconda3/envs/MakeGNU/bin/tbl2asn
    chmod +x ~/anaconda3/envs/MakeGNU/bin/tbl2asn

The path to the location of the script to replace may be slightly different depending on whether you're using anaconda, miniconda, conda, etc.

### Preparing inputs and configuration files

The pipeline currently needs these inputs from the user:
1. A `config.yaml` that contains some fields the user will modify to run.
2. Query proteome ".faa" files. The names of the queries will be specified in the config folder. If the user is beginning with the nucleotide sequence of a whole genome assembly (see below), they can optionally use prokka to annotate the genome and create the ".faa" files.
3. Two CSV files that map names of .faa and .gff files (usually something like "GCA_#########.#.faa/gff" to a biologist-friendly strain name). See documentation in WhatsGNU for more details.
4. A reference proteome for the organism of interest. Currently this is REQUIRED for MakeGNU to run.
    
## A Working Example Using the Test Data

This is how the directory looks like prior to running any rules:

* Data
    * Query_fna (contains microbial genomes)
    * ReferenceProteome (contains the reference proteome from a bacterial strain)
    * Dummy_query (contains a small faa file used to help create the WhatsGNU database)
    * strain_name_list_faa.csv
    * strain_name_list_gff.csv

### Annotating bacterial genomes to be queried
If you are starting with nucleotide sequences, this wil use prokka to annotate the genomes and pull out the ".faa" files to be used by WhatsGNU. 

Execute the following in the MakeGNU root directory. The `-p` flag will print out the shell commands that will be executed.  To do a dry run (see the commands without running them), pass `-np` instead of `-p` and if you want to see the reason for each rule use `-r`. [Sometimes](https://snakemake.readthedocs.io/en/stable/project_info/faq.html#some-command-line-arguments-like-config-cannot-be-followed-by-rule-or-file-targets-is-that-intended-behavior), specifying the rule directly after the `--configfile` argument parser leads to errors. This README won't/can't go over every single Snakemake parameter or error you may encounter, but feel free to leave an issue.

    snakemake --configfile test_config.yaml --use-conda all_query

The directory structure should now look like this. New output is **bolded**

* Data
    * **Query_faa** (contains your proteomes to be queried)
    * **Annotations**
        **prokka_QUERY** (contains all the outputs from prokka)
    * Query_fna (contains microbial genomes)
    * ReferenceProteome
    * Dummy_query (contains a small faa file used to help create the WhatsGNU database)
    * strain_name_list_faa.csv
    * strain_name_list_gff.csv

### Downloading and annotating reference genomes

    snakemake --configfile test_config.yaml --use-conda download_genomes
    snakemake --configfile test_config.yaml unzip_genome_files
    snakemake --configfile test_config.yaml rename_genome_files
    snakemake --configfile test_config.yaml --use-conda all_database_processing

The directory structure should now look similar to this. 

* Data
    * **Genomes**
    * Query_faa
    * Query_fna
    * Annotations
    * ReferenceProteome
    * Dummy_query
    * strain_name_list_faa.csv
    * strain_name_list_gff.csv
    * **genome_list.txt**
* Results
    * **Annotations**
        * prokka_GENOMEID (contains all prokka output files)
        * **all_modified_faa**
        * **all_modified_gff**

Once the reference database has been built, and you have additional genomes to analyze, these database processing steps do not need to be rerun.

### Creating a basic report
    
    snakemake --configfile test_config.yaml --use-conda all_basic
    
### Creating an ortholog report

    snakemake --configfile test_config.yaml --use-conda analyze_pangenome
    snakemake --configfile test_config.yaml --use-conda roary_cleanup
    
Once the pangenome analysis has been done on the reference genomes, and you have additional query genomes to analyze, the above steps do not need to be rerun.

    snakemake --configfile test_config.yaml --use-conda all_ortholog
  
  Final directory structure should look like this:
  
  * Data
    * Genomes
    * Query_faa
    * Query_fna
    * Annotations
    * ReferenceProteome
    * Dummy_query
* Results
    * Annotations
        * prokka_GENOMEID 
        * all_modified_faa
        * all_modified_gff
    * **Roary**
    * **WhatsGNU_db**
    * **WhatsGNU_basic_results**
    * **WhatsGNU_ortholog_results**
 
    
    


 
  
   
 

