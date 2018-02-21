from waflib.Task    import Task
from waflib.TaskGen import before, feature

import sass

import taskgen_utils


class sassc(Task):
    color = "CYAN"

    def run(self):
        self.outputs[0].write(
            sass.compile(filename=self.inputs[0].abspath(), **self.options),
            encoding="utf-8",
        )

    # TODO: sig_deps


@feature("sass")
@before("process_source")
def process_sass(tgen):
    options = getattr(tgen, "options", { })
    for source, target in zip(tgen.to_nodes(tgen.source), tgen.to_out_nodes(tgen.target)):
        task = tgen.create_task("sassc", source, target)
        task.options = options
    tgen.source = [ ]
