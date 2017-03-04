from pykwalify.core import Core
import yaml

c = Core(source_file="config.yaml", schema_files=["schema.yaml"])
c.validate(raise_exception=True)

with open("config.yaml", 'r') as ymlfile:
    cfg = yaml.load(ymlfile)

print cfg['training']['corpus']
print cfg['learning']['mle_crisphold']
