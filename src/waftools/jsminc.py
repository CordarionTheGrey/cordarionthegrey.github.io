from waflib.Task    import Task
from waflib.TaskGen import before, feature

import jsmin

import taskgen_utils


class jsminc(Task):
    color = "YELLOW"

    def keyword(self):
        return "Minifying"

    def run(self):
        result = jsmin.jsmin(self.inputs[0].read(encoding="utf-8-sig"))
        for node in self.outputs:
            node.write(result, encoding="utf-8")


@feature("jsmin")
@before("process_source")
def process_jsmin(tgen):
    for source, target in zip(tgen.to_nodes(tgen.source), tgen.to_out_nodes(tgen.target)):
        tgen.create_task("jsminc", source, target)
    tgen.source = [ ]
