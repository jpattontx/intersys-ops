# Load settings from data bag 'elasticsearch/settings'
#
settings = Chef::DataBagItem.load('elasticsearch', 'settings')[node.chef_environment] rescue {}
Chef::Log.debug "Loaded settings: #{settings.inspect}"


# Initialize the node attributes with node attributes merged with data bag attributes
#
node.default[:elasticsearch] ||= {}
node.normal[:elasticsearch]  ||= {}
node.normal[:elasticsearch]    = DeepMerge.merge(node.default[:elasticsearch].to_hash, node.normal[:elasticsearch].to_hash)
node.normal[:elasticsearch]    = DeepMerge.merge(node.normal[:elasticsearch].to_hash, settings.to_hash)


# === VERSION AND LOCATION
#
default.elasticsearch[:version]       = "2.3.4"
default.elasticsearch[:filename]      = "elasticsearch-#{node.elasticsearch[:version]}.tar.gz"


# === NAMING
#
default.elasticsearch[:service][:name] = 'elasticsearch'
default.elasticsearch.client[:service][:name]    = "#{node.elasticsearch[:service][:name]}-client"
default.elasticsearch.data[:service][:name]    = "#{node.elasticsearch[:service][:name]}-data"
default.elasticsearch.master[:service][:name]    = "#{node.elasticsearch[:service][:name]}-master"

default.elasticsearch[:cluster][:name] = 'elasticsearch'
default.elasticsearch.client[:node][:name]    = "#{node.name}-client"
default.elasticsearch.data[:node][:name]    = "#{node.name}-data"
default.elasticsearch.master[:node][:name]    = "#{node.name}-master"

# === USER & PATHS
#
default.elasticsearch[:user]         = "elasticsearch"
default.elasticsearch[:group]      = "elasticsearch"

default.elasticsearch[:path][:home]   = "/opt/elasticsearch"
default.elasticsearch[:path][:bin]    = "#{node.elasticsearch[:path][:home]}/bin"
default.elasticsearch.data[:path][:conf]   = "#{node.elasticsearch[:path][:home]}/config-data"
default.elasticsearch.master[:path][:conf]   = "#{node.elasticsearch[:path][:home]}/config-master"
default.elasticsearch.data[:path][:data]   = "#{node.elasticsearch[:path][:home]}/data"
default.elasticsearch.master[:path][:data]   = "#{node.elasticsearch[:path][:home]}/masterdata"
default.elasticsearch.data[:path][:logs]   = "#{node.elasticsearch[:path][:home]}/logs"
default.elasticsearch.master[:path][:logs]   = "#{node.elasticsearch[:path][:home]}/logs"
default.elasticsearch[:path][:pid]  = "#{node.elasticsearch[:path][:home]}/logs"
default.elasticsearch.client[:path][:pid]  = "#{node.elasticsearch[:path][:pid]}"
default.elasticsearch.client[:pid_file]  = "#{node.elasticsearch.client[:path][:pid]}/#{node.elasticsearch.client[:node][:name].to_s.gsub(/\W/, '_')}.pid"
default.elasticsearch.data[:path][:pid]  = "#{node.elasticsearch[:path][:pid]}"
default.elasticsearch.data[:pid_file]  = "#{node.elasticsearch.data[:path][:pid]}/#{node.elasticsearch.data[:node][:name].to_s.gsub(/\W/, '_')}.pid"
default.elasticsearch.master[:path][:pid]  = "#{node.elasticsearch[:path][:pid]}"
default.elasticsearch.master[:pid_file]  = "#{node.elasticsearch.master[:path][:pid]}/#{node.elasticsearch.master[:node][:name].to_s.gsub(/\W/, '_')}.pid"


# === Zeroing
#
default.elasticsearch[:zero][:enabled] = false

# === MEMORY
#
# Maximum amount of memory to use is automatically computed as one half of total available memory on the machine.
# You may choose to set it in your node/role configuration instead.
#

default.elasticsearch.client[:allocated_memory_pct_of_heap] = 0.2
client_allocated_memory_int = (((node.memory.total.to_i * node.elasticsearch.client[:allocated_memory_pct_of_heap] ).floor / 1024)/32).ceil * 32
client_allocated_memory = "#{client_allocated_memory_int}m"
default.elasticsearch.client[:allocated_memory] = client_allocated_memory

default.elasticsearch.data[:allocated_memory_pct_of_heap] = 0.5
data_allocated_memory_int = (((node.memory.total.to_i * node.elasticsearch.data[:allocated_memory_pct_of_heap] ).floor / 1024)/32).ceil * 32
data_allocated_memory = "#{data_allocated_memory_int}m"
default.elasticsearch.data[:allocated_memory] = data_allocated_memory

default.elasticsearch.master[:allocated_memory_pct_of_heap] = 0.1
master_allocated_memory_int = (((node.memory.total.to_i * node.elasticsearch.master[:allocated_memory_pct_of_heap] ).floor / 1024)/32).ceil * 32
master_allocated_memory = "#{master_allocated_memory_int}m"
default.elasticsearch.master[:allocated_memory] = master_allocated_memory

# === GARBAGE COLLECTION SETTINGS
#
default.elasticsearch[:gc_settings] =<<-CONFIG
  -XX:+UseParNewGC
  -XX:+UseConcMarkSweepGC
  -XX:CMSInitiatingOccupancyFraction=75
  -XX:+UseCMSInitiatingOccupancyOnly
  -XX:+HeapDumpOnOutOfMemoryError
CONFIG

# Sets Minimum master nodes to 1000 by default. This will prevent nodes coming up as single hosts if config is missing
default.elasticsearch[:discovery][:zen][:minimum_master_nodes]    = 1000

# === LIMITS
#
# By default, the `mlockall` is set to true: on weak machines and Vagrant boxes,
# you may want to disable it.
#
default.elasticsearch[:bootstrap][:mlockall] = true
default.elasticsearch[:limits][:memlock] = 'unlimited'
default.elasticsearch[:limits][:nofile]  = '64000'

# === PRODUCTION SETTINGS
#
default.elasticsearch[:security][:manager][:enabled] = false
default.elasticsearch[:index][:mapper][:dynamic]   = true
default.elasticsearch[:action][:auto_create_index] = true
default.elasticsearch[:action][:disable_delete_all_indices] = true
default.elasticsearch[:node][:max_local_storage_nodes] = 1

default.elasticsearch[:discovery][:zen][:ping][:multicast][:enabled] = false
default.elasticsearch[:gateway][:expected_nodes] = 1

default.elasticsearch[:thread_stack_size] = "256k"

default.elasticsearch[:env_options] = ""

default.elasticsearch[:backup][:nfs_mount] = "/es-backups"
default.elasticsearch[:backup][:snapshot_size] = "100G"


# === OTHER SETTINGS
#


default.elasticsearch[:skip_restart] = true


# === PORT
#
default.elasticsearch.client[:http][:port] = 9200
default.elasticsearch.data[:http][:port] = 9200
default.elasticsearch.master[:http][:port] = 9600


# === CUSTOM CONFIGURATION
#
default.elasticsearch[:custom_config] = {}
default.elasticsearch.client[:custom_config] = {}
default.elasticsearch.data[:custom_config] = {}
default.elasticsearch.master[:custom_config] = {}

# === LOGGING
#
# See `attributes/logging.rb`
#
default.elasticsearch[:logging] = {}

# --------------------------------------------------
# NOTE: Setting the attributes for elasticsearch.yml
# --------------------------------------------------
#
# The template uses the `print_value` extension method to print attributes with a "truthy"
# value, set either in data bags, node attributes, role override attributes, etc.
#
# It is possible to set *any* configuration value exposed by the Elasticsearch configuration file.
#
# For example:
#
#     <%= print_value 'cluster.routing.allocation.node_concurrent_recoveries' -%>
#
# will print a line:
#
#     cluster.routing.allocation.node_concurrent_recoveries: <VALUE>
#
# if the either of following node attributes is set:
#
# * `node.cluster.routing.allocation.node_concurrent_recoveries`
# * `node['cluster.routing.allocation.node_concurrent_recoveries']`
#
# The default attributes set by the cookbook configure a minimal set inferred from the environment
# (eg. memory settings, node name), or reasonable defaults for production.
#
# The template is based on the elasticsearch.yml file from the Elasticsearch distribution;
# to set other configurations, set the `node.elasticsearch[:custom_config]` attribute in the
# node configuration, `elasticsearch/settings` data bag, role/environment definition, etc:
#
#     // ...
#     'threadpool.index.type' => 'fixed',
#     'threadpool.index.size' => '2'
#     // ...
#
