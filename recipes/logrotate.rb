include_recipe "logrotate"
include_recipe "rsyslog"

template "/etc/rsyslog.d/mongodb.conf" do
  source "rsyslog.conf.erb"
  owner "root"
  group "root"
  mode "0644"
  notifies :restart, "service[rsyslog]"
end

logrotate_app "mongodb" do
  path [node[:mongodb][:logrotate][:path]]
  frequency "daily"
  frequency node[:mongodb][:logrotate][:frequency]
  rotate node[:mongodb][:logrotate][:rotate]
end
