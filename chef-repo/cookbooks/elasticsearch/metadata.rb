name 'elasticsearch'
maintainer 'Jason Patton'
maintainer_email 'jpatton@intersysconsulting.com'
license 'all_rights'
description 'Installs/Configures elasticsearch'
long_description 'Installs/Configures elasticsearch'
version '2.3.4'

depends 'java'

provides "elasticsearch::client"
provides "elasticsearch::data"
provides "elasticsearch::master"

supports 'centos', '>= 6.2'
supports 'redhat', '>= 6.2'
supports 'oracle', '>= 6.2'
supports 'suse', '>= 6.2'