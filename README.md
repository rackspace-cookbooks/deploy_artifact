# deploy_artifact

## Overview

This cookbook provides a simple `deploy_artifact` resource library that will deploy a single binary or tar.gz file. The deployment process is designed to mirror the [Deploy Resource](https://docs.chef.io/resource_deploy.html) except to be used only for local deployments. It is assumed that a directory will already contain the contents of what is to be deployed and requires no knowledge on how that file is to be transferred to the client machine which is left up you to decide on.

Given a file location and path, the resource will:
- Create a directory structure:
```
path\
    cached-copy\
    releases\
        <CHECKSUM>\
    current\
```
- Assume the file is a single binary or gziped tar file
- Copy the referenced file to `path\cached-copy`
- Create a release directory named as the MD5 checksum of the deployed file
- On completion, symlink the release directory to `path\current`

## Resources\Providers

- `deploy_artifact` - performs deployment of a local artifact on a server

## Actions
- `deploy`: default action, will deploy a given file to a given path

### :deploy

#### Resource Parameters for :deploy
- `name` : defaults to `file` parameter
- `file` : path to binary or `tar.gz` file to deploy, Required
- `path` : path to location to deploy to, Required
- `owner` : owner of the deployed files, Default: root
- `group` : group of the deployed files, Default: root
- `before_symlink` : callback which takes a Ruby block of code to execute before symlinking a release to current, Default: nothing
- `restart_command` : callback which takes a Ruby block of code to execute after symlinkinga release to current which can be used to restart applications if needed, Default: nothing

## Examples

### Deploy tarball from Rackspace Cloud Files

```
rackspacecloud_file '/var/www/app/cached-copy/deploy.tar.gz' do
  directory 'deploy.tar.gz'
  rackspace_username 'username'
  rackspace_api_key 'api_key'
  rackspace_region 'dfw'
  action :create
end

deploy_artifact 'deploy.tar.gz' do
  path '/var/www/app'
  action :deploy
end
```

### Deploy tarball and restart service
```
deploy_artifact 'deploy.tar.gz' do
  path '/var/www/app'
  action :deploy
  restart_command do
    service 'unicorn-app' do
      action :restart
   end
  end
end
```

## Contributing

1. Fork the repository on Github
2. Create a named feature branch (i.e. `add-my-feature`)
3. Write your change
4. Write tests for your change (if applicable)
5. Run the tests, ensuring they all pass
6. Submit a Pull Request

## License and Authors

Authors:: Justin Seubert (justin.seubert@rackspace.com)
