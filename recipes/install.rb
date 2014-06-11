if node['mongodb']['install_method'] == "10gen" or node.run_list.recipes.include?("mongodb::10gen_repo") then
    include_recipe "mongodb::10gen_repo"
end

# prevent-install defaults, but don't overwrite
file node['mongodb']['sysconfig_file'] do
    content "ENABLE_MONGODB=no"
    group node['mongodb']['root_group']
    owner "root"
    mode 0644
    action :create_if_missing
end

# just-in-case config file drop
template node['mongodb']['dbconfig_file'] do
    cookbook node['mongodb']['template_cookbook']
    source node['mongodb']['dbconfig_file_template']
    group node['mongodb']['root_group']
    owner "root"
    mode 0644
    action :create_if_missing
end

# and we install our own init file
if node['mongodb']['apt_repo'] == "ubuntu-upstart" then
    init_file = File.join(node['mongodb']['init_dir'], "#{node['mongodb']['default_init_name']}.conf")
else
    init_file = File.join(node['mongodb']['init_dir'], "#{node['mongodb']['default_init_name']}")
end
template init_file do
    cookbook node['mongodb']['template_cookbook']
    source node['mongodb']['init_script_template']
    group node['mongodb']['root_group']
    owner "root"
    mode "0755"
    variables({
        :provides => "mongod"
    })
    action :create_if_missing
end

packager_opts = ""
case node['platform_family']
when "debian"
    # this options lets us bypass complaint of pre-existing init file
    # necessary until upstream fixes ENABLE_MONGOD/DB flag
    packager_opts = '-o Dpkg::Options::="--force-confold"'
when "rhel"
    # Add --nogpgcheck option when package is signed
    # see: https://jira.mongodb.org/browse/SERVER-8770
    packager_opts = "--nogpgcheck"
end

if(node[:mongodb][:package_version] && node[:mongodb][:package_version].to_f <= 2.4)
  # As part of MongoDB's "10gen" to "mongodb-org" transition they declared
  # their 2.4 10gen packages obsolete. This means everything automatically gets
  # upgraded to the new mognodb-org 2.6 packages automatically. To prevent this
  # from happening, exclude all the new "mongodb-org" 2.6 packages if we were
  # explicitly trying to install 2.4.
  packager_opts << " --exclude='mongodb-org*'"

  # On systems that were accidentally upgraded to 2.6, uninstall the 2.6
  # packages so then the 2.4 packages can be reinstalled properly.
  uninstall_packages = [
    "mongodb-org",
    "mongodb-org-mongos",
    "mongodb-org-server",
    "mongodb-org-shell",
    "mongodb-org-tools",
  ]

  uninstall_packages.each do |package_name|
    package(package_name) do
      action :remove
    end
  end
end

# The mongo-10gen-server package depends on mongo-10gen, but doesn't specify a
# version. So to prevent the server from being upgraded without the client
# being upgraded, also explicitly install the mongo-10gen with the
# package_version specified.
if(node[:mongodb][:package_name] == "mongo-10gen-server")
  package "mongo-10gen" do
    options packager_opts
    action :install
    version node[:mongodb][:package_version]
  end
elsif(node[:mongodb][:package_name] == "mongodb-org-server")
  package "mongodb-org" do
    options packager_opts
    action :install
    version node[:mongodb][:package_version]
  end
end

# FIXME: For working around Chef vs package issues. See FIXME below.
if(node[:platform_family] == "rhel")
  package "yum-plugin-tsflags"

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
  intalled = `rpm -qa | grep "#{node[:mongodb][:package_name]}"`
  if($?.exitstatus == 0)
    packager_opts << " --tsflags=noscripts"
  end
end

# install
package node[:mongodb][:package_name] do
    options packager_opts
    action :install
    version node[:mongodb][:package_version]
end

# Create keyFile if specified
if node[:mongodb][:key_file_content] then
  file node[:mongodb][:config][:keyFile] do
    owner node[:mongodb][:user]
    group node[:mongodb][:group]
    mode  "0600"
    backup false
    content node[:mongodb][:key_file_content]
  end
end
