# Makefile to run the pipeline
SHELL:=/bin/bash
REFDIR:=/ifs/data/sequence/results/external/NYU/snuderllab/ref
ANNOVAR_DB_DIR:=/ifs/data/molecpathlab/bin/annovar/db/hg19
ANNOVAR_PROTOCOL:=$(shell head -1 annovar_protocol.txt)
ANNOVAR_BUILD_VERSION:=hg19
EP:=
.PHONY: containers

# no default action
none:

# ~~~~~ SETUP PIPELINE ~~~~~ #
./nextflow:
	curl -fsSL get.nextflow.io | bash

install: ./nextflow

bin/multiqc-venv/bin/activate:
	cd bin && \
	make -f multiqc.makefile setup

ref:
	[ -d "$(REFDIR)" ] && ln -fs $(REFDIR) ref || { wget https://genome.med.nyu.edu/results/external/NYU/snuderllab/ref.tar.gz && \
	tar -vxzf ref.tar.gz && \
	rm -f ref.tar.gz ; }

ref-clean:
	rm -f ref.tar.gz*

setup: install ref bin/multiqc-venv/bin/activate

containers:
	cd containers && make build

# demo pipeline dataset for testing
NGS580-demo-data:
	git clone https://github.com/NYU-Molecular-Pathology/NGS580-demo-data.git

samples.analysis.tsv: NGS580-demo-data
	./generate-samplesheets.py NGS580-demo-data/tiny/fastq/ && \
	mv targets.bed targets.bed.old && \
	/bin/cp NGS580-demo-data/tiny/targets.bed .

demo: samples.analysis.tsv


annovar_db: annovar
	[ -d "$(ANNOVAR_DB_DIR)" ] && ln -fs $(ANNOVAR_DB_DIR) annovar_db || { \
	mkdir -p annovar_db && \
	export PATH="annovar:$${PATH}" && \
	for item in $$( echo "$(ANNOVAR_PROTOCOL)" | tr ',' ' '); \
	( \
	downdb_param="$$(grep "$$item" annovar_key.tsv | cut -f1)" ; \
	annotate_variation.pl -downdb -buildver $(ANNOVAR_BUILD_VERSION) -webfrom annovar "$$downdb_param" annovar_db ; \
	) ; \
	done; \
	}

annovar:
	wget http://www.openbioinformatics.org/annovar/download/0wgxR2rIVP/annovar.revision150617.tar.gz && \
	tar xvfz annovar.revision150617.tar.gz && \
	rm -f annovar.revision150617.tar.gz

clean-annovar:
	[ -d annovar_db ] && /bin/mv annovar_db annovar_dbold && rm -rf annovar_dbold &
	[ -d annovar ] && /bin/mv annovar annovarold && rm -rf annovarold &

# ~~~~~ RUN PIPELINE ~~~~~ #
# run on phoenix default settings
run: setup ref
	./nextflow run main.nf  -with-dag flowchart-NGS580.dot $(EP) && \
	[ -f flowchart-NGS580.dot ] && dot flowchart-NGS580.dot -Tpng -o flowchart-NGS580.png

# run on phoenix resume
runr: setup ref
	./nextflow run main.nf -resume -with-dag flowchart-NGS580.dot $(EP) && \
	[ -f flowchart-NGS580.dot ] && dot flowchart-NGS580.dot -Tpng -o flowchart-NGS580.png

# run on phoenix demo
rundp: setup ref demo
	./nextflow run test.nf -with-dag flowchart-NGS580.dot $(EP) && \
	[ -f flowchart-NGS580.dot ] && dot flowchart-NGS580.dot -Tpng -o flowchart-NGS580.png

rundpr: setup ref demo
	./nextflow run test.nf -resume -with-dag flowchart-NGS580.dot $(EP) && \
	[ -f flowchart-NGS580.dot ] && dot flowchart-NGS580.dot -Tpng -o flowchart-NGS580.png

# run on phoenix demo head node
rundph: setup ref demo
	./nextflow run test.nf -profile headnode -with-dag flowchart-NGS580.dot $(EP) && \
	[ -f flowchart-NGS580.dot ] && dot flowchart-NGS580.dot -Tpng -o flowchart-NGS580.png


# run locally default settings
runl: install ref
	./nextflow run test.nf -profile local -with-dag flowchart-NGS580.dot $(EP) && \
	[ -f flowchart-NGS580.dot ] && dot flowchart-NGS580.dot -Tpng -o flowchart-NGS580.png

# run locally resume
runlr: install ref
	./nextflow run test.nf -profile local -resume -with-dag flowchart-NGS580.dot $(EP) && \
	[ -f flowchart-NGS580.dot ] && dot flowchart-NGS580.dot -Tpng -o flowchart-NGS580.png


# ~~~~~ CLEANUP ~~~~~ #
clean-traces:
	rm -f trace*.txt.*

clean-logs:
	rm -f .nextflow.log.*

clean-reports:
	rm -f *.html.*

clean-flowcharts:
	rm -f *.dot.*

clean-output:
	[ -d output ] && mv output oldoutput && rm -rf oldoutput &

clean-work:
	[ -d work ] && mv work oldwork && rm -rf oldwork &

clean: clean-logs clean-traces clean-reports clean-flowcharts

clean-all: clean clean-output clean-work
	[ -d .nextflow ] && mv .nextflow .nextflowold && rm -rf .nextflowold &
	rm -f .nextflow.log
	rm -f *.png
	rm -f trace*.txt*
	rm -f *.html*
