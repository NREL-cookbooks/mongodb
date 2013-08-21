#
# Cookbook Name:: mongodb
# Recipe:: default
#
# Copyright 2011, edelight GmbH
# Authors:
#       Markus Korn <markus.korn@edelight.de>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# The mongo-10gen-server package depends on mongo-10gen, but doesn't specify a
# version. So to prevent the server from being upgraded without the client
# being upgraded, also explicitly install the mongo-10gen with the
# package_version specified.
if(node[:mongodb][:package_name] == "mongo-10gen-server")
  package "mongo-10gen" do
    action :install
    version node[:mongodb][:package_version]
  end
end

package node[:mongodb][:package_name] do
  action :install
  version node[:mongodb][:package_version]
end

needs_mongo_gem = (node.recipe?("mongodb::replicaset") or node.recipe?("mongodb::mongos"))

if needs_mongo_gem
  # install the mongo ruby gem at compile time to make it globally available
  chef_gem 'mongo' do
    action :nothing
  end.run_action(:install)
  Gem.clear_paths
end

if(!node.recipe?("mongodb::replicaset") && (node.recipe?("mongodb::default") || node.recipe?("mongodb")))
  # configure default instance

  mongodb_instance node['mongodb']['instance_name'] do
    mongodb_type "mongod"
    bind_ip      node['mongodb']['bind_ip']
    port         node['mongodb']['port']
    logpath      node['mongodb']['logpath']
    dbpath       node['mongodb']['dbpath']
    enable_rest  node['mongodb']['enable_rest']
    smallfiles   node['mongodb']['smallfiles']
  end
end
