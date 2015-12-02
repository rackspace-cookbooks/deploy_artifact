# deploy_artifact [![Circle CI](https://circleci.com/gh/rackspace-cookbooks/deploy_artifact/tree/master.svg?style=svg)](https://circleci.com/gh/rackspace-cookbooks/deploy_artifact/tree/master)

## Overview

#### Supports and Tested Against
- CentOS 6.7
- CentOS 7.1
- Ubuntu 12.04 LTS
- Ubuntu 14.04 LTS

This cookbook provides a simple `deploy_artifact` resource that will deploy a single binary or tar.gz file. The deployment process is designed to mirror the [Deploy Resource](https://docs.chef.io/resource_deploy.html) except designed to be used only for local deployments and not GIT. It is assumed that a directory called `cached-copy` will already contain the contents of what is to be deployed if not configured. It is left up to you on how to deliver the artifact using the while the resource will do the work to deploy it. The resource determines whether a file should be deployed or not based off of the current `cached-copy` checksum and the current release directory checksum name. Mac PAX format tar files are not supported at this time.

Given a `file` location and `path`, the resource will by default:
- Create a directory structure:
```
path\
    cached-copy\
    releases\
        <CHECKSUM>\
    current -> releases\<CHECKSUM>
```
- Assume the `file` is a single binary, gziped gnu-tar or gnu-tar file
- Create a `cached-copy` directory and expect the `file` to be present or use the `deploy_file` callback to create `file`.
- Create a releases directory and release directory named as the MD5 checksum of the deployed `file` in `path`.
- On successful completion, symlink the release directory `releases\<CHECKSUM>` to `path\current`.

## Resources\Providers

- `deploy_artifact` - performs deployment of a local artifact on a server

## Actions
- `deploy`: default action, will deploy a given `file` to a given `path`

### :deploy

#### Resource Parameters for :deploy
- `name` : defaults to `file` parameter
- `file` : path to binary or `tar.gz` file to deploy, Required
- `path` : path to location to deploy to, Default: `/opt`
- `owner` : owner of the deployed files, Default: root
- `group` : group of the deployed files, Default: root
- `cache_path` : path to cache latest deployed file, Default: `{path}/cached-copy`
- `keep_releases` : number of releases to keep or `false` to keep none, Default: 5
- `deploy_file` : callback which takes a Ruby block of code to execute and deploy a file which is expected to be in `cache_path`.
- `before_symlink` : callback which takes a Ruby block of code to execute before symlinking a release to current, Default: nothing
- `restart_command` : callback which takes a Ruby block of code to execute after symlinkinga release to current which can be used to restart applications if needed, Default: nothing

#### Methods Available for Callbacks
Within a Ruby block used with one of the provided callbacks, you may use the following methods to determine path or files you may wish to act on. From a library perspective, they are resource values compiled during the resource execution, not from before or after.
- `cache_path` : path being used to deploy from
- `cached_file` : path of file calculated from `file` parameter and `cache_path` method
- `cached_checksum` : calculated checksum of `cached_file`
- `releases_directory` : path of parent releases directory calculated by appending `releases` to `path` paramter
- `release_directory` : path of current release being deployed from `releases_directory` and `cached_checksum`

## Examples

### Deploy tarball from Rackspace Cloud Files

```
deploy_artifact 'deploy.tar.gz' do
  path '/var/www/app'
  action :deploy
  deploy_file do
    rackspacecloud_file '/var/www/app/cached-copy/deploy.tar.gz' do
      directory 'deploy.tar.gz'
      rackspace_username 'username'
      rackspace_api_key 'api_key'
      rackspace_region 'dfw'
      action :create
    end
  end
end
```

### Deploy tarball and restart service
```
deploy_artifact 'deploy.tar.gz' do
  path '/var/www/app'
  action :deploy
  deploy_file do
    rackspacecloud_file '/var/www/app/cached-copy/deploy.tar.gz' do
      directory 'deploy.tar.gz'
      rackspace_username 'username'
      rackspace_api_key 'api_key'
      rackspace_region 'dfw'
      action :create
    end
  end
  restart_command do
    service 'unicorn-app' do
      action :restart
    end
  end
end
```

### Deploy tarball to a specific `cache_path`
```
deploy_artifact 'deploy.tar.gz' do
  path '/var/www/app'
  cache_path '/tmp'
  action :deploy
  deploy_file do
    rackspacecloud_file '/var/www/app/cached-copy/deploy.tar.gz' do
      directory 'deploy.tar.gz'
      rackspace_username 'username'
      rackspace_api_key 'api_key'
      rackspace_region 'dfw'
      action :create
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
