# Download sample wordpress install and deploy using deploy_file callback
path = '/var/keep_releases'
file = 'keep_releases.tar.gz'

deploy_artifact file do
  path path
  keep_releases false
  action :deploy
  deploy_file do
    remote_file ::File.join(path, 'cached-copy', file) do
      source 'https://wordpress.org/latest.tar.gz'
      owner 'root'
      group 'root'
      mode '0755'
      action :create
    end
  end
end
