# Download sample wordpress install and deploy using deploy_file callback
path = '/var/cache_path'
file = 'cache_path.tar.gz'
cache_path = '/tmp'

deploy_artifact file do
  path path
  cache_path cache_path
  action :deploy
  deploy_file do
    remote_file "#{cache_path}/#{file}" do
      source 'https://wordpress.org/latest.tar.gz'
      owner 'root'
      group 'root'
      mode '0755'
      action :create
    end
  end
end
