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

needs_mongo_gem = (node.recipes.include?("mongodb::replicaset") or node.recipes.include?("mongodb::mongos"))

# install the mongo ruby gem at compile time to make it globally available
if needs_mongo_gem
  if(Gem.const_defined?("Version") and Gem::Version.new(Chef::VERSION) < Gem::Version.new('10.12.0'))
    gem_package 'mongo' do
      action :nothing
    end.run_action(:install)
    Gem.clear_paths
  else
    chef_gem 'mongo' do
      action :install
    end
  end
end

# Create keyFile if specified
if node[:mongodb][:key_file]
  file "/etc/mongodb.key" do
    owner node[:mongodb][:user]
    group node[:mongodb][:group]
    mode  "0600"
    backup false
    content node[:mongodb][:key_file]
  end
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
