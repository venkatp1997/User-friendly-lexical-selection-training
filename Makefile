CORPUS=europarl-v7
DIR=es-ca
DATA=/home/venkat/Apertium/apertium-es-ca/
AUTOBIL=/home/venkat/Apertium/apertium-es-ca/es-ca.autobil.bin
SCRIPTS=/home/venkat/Apertium/apertium-lex-tools/scripts
MODEL=/home/venkat/Ubuntu-14/train.blm
LEX_TOOLS=/home/venkat/Apertium/apertium-lex-tools
THR=0


#all: data/$(CORPUS).$(DIR).lrx data/$(CORPUS).$(DIR).freq.lrx
all: data/$(CORPUS).$(DIR).freq.lrx.bin data/$(CORPUS).$(DIR).patterns.lrx

data/$(CORPUS).$(DIR).tagger: $(CORPUS).$(DIR).txt
	if [ ! -d data ]; then mkdir data; fi
	cat $(CORPUS).$(DIR).txt | sed 's/[^\.]$$/./g' | apertium-destxt | apertium -f none -d $(DATA) $(DIR)-tagger | apertium-pretransfer > $@

data/$(CORPUS).$(DIR).ambig: data/$(CORPUS).$(DIR).tagger
	cat data/$(CORPUS).$(DIR).tagger | $(LEX_TOOLS)/multitrans $(DATA)$(DIR).autobil.bin -b -t > $@

data/$(CORPUS).$(DIR).multi-trimmed: data/$(CORPUS).$(DIR).tagger
	cat data/$(CORPUS).$(DIR).tagger | $(LEX_TOOLS)/multitrans $(DATA)$(DIR).autobil.bin -m -t > $@

data/$(CORPUS).$(DIR).ranked: data/$(CORPUS).$(DIR).tagger
	cat $< | $(LEX_TOOLS)/multitrans $(DATA)$(DIR).autobil.bin -m | apertium -f none -d $(DATA) $(DIR)-multi | irstlm-ranker-frac $(MODEL) > $@

data/$(CORPUS).$(DIR).annotated: data/$(CORPUS).$(DIR).multi-trimmed data/$(CORPUS).$(DIR).ranked
	paste data/$(CORPUS).$(DIR).multi-trimmed data/$(CORPUS).$(DIR).ranked | cut -f1-4 > $@

data/$(CORPUS).$(DIR).freq: data/$(CORPUS).$(DIR).ambig data/$(CORPUS).$(DIR).annotated
	python3 $(SCRIPTS)/biltrans-extract-frac-freq.py  data/$(CORPUS).$(DIR).ambig data/$(CORPUS).$(DIR).annotated > $@

data/$(CORPUS).$(DIR).freq.lrx:  data/$(CORPUS).$(DIR).freq
	python3 $(SCRIPTS)/extract-alig-lrx.py $< > $@

data/$(CORPUS).$(DIR).freq.lrx.bin: data/$(CORPUS).$(DIR).freq.lrx
	lrx-comp $< $@

data/$(CORPUS).$(DIR).ngrams: data/$(CORPUS).$(DIR).freq data/$(CORPUS).$(DIR).ambig data/$(CORPUS).$(DIR).annotated
	python3 $(SCRIPTS)/biltrans-count-patterns-ngrams.py data/$(CORPUS).$(DIR).freq data/$(CORPUS).$(DIR).ambig data/$(CORPUS).$(DIR).annotated > $@

data/$(CORPUS).$(DIR).patterns: data/$(CORPUS).$(DIR).freq data/$(CORPUS).$(DIR).ngrams
	python3 $(SCRIPTS)/ngram-pruning-frac.py data/$(CORPUS).$(DIR).freq data/$(CORPUS).$(DIR).ngrams > $@

data/$(CORPUS).$(DIR).patterns.lrx:  data/$(CORPUS).$(DIR).patterns
	python3 $(SCRIPTS)/ngrams-to-rules.py $< $(THR) > $@
