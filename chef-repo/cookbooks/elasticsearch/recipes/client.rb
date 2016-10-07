[Chef::Recipe, Chef::Resource].each { |l| l.send :include, ::Extensions }

Erubis::Context.send(:include, Extensions::Templates)

include_recipe "elasticsearch"

# Create directories
[ node.elasticsearch.client[:path][:conf], node.elasticsearch.client[:path][:logs], node.elasticsearch.client[:path][:pid], node.elasticsearch.client[:path][:data] ].each do |path|
  directory path do
    owner node.elasticsearch[:user] and group node.elasticsearch[:user] and mode 0755
    recursive true
    action :create
  end
end

# Update elasticsearch.yml
template "#{node.elasticsearch.client[:path][:conf]}/elasticsearch.yml" do
  source "elasticsearch.yml.erb"
  owner "#{node.elasticsearch[:user]}"
  group "#{node.elasticsearch[:group]}"
  mode "0644"
  variables(
      :nodetype => "client",
      :is_master => "false",
      :is_data => "false"
  )
end