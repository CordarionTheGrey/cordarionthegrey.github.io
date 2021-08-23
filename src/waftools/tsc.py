from waflib.Task    import Task
from waflib.TaskGen import before, feature

import taskgen_utils


def configure(cnf):
    cnf.find_program("tsc", var="TSC")


class tsc(Task):
    run_str = "${TSC} ${TSC_FLAGS} --project ${SRC}"


@feature("ts")
@before("process_source")
def process_ts(tgen):
    source_path = tgen.source_path
    target_path = tgen.target_path
    sources = source_path.ant_glob("**/*.ts")
    task = tgen.create_task("tsc",
        source_path.find_resource("tsconfig.json"),
        [target_path.make_node(source.path_from(source_path)[:-3] + ".js") for source in sources],
    )
    task.dep_nodes = sources
    tgen.source = [ ]
