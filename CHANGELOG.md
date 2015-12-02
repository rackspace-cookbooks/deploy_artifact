deploy_artifact CHANGELOG

1.3.0
----
- Added do_chown method to recursively change permissions to owner and group resource parameters
- Updated testing which failed if owner and group did not match

1.2.3
-----
- Fixed issue with remove_stale method failing if cached_file was not present
- Added centos 7 support

1.2.2
-----
- Fixes to fully support LongLink tar files
- Changed symlink_current method name to do_deploy_release
- Updating testing

1.2.1
-----
- Fix for LongLink and LongName detection into its own method for untar

1.2.0
-----
- Fix for compare method
- Removed check_if_released method in favor of just remove_stale
- Fix for removing stale current/releases
- Fix to do_deploy only when releases directory is empty
- Removed direct deploy to current directory when keep_releases false due to being infeasible
- Added handling of @LongLink tar entries
- Re-write untar method to be less complex adding helper methods file_open, tar_open, gzip_stream, dir_untar, file_untar, symlink_untar
- Updated testingu

1.1.1
-----
- Fix for untar function with symlinks

1.1.0
-----
- Added option keep_releases, an option which defines either how many releases to keep or to not keep
- Added option deploy_file, a callback which allows you to perform the file deployment within the resource
- Added option cache_path, an option to define a custom cache file (temp) path

1.0.0
----
Official release to supermarket

0.0.1
----
- First Version
