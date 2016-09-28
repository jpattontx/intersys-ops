[Chef::Recipe, Chef::Resource].each { |l| l.send :include, ::Extensions }

Erubis::Context.send(:include, Extensions::Templates)

elasticsearch = "elasticsearch-#{node.elasticsearch[:version]}"

include_recipe "elasticsearch::curl"
include_recipe "ark"

# Create user

user node.elasticsearch[:user] do
  comment "ElasticSearch User"
  home    "#{node.elasticsearch[:dir]}/elasticsearch"
  shell   "/bin/bash"
  uid     2008
  supports :manage_home => false
  action  :create
  not_if  { ::File.exists?('/opt/elasticsearch') }
end

# FIX: Work around the fact that Chef creates the directory even for `manage_home: false`
bash "remove the elasticsearch user home" do
  user    'root'
  code    "rm -rf  #{node.elasticsearch[:dir]}/elasticsearch"

  not_if  "test -L #{node.elasticsearch[:dir]}/elasticsearch"
  only_if "test -d #{node.elasticsearch[:dir]}/elasticsearch"
end

# Create ES directories
#[ node.elasticsearch[:path][:conf], node.elasticsearch[:path][:logs], node.elasticsearch[:pid_path] ].each do |path|
[ node.elasticsearch[:path][:conf], node.elasticsearch[:path][:logs], node.elasticsearch[:path][:masterlogs], node.elasticsearch[:pid_path] ].each do |path|
  directory path do
    owner node.elasticsearch[:user] and group node.elasticsearch[:user] and mode 0755
    recursive true
    action :create
  end
end

# Create data path directories
#
data_paths = node.elasticsearch[:path][:data].is_a?(Array) ? node.elasticsearch[:path][:data] : node.elasticsearch[:path][:data].split(',')

data_paths.each do |path|
  directory path.strip do
    owner node.elasticsearch[:user] and group node.elasticsearch[:user] and mode 0755
    recursive true
    action :create
  end
end

# Create service
#
template "/etc/init.d/elasticsearch" do
  source "elasticsearch.init.erb"
  owner 'root' and mode 0755
end

service "elasticsearch" do
  supports :status => true, :restart => true
  action [ :enable ]
end

# Download, extract, symlink the elasticsearch libraries and binaries
#
ark_prefix_root = node.elasticsearch[:dir] || node.ark[:prefix_root]
ark_prefix_home = node.elasticsearch[:dir] || node.ark[:prefix_home]

ark "elasticsearch" do
  url   node.elasticsearch[:download_url]
  owner node.elasticsearch[:user]
  group node.elasticsearch[:user]
  version node.elasticsearch[:version]
  has_binaries ['bin/elasticsearch', 'bin/plugin']
  checksum node.elasticsearch[:checksum]
  prefix_root   ark_prefix_root
  prefix_home   ark_prefix_home

#  notifies :start,   'service[elasticsearch]'
#  notifies :restart, 'service[elasticsearch]' unless node.elasticsearch[:skip_restart]

  not_if do
    link   = "#{node.elasticsearch[:dir]}/elasticsearch"
    target = "#{node.elasticsearch[:dir]}/elasticsearch-#{node.elasticsearch[:version]}"
    binary = "#{target}/bin/elasticsearch"

    ::File.directory?(link) && ::File.symlink?(link) && ::File.readlink(link) == target && ::File.exists?(binary)
  end
end

# Increase open file and memory limits
#
bash "enable user limits" do
  user 'root'

  code <<-END.gsub(/^    /, '')
    echo 'session    required   pam_limits.so' >> /etc/pam.d/su
  END

  not_if { ::File.read("/etc/pam.d/su").match(/^session    required   pam_limits\.so/) }
end

#log "increase limits for the elasticsearch user"

file "/etc/security/limits.d/10-elasticsearch.conf" do
  content <<-END.gsub(/^    /, '')
    #{node.elasticsearch.fetch(:user, "elasticsearch")}     -    nofile    #{node.elasticsearch[:limits][:nofile]}
    #{node.elasticsearch.fetch(:user, "elasticsearch")}     -    memlock   #{node.elasticsearch[:limits][:memlock]}
  END
end

# Create file with ES environment variables
#
template "elasticsearch-env.sh" do
  path   "#{node.elasticsearch[:path][:conf]}/elasticsearch-env.sh"
  source "elasticsearch-env.sh.erb"
  owner node.elasticsearch[:user] and group node.elasticsearch[:user] and mode 0755

#  notifies :restart, 'service[elasticsearch]' unless node.elasticsearch[:skip_restart]
end

# Create ES config file
#
template "elasticsearch.yml" do
  path   "#{node.elasticsearch[:path][:conf]}/elasticsearch.yml"
  source "elasticsearch.yml.erb"
  owner node.elasticsearch[:user] and group node.elasticsearch[:user] and mode 0755

#  notifies :restart, 'service[elasticsearch]' unless node.elasticsearch[:skip_restart]
end

# Create ES in file
#
template "elasticsearch.in.sh" do
  path   "#{node.elasticsearch[:path][:bin]}/elasticsearch.in.sh"
  source "elasticsearch.in.sh.erb"
  owner node.elasticsearch[:user] and group node.elasticsearch[:user] and mode 0755

#  notifies :restart, 'service[elasticsearch]' unless node.elasticsearch[:skip_restart]
end

# Create ES logging file
#
template "logging.yml" do
  path   "#{node.elasticsearch[:path][:conf]}/logging.yml"
  source "logging.yml.erb"
  owner node.elasticsearch[:user] and group node.elasticsearch[:user] and mode 0755

#  notifies :restart, 'service[elasticsearch]' unless node.elasticsearch[:skip_restart]
end

# Install ES Optimize Script
#
template "/opt/elasticsearch/bin/elasticsearch-optimize.sh" do
   source "elasticsearch-optimize.sh.erb"
   mode 0755
   owner "elasticsearch"
   group "elasticsearch"
end

# Install ES Backup Script
#
template "/opt/elasticsearch/bin/elasticsearch-backup.sh" do
   source "elasticsearch-backup.sh.erb"
   mode 0755
   owner "elasticsearch"
   group "elasticsearch"
end

# Install ES Restore Script
#
template "/opt/elasticsearch/bin/elasticsearch-restore.sh" do
   source "elasticsearch-restore.sh.erb"
   mode 0755
   owner "elasticsearch"
   group "elasticsearch"
 end


# Install ES Shard Lister script (used by the backup script) 
#
cookbook_file "/opt/elasticsearch/bin/elasticsearch-listLocalPrimaryShards.py" do
   source "elasticsearch-listLocalPrimaryShards.py"
   mode 0755
   owner "elasticsearch"
   group "elasticsearch"
 end

# Create .ssh directory
#
directory "/opt/elasticsearch/.ssh" do
   owner 'elasticsearch'
   group 'elasticsearch'
   mode '0700'
   action :create
end

# Install ssh authorized_keys
#
cookbook_file "/opt/elasticsearch/.ssh/authorized_keys" do
   source "authorized_keys"
   mode 0600
   owner "elasticsearch"
   group "elasticsearch"
 end

# Install ssh private key 
#
cookbook_file "/opt/elasticsearch/.ssh/backup_sync-id_rsa" do
   source "backup_sync-id_rsa"
   mode 0400
   owner "elasticsearch"
   group "elasticsearch"
 end

# Install ssh public key 
#
cookbook_file "/opt/elasticsearch/.ssh/backup_sync-id_rsa.pub" do
   source "backup_sync-id_rsa.pub"
   mode 0400
   owner "elasticsearch"
   group "elasticsearch"
 end

###########################################################################
# Cron Jobs

# Daily backup cron job (production only)
cron "elasticsearch_backup_job" do
  minute "10"
  hour "19"
  weekday "0-5"
  user "root"
  mailto "jason.patton@avention.com"
  command "/opt/elasticsearch/bin/elasticsearch-backup.sh final dd prd2-av.daily"
  only_if { node["chef"]["instance_role"] == "instance-av-prd2"  }
end

cron "cmdm_elasticsearch_backup_job" do
  minute "00"
  hour "01"
  weekday "0-5"
  user "root"
  mailto "jason.patton@avention.com"
  command "/opt/elasticsearch/bin/elasticsearch-backup.sh final dd prd2-cmdm.daily"
  only_if { node["chef"]["instance_role"] == "instance-cmdm-prd2"  }
end

# Weekly rotation of ES backup
cron "elasticsearch_backup_rotation" do
  minute "10"
  hour "23"
  weekday "3"
  user "root"
  mailto "jason.patton@avention.com"
  command "rsync -avL --delete #{node.elasticsearch[:backup][:dd_mount]}/prd2-av.daily #{node.elasticsearch[:backup][:dd_mount]}/prd2-av.weekly"
  only_if { node["fqdn"] == "prd2-av-esa05.avention.com" }
end

cron "cmdm_elasticsearch_backup_rotation" do
  minute "00"
  hour "03"
  weekday "3"
  user "root"
  mailto "jason.patton@avention.com"
  command "rsync -avL --delete #{node.elasticsearch[:backup][:dd_mount]}/prd2-cmdm.daily #{node.elasticsearch[:backup][:dd_mount]}/prd2-cmdm.weekly"
  only_if { node["fqdn"] == "prd2-cmdm-es03.avention.com" }
end

# Weekly optimize cron job (captain only)
cron "elasticsearch_optimize_job" do
  minute "10"
  hour "18"
  weekday "5"
  user "elasticsearch"
  mailto "ops@avention.com"
  command "/opt/elasticsearch/bin/elasticsearch-optimize.sh"
  only_if { node["elasticsearch"]["backup_captain"] == node["fqdn"] }
end

###########################################################################
