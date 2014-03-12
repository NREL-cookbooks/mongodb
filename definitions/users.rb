#
# Cookbook Name:: mongo_bde
# Definition:: users
#
# Copyright 2013, Nicholas Long


define :add_mongo_user, :password => nil, :database => nil, :roles => [] do
  name = params[:name]
  password = params[:password]
  database = params[:database]
  roles = params[:roles]

  ruby_block "adding_user #{name}" do
    block do
      # check if auth is needed
      require 'mongo'

      connection = Mongo::Connection.new("localhost", node[:mongodb][:port])
      is_master = connection.check_is_master(["localhost", node[:mongodb][:port]])['ismaster'] || false
      Chef::Log.info("Node is not the Master node, will skip user methods") if not is_master
      if is_master
        auth_needed = false
        begin
          test_command = connection['admin'].eval("db.system.users.find({user:'admin'}).count()")
        rescue
          # need to authenticate (most likely)
          auth_needed = true
        end

        if auth_needed
          Chef::Log.info "Authenticating admin user"
          success = connection['admin'].authenticate('admin', node[:mongodb][:admin_password])
          Chef::Log.error "could not authenitcate as admin on database" if not success
        end

        user_exists = connection[database].eval("db.system.users.find({user:'#{name}'}).count()").to_i == 1
        if !user_exists
          Chef::Log.info("Adding mongo user: #{name}")
          connection[database].add_user(name, password, false, {:roles => roles})
        else
          Chef::Log.info("User '#{name}' already exists")
          # todo: updating roles
          
        end
      end
    end
  end
end
