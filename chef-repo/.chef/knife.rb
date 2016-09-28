chef_server_url 'https://54.213.73.141/organizations/intersys'
client_key 'jpatton.pem'
validation_key 'intersys-validator.pem'
ssl_verify_mode :verify_none
node_name 'jpatton'
cookbook_path ['cookbooks']
versioned_cookbooks true
data_bag_encrypt_version 2
