from waflib.TaskGen import taskgen_method


@taskgen_method
def to_out_nodes(tgen, targets):
    targets = tgen.to_list(targets)
    if not isinstance(targets, list):
        return [targets]
    return [tgen.path.find_or_declare(node) if isinstance(node, str) else node for node in targets]
