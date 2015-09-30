# deploy_artifact [![Circle CI](https://circleci.com/gh/rackspace-cookbooks/deploy_artifact/tree/master.svg?style=svg)](https://circleci.com/gh/rackspace-cookbooks/deploy_artifact/tree/master)

## Overview

This cookbook provides a simple `deploy_artifact` resource that will deploy a single binary or tar.gz file. The deployment process is designed to mirror the [Deploy Resource](https://docs.chef.io/resource_deploy.html) except designed to be used only for local deployments and not GIT. It is assumed that a directory called `cached-copy` will already contain the contents of what is to be deployed. It is left up to you on how to deliver the artifact while the resource will do the work to deploy it.

Given a `file` location and `path`, the resource will:
- Create a directory structure:
```
path\
    cached-copy\
    releases\
        <CHECKSUM>\
    current -> releases\<CHECKSUM>
```
- Assume the `file` is a single binary or gziped tar file
- Create a releases directory and release directory named as the MD5 checksum of the deployed `file` in `path`
- On successful completion, symlink the release directory `releases\<CHECKSUM>` to `path\current`

## Resources\Providers

- `deploy_artifact` - performs deployment of a local artifact on a server

## Actions
- `deploy`: default action, will deploy a given `file` to a given `path`

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
