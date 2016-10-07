#
# Cookbook Name:: elasticsearch
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.


include_recipe "java"

package 'curl' do
  action :install
end

# Create user

user node.elasticsearch[:user] do
  comment "ElasticSearch User"
  home    "#{node.elasticsearch[:path][:home]}"
  shell   "/bin/bash"
  action  :create
  not_if  { ::File.exists?("#{node.elasticsearch[:path][:home]}") }
end


# Install ES
cookbook_file "/tmp/#{node.elasticsearch[:filename]}" do
  source "#{node.elasticsearch[:filename]}"
  mode 0644
  owner "#{node.elasticsearch[:user]}"
  group "#{node.elasticsearch[:group]}"
end

bash 'extract_binaries' do
  creates "#{node.elasticsearch[:path][:home]}/bin/elasticsearch"
  code <<-EOH
mkdir -p #{node.elasticsearch[:path][:home]}
cd #{node.elasticsearch[:path][:home]}
tar xfvz /tmp/#{node.elasticsearch[:filename]} --strip 1
rm -rf config
chown -R #{node.elasticsearch[:user]}:#{node.elasticsearch[:group]} .
echo  "#{node.elasticsearch[:version]}" > "version-#{node.elasticsearch[:version]}"
  EOH
  not_if  "test -f #{node.elasticsearch[:path][:home]}/version-#{node.elasticsearch[:version]}"
end


# Extra startup scripts needed by init scripts
template "#{node.elasticsearch[:path][:bin]}/elasticsearch-systemd-pre-exec.sh" do
  source "elasticsearch-systemd-pre-exec.sh.erb"
  owner "#{node.elasticsearch[:user]}"
  group "#{node.elasticsearch[:group]}"
  mode "0755"
end


# Install ES plugins
node.elasticsearch.plugin[:mandatory].each do |plugin|

  cookbook_file "/tmp/#{plugin}.zip" do
    source "#{node.elasticsearch[:version]}/#{plugin}.zip"
    mode 0644
    owner "#{node.elasticsearch[:user]}"
    group "#{node.elasticsearch[:group]}"
  end

  bash 'install_plugins' do
    code <<-EOH
cd #{node.elasticsearch[:path][:home]}
bin/plugin install -b file:///tmp/#{plugin}.zip
    EOH
    not_if  "test -d #{node.elasticsearch[:path][:home]}/plugins/#{plugin}"
  end
end