from waflib.Task    import Task
from waflib.TaskGen import before, feature

import taskgen_utils


def configure(cnf):
    cnf.find_program(["lsc", "livescript"], var="LSC")


class lsc(Task):
    run_str = "${LSC} ${LSC_FLAGS} --compile --print ${SRC}"

    def redirect_and_run(self):
        with open(self.outputs[0].abspath(), "wb") as self.stdout:
            return self._run()


@feature("live")
@before("process_source")
def process_live(tgen):
    for source, target in zip(tgen.to_nodes(tgen.source), tgen.to_out_nodes(tgen.target)):
        task = tgen.create_task("lsc", source, target)
        task._run = task.run
        task.run = task.redirect_and_run
    tgen.source = [ ]
