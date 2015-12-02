require 'chef/provider/lwrp_base'
require 'chef/digester'
require 'fileutils'
require 'etc'

class Chef
  class Provider
    # Chef Provider class for deploy_artifact
    class DeployArtifact < Chef::Provider::LWRPBase # rubocop:disable Metrics/ClassLength
      use_inline_resources if defined?(:use_inline_resources)

      def load_current_resource
        @current_resource ||= Chef::Resource::DeployArtifact.new(new_resource.name)
        @current_resource.file(new_resource.file)
        @current_resource.path(new_resource.path)
        @current_resource.owner(new_resource.owner)
        @current_resource.group(new_resource.group)
        @current_resource.cache_path(new_resource.cache_path)
        @current_resource.deploy_file(new_resource.deploy_file)
        @current_resource.keep_releases(new_resource.keep_releases)
        @current_resource.before_symlink(new_resource.before_symlink)
        @current_resource.restart_command(new_resource.restart_command)
        @current_resource
      end

      action :deploy do
        remove_stale

        do_mkdir(cache_path)
        do_deploy_file

        do_mkdir(releases_directory)
        do_mkdir(release_directory)

        do_deploy_cached
        do_deploy_release

        check_old_releases
      end

      def cache_path
        current_resource.cache_path || ::File.join(new_resource.path, 'cached-copy')
      end

      def releases_directory
        ::File.join(new_resource.path, 'releases')
      end

      def release_directory
        ::File.join(releases_directory, cached_checksum)
      end

      def cached_checksum
        Chef::Digester.generate_md5_checksum_for_file(cached_file)
      end

      def cached_file
        ::File.join(cache_path, new_resource.file)
      end

      def release_file
        targz? ? release_directory : ::File.join(release_directory, new_resource.file)
      end

      def current_file
        filename = targz? ? 'current' : new_resource.file
        ::File.join(new_resource.path, filename)
      end

      def current_file_checksum
        targz? ? release_file_checksum : Chef::Digester.generate_md5_checksum_for_file(current_file)
      end

      def release_file_checksum
        if targz?
          ::File.basename(release_directory)
        else
          Chef::Digester.generate_md5_checksum_for_file(release_file)
        end
      end

      def do_mkdir(directory)
        return false if ::File.exist?(directory)
        Chef::Log.info("#{new_resource} Creating directory - #{directory}")
        converge_by("create directory #{directory}") do
          FileUtils.mkdir_p(directory)
        end
      end

      def do_chown(directory)
        return unless ::File.exist?(directory)
        Chef::Log.info("#{new_resource} Changing permissions to #{new_resource.owner}:#{new_resource.group}
                       on #{directory} recursively")
        converge_by("changing ownership for #{directory} recursively") do
          FileUtils.chown_R(new_resource.owner, new_resource.group, directory)
        end
      end

      def do_deploy_file
        callback = new_resource.deploy_file
        return false unless callback.is_a?(Proc)
        Chef::Log.info("#{new_resource} running deploy_file as embedded recipe")
        converge_by('running deploy_file callback') do
          recipe_eval(&new_resource.deploy_file)
        end
        new_resource.updated_by_last_action(true)
      end

      def do_before_symlink
        callback = new_resource.before_symlink
        return false unless callback.is_a?(Proc)
        Chef::Log.info("#{new_resource} running before_symlink as embedded recipe")
        converge_by('running before_symlink callback') do
          recipe_eval(&new_resource.before_symlink)
        end
        new_resource.updated_by_last_action(true)
      end

      def do_restart_command
        callback = new_resource.restart_command
        return false unless callback.is_a?(Proc)
        Chef::Log.info("#{new_resource} running restart_command as embedded recipe")
        converge_by('running restart_command') do
          recipe_eval(&new_resource.restart_command)
        end
        new_resource.updated_by_last_action(true)
      end

      def check_old_releases
        return unless current_resource.keep_releases
        old_releases = ::Dir.entries(releases_directory).sort_by do |a|
          ::File.mtime(::File.join(releases_directory, a))
        end
        Chef::Log.info("#{new_resource} old_releases #{old_releases}")
      end

      def do_deploy_release
        return if ::File.exist?(current_file)
        do_before_symlink
        do_chown(release_file)
        Chef::Log.info("#{new_resource} - creating symlink for current release #{release_file_checksum}")
        converge_by("linking new release #{release_file_checksum} as current") do
          ::File.symlink(release_file, current_file)
        end
        do_restart_command
        new_resource.updated_by_last_action(true)
      end

      def remove_stale
        if ::File.exist?(current_file) && ::File.exist?(cached_file)
          unless compare?(cached_file, current_file)
            Chef::Log.info("#{new_resource} - removing non-matching release to re-deploy")
            converge_by('removing non-matching release to re-deploy') do
              FileUtils.remove_entry_secure(current_file)
            end
            new_resource.updated_by_last_action(true)
          end
        elsif ::File.symlink?(current_file)
          Chef::Log.info("#{new_resource} - removing stale current symlink #{current_file}")
          converge_by('removing stale symlink') do
            ::File.unlink(current_file)
          end
        end
      end

      def do_deploy_cached
        return false unless ::File.exist?(cached_file)
        Chef::Log.info("#{new_resource} - found current cached release - #{cached_checksum}")

        do_release
        new_resource.updated_by_last_action(true)
      end

      def compare?(old_file, new_file)
        old_checksum = Chef::Digester.generate_md5_checksum_for_file(old_file)
        if ::File.symlink?(new_file)
          return ::File.fnmatch("*/#{old_checksum}", ::File.readlink(new_file))
        else
          return false if ::File.directory?(new_file)
          new_checksum = Chef::Digester.generate_md5_checksum_for_file(new_file)
          return new_checksum == old_checksum
        end
      end

      def _compare_tar?(tarfile)
        targz(tarfile).each do |entry|
          dest_file = entry.header.typeflag == ('L' || 'K') ? entry.read.strip : entry.full_name
          dest = ::File.join(new_file, dest_file)
          return false unless ::File.exist?(dest)
        end
        true
      end

      def do_release
        return unless (::Dir.entries(release_directory) - %w( . .. )).empty?
        if targz?
          Chef::Log.info("#{new_resource} - untaring cached file #{cached_checksum} into release directory")
          converge_by("untaring cached file #{cached_checksum} to release directory #{release_directory}") do
            untar(cached_file, release_directory)
          end
        else
          Chef::Log.info("#{new_resource} - copying cached file #{cached_checksum} into release directory")
          converge_by("copy cached file #{cached_checksum} to release directory #{release_directory}") do
            FileUtils.cp(cached_copy, release_directory)
          end
        end
      end

      def untar(cached_copy, destination)
        dest = nil
        targz(cached_copy).each do |entry|
          dest ||= ::File.join(destination, entry.full_name)
          case entry.header.typeflag
          when '0'
            untar_file(entry, dest)
          when '5'
            untar_dir(entry, dest)
          when '2'
            untar_symlink(entry, dest)
          when 'L', 'K'
            dest = ::File.join(destination, entry.read.strip)
            next
          else
            puts "Unkown tar entry: #{entry.full_name} type: #{entry.header.typeflag}."
          end
          dest = nil
        end
      end

      def file_open(tarfile)
        ::File.open(tarfile, 'rb')
      rescue StandardError => e
        Chef::Log.warn e.message
        raise e
      end

      def tar_open(tarfile)
        Gem::Package::TarReader.new(tarfile)
      rescue Gem::Package::TarInvalidError
        return false
      end

      def gzip_stream(file)
        Zlib::GzipReader.new(file_open(file))
      rescue Zlib::GzipFile::Error
        file.rewind
        file_open(file)
      end

      def untar_dir(entry, dest)
        ::File.delete(dest) if ::File.file?(dest)
        ::FileUtils.mkdir_p(dest, mode: entry.header.mode, verbose: false)
        ::FileUtils.chown(get_uid(entry), get_gid(entry), dest)
      end

      def untar_file(entry, dest)
        ::FileUtils.rm_rf(dest) if ::File.directory?(dest)
        ::File.open dest, 'wb' do |f|
          f.write entry.read
        end
        ::FileUtils.chmod(entry.header.mode, dest, verbose: false)
        ::FileUtils.touch(dest, mtime: entry.header.mtime)
        ::FileUtils.chown(get_uid(entry), get_gid(entry), dest)
      end

      def untar_symlink(entry, dest)
        ::File.symlink(entry.header.linkname, dest)
      end

      def get_uid(file)
        return ::Etc.getpwnam(file.header.uname).name.split(/,/).first
      rescue ArgumentError
        return file.header.uid
      end

      def get_gid(file)
        return ::Etc.getgrnam(file.header.gname).name.split(/,/).first
      rescue ArgumentError
        return file.header.gid
      end

      def targz?
        ::File.fnmatch('*.tar.gz', new_resource.file)
      end

      def targz(file)
        tar_open(gzip_stream(file))
      end
    end
  end
end
