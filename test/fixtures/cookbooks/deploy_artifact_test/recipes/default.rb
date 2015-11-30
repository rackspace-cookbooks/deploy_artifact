# Created expected directory
%w(
  /var/www
  /var/www/cached-copy
).each do |dir|
  directory dir
end

# Download sample wordpress install
remote_file '/var/www/cached-copy/latest.tar.gz' do
  source node['deploy_artifact_test']['targz']
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

deploy_artifact 'latest.tar.gz' do
  path '/var/www'
  action :deploy
end
