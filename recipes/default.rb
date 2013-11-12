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

# FIXME: For working around Chef vs package issues. See FIXME below.
if(node[:platform_family] == "rhel")
  package "yum-plugin-tsflags"
end

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

  # FIXME: Don't run the yum post-installation scripts when upgrading Mongo.
  # This is due to a few issues with how this chef package installs things (by
  # relying on a custom init.d and sysconfig files) and the fact that Opscode's
  # RPMs will overwrite those and restart immediately during the upgrade
  # process. By not running the yum scripts after an upgrade, Mongo won't get
  # restarted in a broken state.
  #
  # This should all be cleaned up and probably not necessary if the Chef
  # cookbook starts to use the conf files instead of sysconfig, to better match
  # what Mongo installs by default from the RPMs:
  # https://github.com/edelight/chef-mongodb/pull/136
  # https://github.com/edelight/chef-mongodb/pull/139
  if(node[:platform_family] == "rhel")
    intalled = `rpm -qa | grep "#{node[:mongodb][:package_name]}"`
    if($?.exitstatus == 0)
      options "--tsflags=noscripts"
    end
  end
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
