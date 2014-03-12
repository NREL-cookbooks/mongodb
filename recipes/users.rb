#
# Cookbook Name:: mongo_bde.nrel.gov
# Recipe:: users
#
# Copyright (C) 2013 Nicholas Long
# 
# All rights reserved - Do Not Redistribute
#

include_recipe "mongodb::mongo_gem"

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

if node[:mongodb][:use_admin_password]
  if Chef::Config[:solo]
    Chef::Log.info "Using chef solo so will use predefined admin password or set a new one"
    temp_admin_pw = secure_password(30)
    Chef::Log.info "Make sure to write down this password because you didn't provide one #{temp_admin_pw}"
    node.set_unless[:mongodb][:admin_password] = temp_admin_pw
  else
    mongo_creds = Chef::EncryptedDataBagItem.load("keyfiles", "mongo")
    Chef::Log.info "set mongo admin password to value in databag"
    node.set_unless[:mongodb][:admin_password] = mongo_creds["admin_password"]
  end

  add_mongo_user "admin" do
    password node[:mongodb][:admin_password]
    database "admin"
    roles ["userAdminAnyDatabase", "readWriteAnyDatabase", "clusterAdmin", "dbAdminAnyDatabase"]
  end
end

node[:mongodb][:users].each_pair do |name, user|
  # create passwords if they don't exist
  Chef::Log.info "Adding user '#{name}' with on database '#{user[:database]}'"
  tmp_password = nil
  if !user[:password]
    tmp_password = secure_password
    node.set_unless[:mongodb][:users][name][:password] = tmp_password

    if Chef::Config[:solo]
      Chef::Log.warn "It is not recommended to dynamically add a password with chef solo. Please save the password shown below"
      Chef::Log.info "New password for #{name} set to #{tmp_password}"
    else
      node.save
    end
  else
    tmp_password = user[:password]
  end

  Chef::Log.info "creating password of #{node[:mongodb][:users][name][:password]}"
  add_mongo_user name do
    password tmp_password
    database user[:database]
    roles user[:roles]
  end
end
