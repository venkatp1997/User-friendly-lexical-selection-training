# Prerequisites
1. Python 2.7
2. pykwalify module for python 2.7

```config.yaml``` defines a sample config file.
```schema.yaml``` defines the schema that the config file must follow. 
```read_config.py``` uses pykwalify module to detect whether the provided config file is valid by checking whether it follows the schema defined in ```schema.yaml``` and also prints some values from the config. 

