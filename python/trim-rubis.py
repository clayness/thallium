#!/usr/bin/env python3

import sys
import os
import re
import ruamel.yaml

results_dir = os.getenv("RESULTS_DIR", "../results/latest")
weights     = os.getenv("W")

yaml = ruamel.yaml.YAML(typ="safe")
yaml.default_flow_style = False

# represents the incoming yaml nodes from the reachability
# matrix, with some adjustments to match the bounds
class ReachConfigIn:
    yaml_tag = u'!reach.ConfigRubis'

    def __init__(self, node):
        self._node = node
        self.d = 1 + int(node[2][1].value)
        self.p = 1 + int(node[0][1].value)
        self.s = 1 + int(node[3][1].value)

    def key(self):
        return "%d%d%d" % (self.s, self.d, self.p)

    @classmethod
    def from_yaml(cls, loader, node):
        return ReachConfigIn(node.value)

    @classmethod
    def to_yaml(cls, dumper, data):
        return dumper.represent_yaml_object(cls.yaml_tag, ReachConfigOut(data, data._node), cls)

# represents the unaltered yaml nodes for the reachability
# for the purpose of printing out the "in" nodes we 
# actually use
class ReachConfigOut:
    def __init__(self, data, node):
        self.addServerProgress = int(node[0][1].value) 
        self.coldCache = (node[1][1].value == "true")
        self.d = int(node[2][1].value)
        self.s = int(node[3][1].value)

# register the "in" class with the reader
yaml.register_class(ReachConfigIn)

# reads the nodes and edges of the reachability graph
# from the yaml file output by reach.sh
def loadReachability():
    with open("%s/reach/rubis.yaml" % results_dir, 'r') as f:
        docs = yaml.load_all(f)
        return next(docs), next(docs)

def check(base,child):
    pattern = "%2d,%2d,%2d -> %2d,%2d,%2d .* : \\+" % (base.s,2-(base.p-1),base.d-1,child.s,2-(child.p-1),child.d-1)
    with open("%s/trim%s/trimmed.txt" % (results_dir,weights), 'r') as f:
        for line in f:
            if re.match(pattern, line):
                return True
        return False
        

# load the nodes from the reachability graph from the Alloy/reach output
configs, old_graph = loadReachability()
new_graph = {}
num_old = 0
num_new = 0
for n in old_graph:
    # generate a new reachability graph from all the transitions whose 
    # upper bounds exceed the threshold
    new_graph[n] = {x: old_graph[n][x] for x in old_graph[n] if check(configs["configs"][n],configs["configs"][x])}
    # count both the old and new transitions (for reporting purposes)
    num_old += len(old_graph[n])
    num_new += len(new_graph[n])

print("Trimmed %d of %d transitions (%f%%)" % (num_old-num_new, num_old, ((num_old-num_new)/num_old)*100.0))
subdir = "%s/trim%s" % (results_dir,weights)
if not os.path.exists(subdir):
    try:
        os.makedirs(subdir)
    except OSError as exc:
        if exc.errno != errno.EEXIST:
            raise
with open("%s/rubis.yaml" % subdir, 'w') as f:
    yaml.dump_all((configs, new_graph), f)

