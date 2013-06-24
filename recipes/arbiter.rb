node.default['mongodb']['arbiter'] = true

include_recipe "mongodb::replicaset"
