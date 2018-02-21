import subprocess

from waflib.Task    import Task
from waflib.TaskGen import before, feature

import taskgen_utils


def configure(cnf):
    cnf.find_program("elm-make", var="ELM")


class elm(Task):
    color = "GREEN"
    run_str = "${ELM} ${ELM_FLAGS} ${SRC[0].abspath()} --output ${TGT}"
    stdout = subprocess.DEVNULL

    def keyword(self):
        return "Compiling"

    def __str__(self):
        return self.inputs[0].srcpath()


@feature("elm")
@before("process_source")
def process_elm(tgen):
    for source, target in zip(tgen.to_nodes(tgen.source), tgen.to_out_nodes(tgen.target)):
        # TODO: Parse elm-package.json.
        sources = source.parent.ant_glob("**/*.elm", excl=[source.name, "elm-stuff"])
        sources.insert(0, source)
        sources.append(source.parent.find_resource("elm-package.json"))
        task = tgen.create_task("elm", sources, target)
        task.cwd = source.parent # Required for picking up a correct elm-package.json.
    tgen.source = [ ]
