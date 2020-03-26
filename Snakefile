###############################################################################
##Author: Arwa Abbas
##Date: December 2019
###############################################################################


##Description##

#This is a Snakemake workflow for implementing WhatsGNU

#Reference genomes to make a database from
GENOMES=config["genomes"]
#Sample genomes (such as from new isolates) to interrogate
QUERIES=config["queries"]

#File paths
OUTPUT_DIR=str(config["output"])
DATA_DIR=str(config["data"])

#Location of specific files
REFERENCE=config["reference"]

#Details for annotating with prokka
GENUS=config["genus"]
SPECIES=config["species"]

###Snakemake Rules###


##Annotating Query Genomes##
rule annotate_queries:
	input:
		str(DATA_DIR+"/Query_fna/{query}.fna")
	params:
		dir=str(DATA_DIR+"/Annotations/prokka_{query}"),
		prefix="{query}",
		proteins=str(REFERENCE),
		refgenus=str(GENUS),
		refspecies=str(SPECIES)
	output:
		str(DATA_DIR+"/Annotations/prokka_{query}/{query}.faa")
	threads: 2
	shell:
		'''
		prokka --kingdom Bacteria --outdir {params.dir} --cpus {threads} --force --gcode 11 --proteins {params.proteins} --genus {params.refgenus} --species {params.refspecies} --strain {params.prefix} --prefix {params.prefix} --locustag {params.prefix} {input}
		'''

rule move_query_faa:
	input:
		str(DATA_DIR+"/Annotations/prokka_{query}/{query}.faa")
	output:
		str(DATA_DIR+"/Query_faa/{query}.faa")
	shell:
		'''
		cp {input} {output}
		'''

rule all_query:
	input:
		expand(str(DATA_DIR+"/Query_faa/{query}.faa"), query=QUERIES)

##Building Database##
rule make_genome_list:
	output: 
		str(DATA_DIR+"/genome_list.txt")
	params:
		genome_list=GENOMES
	run:
		with open(str(output),'w') as f:
			f.write('\n'.join(params.genome_list))

#This uses a modified WhatsGNU_get_GenBank_genomes.py script so that it doesn't throw an error if the output folder already exists.

rule download_genomes:
	input:
		str(DATA_DIR+"/genome_list.txt")
	params: 
		str(DATA_DIR+"/Genomes/")
	conda:
		"Envs/WhatsGNU.yaml"
	shell:
		'''
		Scripts/WhatsGNU_get_GenBank_genomes.py -c -r {input} {params}
		'''

rule unzip_genome_files:
	params:
		str(DATA_DIR+"/Genomes/*.gz")
	shell:
		'''
		gunzip {params}
		'''

rule rename_genome_files:
	params: 
		dir=str(DATA_DIR+"/Genomes/"),
                names=str(DATA_DIR+"/genome_list.txt")
	shell:
		'''
		bash Scripts/modify_filenames.sh {params.names} {params.dir}
		'''
#Annotate genomes with prokka
rule annotate_genome:
	input:
		str(DATA_DIR+"/Genomes/{genome}.fna")
	params:
		dir=str(OUTPUT_DIR+"/Annotations/prokka_{genome}"),
		prefix="{genome}",
		proteins=str(REFERENCE),
		refgenus=str(GENUS),
		refspecies=str(SPECIES)
	threads: 2
	output:
                str(OUTPUT_DIR+"/Annotations/prokka_{genome}/{genome}.faa"),
                str(OUTPUT_DIR+"/Annotations/prokka_{genome}/{genome}.gff")
	shell:
		'''
		prokka --kingdom Bacteria --outdir {params.dir} --cpus {threads} --force --gcode 11 --proteins {params.proteins} --genus {params.refgenus} --species {params.refspecies} --strain {params.prefix} --prefix {params.prefix} --locustag {params.prefix} {input}
		'''

#Separate out the files needed for WhatsGNU
rule move_files:
	input:
		faa=str(OUTPUT_DIR+"/Annotations/prokka_{genome}/{genome}.faa"),
                gff=str(OUTPUT_DIR+"/Annotations/prokka_{genome}/{genome}.gff")
	params:
		faa_dir=str(OUTPUT_DIR+"/Annotations/all_faa/"),
                gff_dir=str(OUTPUT_DIR+"/Annotations/all_gff/")		
	output:
		faa_out=temp(str(OUTPUT_DIR+"/Annotations/all_faa/{genome}.faa")),
                gff_out=temp(str(OUTPUT_DIR+"/Annotations/all_gff/{genome}.gff"))
	shell:
		'''
		cp {input.faa} {params.faa_dir}
		cp {input.gff} {params.gff_dir}
		'''

#This uses a modified WhatsGNU_database_customizer.py so that it doesn't throw an error if output directory already exists.
#The only difference in these lists is the "filename" column to specify either the "faa" or "gff" file.

rule customize_database:
	input:
		faa_out=str(OUTPUT_DIR+"/Annotations/all_faa/{genome}.faa"),
                gff_out=str(OUTPUT_DIR+"/Annotations/all_gff/{genome}.gff"),
		faa_list=str(DATA_DIR+"/strain_name_list_faa.csv"),
                gff_list=str(DATA_DIR+"/strain_name_list_gff.csv")
	params:
		faa_dir=str(OUTPUT_DIR+"/Annotations/all_faa/"),
		gff_dir=str(OUTPUT_DIR+"/Annotations/all_gff/"),
		faa_prefix="all_modified_faa",
		gff_prefix="all_modified_gff"
	output:
		faa_out=temp(str(OUTPUT_DIR+"/Annotations/all_modified_faa/{genome}_modified.faa")),
                gff_out=str(OUTPUT_DIR+"/Annotations/all_modified_gff/{genome}_modified.gff")
	conda:
		"Envs/WhatsGNU.yaml"	
	#The script puts the modified folder/files adjacent to the input directory.
	shell:
		'''
		Scripts/WhatsGNU_database_customizer.py -p -i -l {input.faa_list} {params.faa_prefix} {params.faa_dir}
		Scripts/WhatsGNU_database_customizer.py -s -i -l {input.gff_list} {params.gff_prefix} {params.gff_dir}
		'''
#This rule runs all the pre-processing steps before creating either a basic or ortholog report:
rule all_database_processing:
	input:
		expand(str(OUTPUT_DIR+"/Annotations/all_modified_faa/{genome}_modified.faa"), genome=GENOMES),
                expand(str(OUTPUT_DIR+"/Annotations/all_modified_gff/{genome}_modified.gff"), genome=GENOMES)


###Basic Report####
rule combine_files:
	input:
		expand(str(OUTPUT_DIR+"/Annotations/all_modified_faa/{genome}_modified.faa"), genome=GENOMES)
	output:
		str(OUTPUT_DIR+"/Annotations/all_modified_faa/all_modified.faa")
	shell:
		'''
		cat {input} > {output}
		'''

##There is no option to "just" make the database without querying it as well, so using a dummy protein file to first create the database.
rule make_basic_db:
	input:
		proteins=str(OUTPUT_DIR+"/Annotations/all_modified_faa/all_modified.faa"),
		dummy_query=str(DATA_DIR+"/Dummy_query/dummy_query.faa")
	output:
		str(OUTPUT_DIR+"/WhatsGNU_db/basic_compressed.txt")
	params:
		dir=str(OUTPUT_DIR+"/WhatsGNU_basic_results"),
		db=str(OUTPUT_DIR+"/WhatsGNU_basic_results/basic_compressed.txt"),
		prefix="basic_compressed",
		db_dir=str(OUTPUT_DIR+"/WhatsGNU_db")
	conda:
		"Envs/WhatsGNU.yaml"
	shell:
		'''
		WhatsGNU_main.py -m {input.proteins} -o {params.dir} --force -p {params.prefix} {input.dummy_query}
		mv {params.db} {params.db_dir}
		'''
rule make_basic_report:
	input:
		q=str(DATA_DIR+"/Query_faa/{query}.faa"),
		db=str(OUTPUT_DIR+"/WhatsGNU_db/basic_compressed.txt")
	output:
		str(OUTPUT_DIR+"/WhatsGNU_basic_results/{query}_WhatsGNU_report.txt")
	params:
		dir=str(OUTPUT_DIR+"/WhatsGNU_basic_results")
	conda:
		"Envs/WhatsGNU.yaml"
	shell:
		'''
		WhatsGNU_main.py -d {input.db} -dm basic -o {params.dir} --force {input.q}
		'''
rule all_basic:
	input:
		expand(str(OUTPUT_DIR+"/WhatsGNU_basic_results/{query}_WhatsGNU_report.txt"), query=QUERIES)

###Ortholog Report###
#Roary also will not overwrite an existing directory so have to do some workarounds to organize and clean up
rule analyze_pangenome:
	input:
		expand(str(OUTPUT_DIR+"/Annotations/all_modified_gff/{genome}_modified.gff"), genome=GENOMES)
	output:
		"clustered_proteins"
	threads: 2
	conda:
		"Envs/roary.yaml"
	shell:
		'''
		roary -p {threads} {input}
		'''
rule roary_cleanup:
	input:
		clusters="clustered_proteins",
                ach="accessory.header.embl",
                ac="accessory.tab",
                acbg="accessory_binary_genes.fa",
                acgraph="accessory_graph.dot",
                bi="blast_identity_frequency.Rtab",
                corac="core_accessory.header.embl",
                cor="core_accessory.tab",
                corgraph="core_accessory_graph.dot",
                gpa="gene_presence_absence.Rtab",
                genes="gene_presence_absence.csv",
                ngenes="number_of_conserved_genes.Rtab",
                npan="number_of_genes_in_pan_genome.Rtab",
                nnew="number_of_new_genes.Rtab",
                nunique="number_of_unique_genes.Rtab",
                summary="summary_statistics.txt"
	params:
		str(OUTPUT_DIR+"/Roary/")
	shell:
		'''
		mkdir {params}
		mv {input.clusters} {params}
		mv {input.ach} {params}
		mv {input.ac} {params}
		mv {input.acbg} {params}
		mv {input.acgraph} {params}
		mv {input.bi} {params}
		mv {input.corac} {params}
		mv {input.cor} {params}
		mv {input.corgraph} {params}
		mv {input.gpa} {params}
		mv {input.genes} {params}
		mv {input.ngenes} {params}
		mv {input.npan} {params}
		mv {input.nnew} {params}
		mv {input.nunique} {params}
		mv {input.summary} {params}
		'''
rule make_ortholog_db:
	input: 
		clusters=str(OUTPUT_DIR+"/Roary/clustered_proteins"),
		proteins=str(OUTPUT_DIR+"/Annotations/all_modified_faa/all_modified.faa"),
                dummy_query=str(DATA_DIR+"/Dummy_query/dummy_query.faa")
	output: 
		str(OUTPUT_DIR+"/WhatsGNU_db/ortholog_compressed.txt")
	params:
		dir=str(OUTPUT_DIR+"/WhatsGNU_ortholog_results"),
		db=str(OUTPUT_DIR+"/WhatsGNU_ortholog_results/ortholog_compressed.txt"),
		prefix="ortholog_compressed",
		db_dir=str(OUTPUT_DIR+"/WhatsGNU_db")
	conda:
		"Envs/WhatsGNU.yaml"
	shell:
		'''
		WhatsGNU_main.py -m {input.proteins} -o {params.dir} -r {input.clusters} --force -p {params.prefix} {input.dummy_query}
		mv {params.db} {params.db_dir}
		'''

rule make_ortholog_report:
	input:
		q=str(DATA_DIR+"/Query_faa/{query}.faa"),
		db=str(OUTPUT_DIR+"/WhatsGNU_db/ortholog_compressed.txt")
	params:
		dir=str(OUTPUT_DIR+"/WhatsGNU_ortholog_results")
	output:
		str(OUTPUT_DIR+"/WhatsGNU_ortholog_results/{query}_WhatsGNU_report.txt")
	conda:
		"Envs/WhatsGNU.yaml"
	shell:
		'''
		WhatsGNU_main.py -d {input.db} -dm ortholog -o {params.dir} --force {input.q}
		'''
rule all_ortholog:
	input:
		expand(str(OUTPUT_DIR+"/WhatsGNU_ortholog_results/{query}_WhatsGNU_report.txt"), query=QUERIES)
		
