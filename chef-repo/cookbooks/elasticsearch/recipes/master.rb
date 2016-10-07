[Chef::Recipe, Chef::Resource].each { |l| l.send :include, ::Extensions }

Erubis::Context.send(:include, Extensions::Templates)

include_recipe "elasticsearch"

# Create directories
[ node.elasticsearch.master[:path][:conf], node.elasticsearch.master[:path][:logs], node.elasticsearch.master[:path][:pid], node.elasticsearch.master[:path][:data] ].each do |path|
  directory path do
    owner node.elasticsearch[:user] and group node.elasticsearch[:user] and mode 0755
    recursive true
    action :create
  end
end

# Copy shield config directory
bash 'copy_shield_config' do
  code "cp -r #{node.elasticsearch[:path][:home]}/config/shield #{node.elasticsearch.master[:path][:conf]}/"
end

# Update elasticsearch.yml
template "#{node.elasticsearch.master[:path][:conf]}/elasticsearch.yml" do
  source "elasticsearch.yml.erb"
  owner "#{node.elasticsearch[:user]}"
  group "#{node.elasticsearch[:group]}"
  mode "0644"
  variables(
      :nodetype => "master",
      :is_master => "true",
      :is_data => "false"
  )
end



# Env setup script
template "#{node.elasticsearch.master[:path][:conf]}/elasticsearch-env.sh" do
  source "environment.sh.erb"
  owner "#{node.elasticsearch[:user]}"
  group "#{node.elasticsearch[:group]}"
  mode "0755"
  variables(
      :nodetype => "master"
  )
end


# Logging config
template "#{node.elasticsearch.master[:path][:conf]}/logging.yml" do
  source "logging.yml.erb"
  owner "#{node.elasticsearch[:user]}"
  group "#{node.elasticsearch[:group]}"
  mode "0755"
  variables(
      :nodetype => "master"
  )
end


# Init script for systemd
template "/etc/systemd/system/#{node.elasticsearch.master[:service][:name]}.service" do
  source 'sysd-init.erb'
  variables(
      nodetype: "master"
  )
  cookbook 'elasticsearch'
  owner 'root'
  group 'root'
  mode '0644'
#  notifies :run, 'execute[Load systemd unit file]', :immediately
end

service "#{node.elasticsearch.master[:service][:name]}.service" do
  supports :status => true, :start => true, :stop => true, :restart => true
  action [ :enable ]
end