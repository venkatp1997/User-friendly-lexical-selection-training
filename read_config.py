from pykwalify.core import Core
import yaml

def validate(config,schema):
    c = Core(source_file=config, schema_files=[schema])
    c.validate(raise_exception=True)
def read_var(config):
    with open(config, 'r') as ymlfile:
        cfg=yaml.load(ymlfile)
        return cfg
