import os 
import subprocess
import sys
import read_config
import shlex
import glob

def main():
    if (len(sys.argv))!=3:
        print ("Please provide exactly two arguments: path to the config file & path to the schema file")
        sys.exit()
    config=sys.argv[1]
    schema=sys.argv[2]
    if(os.path.exists(config)==False):
        print ("Config file provided doesn't exist.")
        sys.exit()
    if(os.path.exists(schema)==False):
        print ("Schema file provided doesn't exist.")
        sys.exit()
    read_config.validate(config,schema)
    cfg=read_config.read_var(config)

    #Reading Variables from Config
    corpus=cfg["training"]["corpus"]
    pair=cfg["training"]["pair"]
    sl=cfg["training"]["sl"]
    tl=cfg["training"]["tl"]
    data=cfg["training"]["data"]
    lex_tools=cfg["training"]["lex_tools"]
    scripts=cfg["training"]["scripts"]
    mosesdecoder=cfg["training"]["mosesdecoder"]
    lines=cfg["training"]["lines"]

    bin_dir=cfg["learning"]["bin_dir"]
    lm=cfg["learning"]["lm"]

    if os.path.isdir("./data-"+cfg["training"]["sl"]+"-"+cfg["training"]["tl"])==False:
        execute_commands(["mkdir data-{0}-{1}".format(sl,tl)])
    #Tag Corpus
    execute_commands("cat {0}.{1}.{2} | head -n {5} | apertium -d {4} {2}-{3}-tagger | apertium-pretransfer".format(corpus,pair,sl,tl,data,lines).split('|'),"data-{2}-{3}/{0}.tagged.{2}".format(corpus,pair,sl,tl,data,lines))
    execute_commands("cat {0}.{1}.{3} | head -n {5} | apertium -d {4} {3}-{2}-tagger | apertium-pretransfer".format(corpus,pair,sl,tl,data,lines).split('|'),"data-{2}-{3}/{0}.tagged.{3}".format(corpus,pair,sl,tl,data,lines))
    execute_commands("seq 1 {3}".format(corpus,sl,tl,lines).split('|'),"data-{1}-{2}/{0}.lines".format(corpus,sl,tl,lines))
    execute_commands("paste data-{1}-{2}/{0}.lines data-{1}-{2}/{0}.tagged.{1} data-{1}-{2}/{0}.tagged.{2} | grep '<' | cut -f1".format(corpus,sl,tl).split('|'),"data-{1}-{2}/{0}.lines.new".format(corpus,sl,tl))
    execute_commands("paste data-{1}-{2}/{0}.lines data-{1}-{2}/{0}.tagged.{1} data-{1}-{2}/{0}.tagged.{2} | grep '<' | cut -f2".format(corpus,sl,tl).split('|'),"data-{1}-{2}/{0}.tagged.{1}.new".format(corpus,sl,tl))
    execute_commands("paste data-{1}-{2}/{0}.lines data-{1}-{2}/{0}.tagged.{1} data-{1}-{2}/{0}.tagged.{2} | grep '<' | cut -f3".format(corpus,sl,tl).split('|'),"data-{1}-{2}/{0}.tagged.{2}.new".format(corpus,sl,tl))
    execute_commands("mv data-{1}-{2}/{0}.lines.new data-{1}-{2}/{0}.lines".format(corpus,sl,tl).split('|'))
    execute_commands("cat data-{1}-{2}/{0}.tagged.{1}.new | sed 's/ /~/g' | sed 's/\$[^\^]*/$ /g'".format(corpus,sl,tl).split('|'),"data-{1}-{2}/{0}.tagged.{1}".format(corpus,sl,tl))
    execute_commands("cat data-{1}-{2}/{0}.tagged.{2}.new | sed 's/ /~/g' | sed 's/\$[^\^]*/$ /g'".format(corpus,sl,tl).split('|'),"data-{1}-{2}/{0}.tagged.{2}".format(corpus,sl,tl))
    files_to_delete=glob.glob("data-{0}-{1}/*.new".format(sl,tl))
    for i in files_to_delete: os.remove(i)

    #Clean Corpus
    execute_commands("perl {3}/clean-corpus-n.perl data-{1}-{2}/{0}.tagged {1} {2} data-{1}-{2}/{0}.tag-clean 1 40".format(corpus,sl,tl,mosesdecoder).split('|'))

    #Align
    os.system("export PYTHONIOENCODING=utf-8")
    execute_commands("perl {3}/train-model.perl -external-bin-dir {4} -corpus data-{1}-{2}/{0}.tag-clean -f {2} -e {1} -alignment grow-diag-final-and -reordering msd-bidirectional-fe -lm 0:5:{5}:0 -mgiza".format(corpus,sl,tl,mosesdecoder,bin_dir,lm).split('|'),1,1)

    #Extract
    execute_commands("zcat giza.{1}-{2}/{1}-{2}.A3.final.gz | {3}/giza-to-moses.awk".format(corpus,sl,tl,scripts).split('|'),"data-{1}-{2}/{0}.phrasetable.{1}-{2}".format(corpus,sl,tl))

    #Trim Tags
    execute_commands("cat data-{1}-{2}/{0}.phrasetable.{1}-{2} | sed 's/ ||| /\t/g' | cut -f 1 | sed 's/~/ /g' | {4}/process-tagger-output {3}/$TL-$SL.autobil.bin -p -t".format(corpus,sl,tl,data,scripts).split(" | "),"tmp1")
    execute_commands("cat data-{1}-{2}/{0}.phrasetable.{1}-{2} | sed 's/ ||| /\t/g' | cut -f 2 | sed 's/~/ /g' | {4}/process-tagger-output {3}/$TL-$SL.autobil.bin -p -t".format(corpus,sl,tl,data,scripts).split(" | "),"tmp2")
    execute_commands("cat data-{1}-{2}/{0}.phrasetable.{1}-{2} | sed 's/ ||| /\t/g' | cut -f 3".format(corpus,sl,tl).split(" | "),"tmp3")
    execute_commands("cat data-{1}-{2}/{0}.phrasetable.{1}-{2} | sed 's/ ||| /\t/g' | cut -f 2 | sed 's/~/ /g' | {4}/process-tagger-output {3}/$TL-$SL.autobil.bin -b -t".format(corpus,sl,tl,data,scripts).split(" | "),"data-{2}-{3}/{0}.clean-biltrans.{1}".format(corpus,pair,sl,tl))
    execute_commands("paste tmp1 tmp2 tmp3 | sed 's/\t/ ||| /g'".split(" | "),"data-{1}-{2}/{0}.phrasetable.{1}-{2}".format(corpus,sl,tl))
    execute_commands("rm tmp1 tmp2 tmp3".split('|'))

    #Sentences
    execute_commands("python3 {4}/extract-sentences.py data-{2}-{3}/{0}.phrasetable.{2}-{3} data-{2}-{3}/{0}.clean-biltrans.{1}".format(corpus,pair,sl,tl,scripts).split('|'),"data-{1}-{2}/{0}.candidates.{1}-{2}".format(corpus,sl,tl),"/dev/null")

    #Frequency Lexicon
    execute_commands("python {3}/extract-freq-lexicon.py data-{1}-{2}/{0}.candidates.{1}-{2}".format(corpus,sl,tl,scripts).split('|'),"data-{1}-{2}/{0}.lex.{1}-{2}".format(corpus,sl,tl),"/dev/null")

def execute_commands(commands,stdout_arg=1,stderr_arg=2):
    """
    1) Executes piped commands. 
    2) Also takes arguments as to where to print the stdout and the stderr of the commands executed. 
    """
    list_of_commands=[]
    for i in range(len(commands)):
        stdin=0
        stdout=subprocess.PIPE
        stderr=2
        command=shlex.split(commands[i].strip())
        if i!=0:
            stdin=list_of_commands[i-1].stdout
        if i==(len(commands)-1):
            if type(stdout_arg)==str: stdout=open(stdout_arg,"w")
            else: stdout=stdout_arg
            if type(stderr_arg)==str: stderr=open(stderr_arg,"w")
            else: stderr=stderr_arg
        list_of_commands.append(subprocess.Popen(command,stdin=stdin,stdout=stdout,stderr=stderr))
    list_of_commands[len(commands)-1].communicate()

if __name__=='__main__':
    main()
