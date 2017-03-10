# Prerequisites
1. Python 3.5
2. pykwalify module for python 3.5
3. lttoolbox
4. Apertium
5. Apertium-Lex-Tools
6. Moses
7. Giza++
8. IRSTLM

```config.yaml```: defines a sample config file.
```schema.yaml```: defines the schema that the config file must follow. 
```read_config.py```: uses pykwalify module to detect whether the provided config file is valid by checking whether it follows the schema defined in ```schema.yaml``` and provides functions to read variables defined in config.
```execute.py``` : performs word alignment. 
```current_script.sh```: the results of ```execute.py``` are checked with this script (which is the one defined in this [link](http://wiki.apertium.org/wiki/Learning_rules_from_parallel_and_non-parallel_corpora))
