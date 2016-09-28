
include_recipe "elasticsearch"

# Create service
#
template "/etc/init.d/elasticsearch-master" do
  source "elasticsearch-master.init.erb"
  owner 'root' and mode 0755
end

service "elasticsearch-master" do
  supports :status => true, :restart => true
  action [ :enable ]
end

# Create file with ES environment variables
#
template "elasticsearch-master-env.sh" do
  path   "#{node.elasticsearch[:path][:conf]}/elasticsearch-master-env.sh"
  source "elasticsearch-master-env.sh.erb"
  owner node.elasticsearch[:user] and group node.elasticsearch[:user] and mode 0755

#  notifies :restart, 'service[elasticsearch]' unless node.elasticsearch[:skip_restart]
end

# Create ES config file
#
template "elasticsearch-master.yml" do
  path   "#{node.elasticsearch[:path][:conf]}/elasticsearch-master.yml"
  source "elasticsearch-master.yml.erb"
  owner node.elasticsearch[:user] and group node.elasticsearch[:user] and mode 0755

#  notifies :restart, 'service[elasticsearch]' unless node.elasticsearch[:skip_restart]
end

# Create ES in file
#
template "elasticsearch-master.in.sh" do
  path   "#{node.elasticsearch[:path][:bin]}/elasticsearch-master.in.sh"
  source "elasticsearch-master.in.sh.erb"
  owner node.elasticsearch[:user] and group node.elasticsearch[:user] and mode 0755

#  notifies :restart, 'service[elasticsearch]' unless node.elasticsearch[:skip_restart]
end
