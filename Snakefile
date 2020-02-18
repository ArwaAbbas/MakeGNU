###############################################################################
##Author: Arwa Abbas
##Date: December 2019
###############################################################################



##Description##

#This is testing a Snakemake workflow for implementing WhatsGNU

#Reference genomes to make a database from
GENOMES=config["genomes"]
#Sample genomes (such as from new isolates) to interrogate
QUERIES=config["queries"]

###Snakemake Rules###

##Building Database##

#Modified the WhatsGNU_get_GenBank_genomes.py scripts so that it doesn't throw an error if the output folder already exists.
#Created a "Scripts" folder that contains the modified WhatsGNU scripts.
rule make_genome_list:
	output: 
		temp("Data/genome_list.txt")
	params:
		genome_list=GENOMES
	run:
		with open(str(output),'w') as f:
			f.write('\n'.join(params.genome_list))

#Using separate conda environments for each distinct tool
rule download_genomes:
	input:
		"Data/genome_list.txt"
	output: 
		temp(expand("Data/Genomes/{genome}.fna", genome=GENOMES))
	conda:
		"Envs/WhatsGNU.yaml"
	#Have to escape the braces in the for loop or else it thinks its a Snakemake variable
	shell:
		'''
		Scripts/WhatsGNU_get_GenBank_genomes.py -c -r {input} Data/Genomes
		gunzip Data/Genomes/*.gz
		for name in `cat {input}`; do mv Data/Genomes/${{name}}*.fna Data/Genomes/${{name}}.fna; done
		'''
#Annotate genomes with prokka
#Problem with tbl2asn is still not fixed yet on Bioconda.
#As a workaround, prokka is now included in the "TestSnakemake" environment
#The newest tbl2asn was manually installed from NCBI following directions in prokka issue #453
#Eventually want to be able to specify the prokka environment separately
#Also need to clean up unused prokka files
rule annotate_genome:
	input:
		"Data/Genomes/{genome}.fna"
	params:
		dir="Results/Annotations/prokka_{genome}",
		prefix="{genome}",
		proteins="Data/ReferenceProteome/UniProt_R20291.fasta"
	#conda:
	#	"Envs/prokka.yaml"
	output:
		"Results/Annotations/prokka_{genome}/{genome}.faa",
		"Results/Annotations/prokka_{genome}/{genome}.gff"
	shell:
		'''
		prokka --kingdom Bacteria --outdir {params.dir} --cpus 2 --force --gcode 11 --proteins {params.proteins} --genus Clostridioides --species difficile --strain {params.prefix} --prefix {params.prefix} --locustag {params.prefix} {input}
		'''
#rule test_process:
#	input: 
#		expand("Results/Annotations/prokka_{genome}/{genome}.faa", genome=GENOMES)

#Separate out the files needed later
rule move_files:
	input:
		faa="Results/Annotations/prokka_{genome}/{genome}.faa",
		gff="Results/Annotations/prokka_{genome}/{genome}.gff"
	params:
		faa_dir="Results/Annotations/CDiff_faa/",
		gff_dir="Results/Annotations/CDiff_gff/"
	output:
		faa_out=temp("Results/Annotations/CDiff_faa/{genome}.faa"),
		gff_out=temp("Results/Annotations/CDiff_gff/{genome}.gff")
	shell:
		'''
		cp {input.faa} {params.faa_dir}
		cp {input.gff} {params.gff_dir}
		'''
#rule test_process:
#	input:
#		expand("Results/Annotations/CDiff_faa/{genome}.faa", genome=GENOMES),
#		expand("Results/Annotations/CDiff_gff/{genome}.gff", genome=GENOMES)

#Append strain names to files. 
#Again, had to modify the WhatsGNU_database_customizer.py so that it doesn't throw an error if output directory already exists.

rule customize_database:
	input:
		faa="Results/Annotations/CDiff_faa/{genome}.faa",
		gff="Results/Annotations/CDiff_gff/{genome}.gff",
		#The only difference in these lists is the "filename" column to specify either the "faa" or "gff" file.
		faa_list="Data/strain_name_list_faa.csv",
		gff_list="Data/strain_name_list_gff.csv"
	params:
		faa_dir="Results/Annotations/CDiff_faa/",
		gff_dir="Results/Annotations/CDiff_gff/",
		faa_prefix="CDiff_modified_faa",
		gff_prefix="CDiff_modified_gff"
	output:
		faa_out=temp("Results/Annotations/CDiff_modified_faa/{genome}_modified.faa"),
		gff_out="Results/Annotations/CDiff_modified_gff/{genome}_modified.gff"
	conda:
		"Envs/WhatsGNU.yaml"	
	#The script puts the modified folder/files adjacent to the input directory.
	shell:
		'''
		Scripts/WhatsGNU_database_customizer.py -p -i -l {input.faa_list} {params.faa_prefix} {params.faa_dir}
		Scripts/WhatsGNU_database_customizer.py -s -i -l {input.gff_list} {params.gff_prefix} {params.gff_dir}
		'''
#This rule to run all the pre-processing steps before creating either a basic or ortholog report:
rule all_preprocess:
	input:
		expand("Results/Annotations/CDiff_modified_faa/{genome}_modified.faa", genome=GENOMES),
		expand("Results/Annotations/CDiff_modified_gff/{genome}_modified.gff", genome=GENOMES)


###Basic Report####

rule combine_files:
	input:
		faa=expand("Results/Annotations/CDiff_modified_faa/{genome}_modified.faa", genome=GENOMES)
	output:
		faa_out="Results/Annotations/CDiff_modified_faa/CDiff_all_modified.faa"
	shell:
		'''
		cat {input.faa} > {output.faa_out}
		'''

#There is no option to "just" make the database without querying it as well.
rule make_basic_report:
	input:
		proteins="Results/Annotations/CDiff_modified_faa/CDiff_all_modified.faa",
		query="Data/Query_faa/{query}.faa"
	output:
		"Results/WhatsGNU_basic_results/{query}_WhatsGNU_report.txt"
	params:
		dir="Results/WhatsGNU_basic_results",
		prefix="CDiff_basic_compressed"
	conda:
		"Envs/WhatsGNU.yaml"
	shell:
		'''
		WhatsGNU_main.py -m {input.proteins} -o {params.dir} --force -p {params.prefix} {input.query}
		'''
rule all_basic:
	input:
		expand("Results/WhatsGNU_basic_results/{query}_WhatsGNU_report.txt", query=QUERIES)
		
###Ortholog Report###
#Roary also will not overwrite an existing directory so have to do some workarounds to organize and clean up
rule analyze_pangenome:
	input:
		expand("Results/Annotations/CDiff_modified_gff/{genome}_modified.gff", genome=GENOMES)
	#For some reason, these files are still around even though they've been temp'd
	output:
		clusters="clustered_proteins",
		ach=temp("accessory.header.embl"),
		ac=temp("accessory.tab"),
		acbg=temp("accessory_binary_genes.fa"),
		acgraph=temp("accessory_graph.dot"),
		bi=temp("blast_identity_frequency.Rtab"),
		corac=temp("core_accessory.header.embl"),
		cor=temp("core_accessory.tab"),
		corgraph=temp("core_accessory_graph.dot"),
		gpa=temp("gene_presence_absence.Rtab"),
		genes="gene_presence_absence.csv",
		ngenes=temp("number_of_conserved_genes.Rtab"),
		npan=temp("number_of_genes_in_pan_genome.Rtab"),
		nnew=temp("number_of_new_genes.Rtab"),
		nunique=temp("number_of_unique_genes.Rtab"),
		summary="summary_statistics.txt"		
	conda:
		"Envs/roary.yaml"
	shell:
		'''
		roary {input}
		'''
rule make_ortholog_report:
	input:
		clusters="clustered_proteins",
		proteins="Results/Annotations/CDiff_modified_faa/CDiff_all_modified.faa",
                query="Data/Query_faa/{query}.faa"
	params:
		dir="Results/WhatsGNU_ortholog_results",
		prefix="CDiff_ortholog_compressed"
	output:
		"Results/WhatsGNU_ortholog_results/{query}_WhatsGNU_report.txt"
	conda:
		"Envs/WhatsGNU.yaml"
	shell:
		'''
		WhatsGNU_main.py -m {input.proteins} -o {params.dir} -r {input.clusters} --force -p {params.prefix} {input.query}
		'''
rule all_ortholog:
       input:
               expand("Results/WhatsGNU_ortholog_results/{query}_WhatsGNU_report.txt", query=QUERIES)
		
