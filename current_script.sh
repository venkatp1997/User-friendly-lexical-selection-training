CORPUS="europarl-v7"
PAIR="es-en"
SL="es"
TL="en"
DATA="/home/venkat/Apertium/apertium-en-es"

LEX_TOOLS="/home/venkat/Apertium/apertium-lex-tools/"
SCRIPTS="$LEX_TOOLS/scripts"
MOSESDECODER="/home/venkat/Apertium/mosesdecoder/scripts/training"
TRAINING_LINES=1000


if [ ! -d data-$SL-$TL ]; then 
	mkdir data-$SL-$TL;
fi

# TAG CORPUS
cat "$CORPUS.$PAIR.$SL" | head -n $TRAINING_LINES | apertium -d "$DATA" $SL-$TL-tagger\
	| apertium-pretransfer > data-$SL-$TL/$CORPUS.tagged.$SL;

cat "$CORPUS.$PAIR.$TL" | head -n $TRAINING_LINES | apertium -d "$DATA" $TL-$SL-tagger\
	| apertium-pretransfer > data-$SL-$TL/$CORPUS.tagged.$TL;

N=`wc -l $CORPUS.$PAIR.$SL | cut -d ' ' -f 1`


# # # REMOVE LINES WITH NO ANALYSES
seq 1 $TRAINING_LINES > data-$SL-$TL/$CORPUS.lines
paste data-$SL-$TL/$CORPUS.lines data-$SL-$TL/$CORPUS.tagged.$SL data-$SL-$TL/$CORPUS.tagged.$TL | grep '<' \
	| cut -f1 > data-$SL-$TL/$CORPUS.lines.new
paste data-$SL-$TL/$CORPUS.lines data-$SL-$TL/$CORPUS.tagged.$SL data-$SL-$TL/$CORPUS.tagged.$TL | grep '<' \
	| cut -f2 > data-$SL-$TL/$CORPUS.tagged.$SL.new
paste data-$SL-$TL/$CORPUS.lines data-$SL-$TL/$CORPUS.tagged.$SL data-$SL-$TL/$CORPUS.tagged.$TL | grep '<' \
	| cut -f3 > data-$SL-$TL/$CORPUS.tagged.$TL.new
mv data-$SL-$TL/$CORPUS.lines.new data-$SL-$TL/$CORPUS.lines
cat data-$SL-$TL/$CORPUS.tagged.$SL.new \
	| sed 's/ /~/g' | sed 's/\$[^\^]*/$ /g' > data-$SL-$TL/$CORPUS.tagged.$SL
cat data-$SL-$TL/$CORPUS.tagged.$TL.new \
	| sed 's/ /~/g' | sed 's/\$[^\^]*/$ /g' > data-$SL-$TL/$CORPUS.tagged.$TL
rm data-$SL-$TL/*.new


# CLEAN CORPUS
perl "$MOSESDECODER/clean-corpus-n.perl" data-$SL-$TL/$CORPUS.tagged $SL $TL "data-$SL-$TL/$CORPUS.tag-clean" 1 40;

BIN_DIR="/home/venkat/Apertium/mgiza/mgizapp/bin"
# *Absolute path* to the lm that you created with IRSTLM:
LM=/home/venkat/Apertium/lm/train.lm

# ALIGN
PYTHONIOENCODING=utf-8 perl $MOSESDECODER/train-model.perl \
  -external-bin-dir "$BIN_DIR" \
  -corpus data-$SL-$TL/$CORPUS.tag-clean \
  -f $TL -e $SL \
  -alignment grow-diag-final-and -reordering msd-bidirectional-fe \
  -lm 0:5:${LM}:0 2>&1 \
  -mgiza

# (if you use mgiza, add the -mgiza argument)
# EXTRACT
zcat giza.$SL-$TL/$SL-$TL.A3.final.gz | $SCRIPTS/giza-to-moses.awk > data-$SL-$TL/$CORPUS.phrasetable.$SL-$TL

# TRIM TAGS
cat data-$SL-$TL/$CORPUS.phrasetable.$SL-$TL | sed 's/ ||| /\t/g' | cut -f 1 \
	| sed 's/~/ /g' | $SCRIPTS/process-tagger-output $DATA/$TL-$SL.autobil.bin -p -t > tmp1

cat data-$SL-$TL/$CORPUS.phrasetable.$SL-$TL | sed 's/ ||| /\t/g' | cut -f 2 \
	| sed 's/~/ /g' | $SCRIPTS/process-tagger-output $DATA/$SL-$TL.autobil.bin -p -t > tmp2

cat data-$SL-$TL/$CORPUS.phrasetable.$SL-$TL | sed 's/ ||| /\t/g' | cut -f 3 > tmp3

cat data-$SL-$TL/$CORPUS.phrasetable.$SL-$TL | sed 's/ ||| /\t/g' | cut -f 2 \
	| sed 's/~/ /g' | $SCRIPTS/process-tagger-output $DATA/$SL-$TL.autobil.bin -b -t > data-$SL-$TL/$CORPUS.clean-biltrans.$PAIR

paste tmp1 tmp2 tmp3 | sed 's/\t/ ||| /g' > data-$SL-$TL/$CORPUS.phrasetable.$SL-$TL
rm tmp1 tmp2 tmp3

# SENTENCES
python3 $SCRIPTS/extract-sentences.py data-$SL-$TL/$CORPUS.phrasetable.$SL-$TL data-$SL-$TL/$CORPUS.clean-biltrans.$PAIR \
  > data-$SL-$TL/$CORPUS.candidates.$SL-$TL 2>/dev/null

# FREQUENCY LEXICON
python $SCRIPTS/extract-freq-lexicon.py data-$SL-$TL/$CORPUS.candidates.$SL-$TL > data-$SL-$TL/$CORPUS.lex.$SL-$TL 2>/dev/null
