# Encoding: utf-8
name 'deploy_artifact'
maintainer 'Rackspace'
maintainer_email 'rackspace-cookbooks@rackspace.com'
license 'Apache 2.0'
description 'A cookbook with library to deploy local files'
issues_url 'https://github.com/rackspace-cookbooks/deploy_artifact/issues' if respond_to?(:issues_url)
source_url 'https://github.com/rackspace-cookbooks/deploy_artifact' if respond_to?(:source_url)
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version '1.3.0'

supports 'centos'
supports 'ubuntu'
