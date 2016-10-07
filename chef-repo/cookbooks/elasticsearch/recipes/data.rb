[Chef::Recipe, Chef::Resource].each { |l| l.send :include, ::Extensions }

Erubis::Context.send(:include, Extensions::Templates)

include_recipe "elasticsearch"

# Create directories
[ node.elasticsearch.data[:path][:conf], node.elasticsearch.data[:path][:logs], node.elasticsearch.data[:path][:pid], node.elasticsearch.data[:path][:data] ].each do |path|
  directory path do
    owner node.elasticsearch[:user] and group node.elasticsearch[:user] and mode 0755
    recursive true
    action :create
  end
end

# Copy shield config directory
bash 'copy_shield_config' do
  code "cp -r #{node.elasticsearch[:path][:home]}/config/shield #{node.elasticsearch.data[:path][:conf]}/"
end

# Update elasticsearch.yml
template "#{node.elasticsearch.data[:path][:conf]}/elasticsearch.yml" do
  source "elasticsearch.yml.erb"
  owner "#{node.elasticsearch[:user]}"
  group "#{node.elasticsearch[:group]}"
  mode "0644"
  variables(
      :nodetype => "data",
      :is_master => "false",
      :is_data => "true"
  )
end



# Env setup script
template "#{node.elasticsearch.data[:path][:conf]}/elasticsearch-env.sh" do
  source "environment.sh.erb"
  owner "#{node.elasticsearch[:user]}"
  group "#{node.elasticsearch[:group]}"
  mode "0755"
  variables(
      :nodetype => "data"
  )
end


# Logging config
template "#{node.elasticsearch.data[:path][:conf]}/logging.yml" do
  source "logging.yml.erb"
  owner "#{node.elasticsearch[:user]}"
  group "#{node.elasticsearch[:group]}"
  mode "0755"
  variables(
      :nodetype => "data"
  )
end


# Init script for systemd
template "/etc/systemd/system/#{node.elasticsearch.data[:service][:name]}.service" do
  source 'sysd-init.erb'
  variables(
      nodetype: "data"
  )
  cookbook 'elasticsearch'
  owner 'root'
  group 'root'
  mode '0644'
#  notifies :run, 'execute[Load systemd unit file]', :immediately
end

service "#{node.elasticsearch.data[:service][:name]}.service" do
  supports :status => true, :start => true, :stop => true, :restart => true
  action [ :enable ]
end