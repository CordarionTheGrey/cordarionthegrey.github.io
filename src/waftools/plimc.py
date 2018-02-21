from waflib.Task    import Task
from waflib.TaskGen import before, feature

import plim

import taskgen_utils


class plimc(Task):
    color = "BLUE"

    def run(self):
        result = plim.compile_plim_source(
            self.inputs[0].read(encoding="utf-8-sig"),
            getattr(plim.syntax, self.syntax)(),
        )
        for node in self.outputs:
            node.write(result, encoding="utf-8")

    # TODO: sig_deps


@feature("plim")
@before("process_source")
def process_plim(tgen):
    syntax = getattr(tgen, "syntax", "Mako")
    for source, target in zip(tgen.to_nodes(tgen.source), tgen.to_out_nodes(tgen.target)):
        task = tgen.create_task("plimc", source, target)
        task.syntax = syntax
    tgen.source = [ ]
