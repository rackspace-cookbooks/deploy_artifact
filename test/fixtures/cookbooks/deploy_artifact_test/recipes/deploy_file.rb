# Download sample wordpress install and deploy using deploy_file callback
path = '/var/deploy_file'
file = 'deploy_file.tar.gz'

deploy_artifact file do
  path path
  action :deploy
  deploy_file do
    remote_file "#{path}/cached-copy/#{file}" do
      source 'https://wordpress.org/latest.tar.gz'
      owner 'root'
      group 'root'
      mode '0755'
      action :create
    end
  end
end
