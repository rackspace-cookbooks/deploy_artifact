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
        @current_resource.before_symlink(new_resource.before_symlink)
        @current_resource.restart_command(new_resource.restart_command)
        @current_resource
      end

      action :deploy do
        do_mkdir(cached_directory)
        do_mkdir(releases_directory)
        do_mkdir(release_directory)

        do_deploy_cached
        do_before_symlink
        remove_stale_symlink
        symlink_current
        do_restart_command

        check_old_releases
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

      def cached_directory
        ::File.join(new_resource.path, 'cached-copy')
      end

      def cached_file
        ::File.join(cached_directory, new_resource.file)
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
        # TODO: calculate archive targz
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
        old_releases = ::Dir.entries(releases_directory).sort_by do |a|
          ::File.mtime(::File.join(releases_directory, a))
        end
        Chef::Log.info("#{new_resource} old_releases #{old_releases}")
      end

      def symlink_current
        return if ::File.exist?(current_file)
        Chef::Log.info("#{new_resource} - creating symlink for current release #{release_file_checksum}")
        converge_by("linking new release #{release_file_checksum} as current") do
          ::File.symlink(release_file, current_file)
        end
        new_resource.updated_by_last_action(true)
      end

      def remove_stale_symlink
        return unless ::File.exist?(release_directory)
        if ::File.exist?(current_file)
          unless release_file_checksum == current_file_checksum
            Chef::Log.info("#{new_resource} - removing old current")
            converge_by('removing old current') do
              ::File.unlink(current_file)
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

      # If release directory is present, see if it does not match and remove to re-deploy
      def check_if_released
        return unless compare?(cached_file, release_file)

        Chef::Log.info("#{new_resource} - removing non-matching release to re-deploy")
        converge_by("removing non-matching release #{release_file_checksum}") do
          ::File.unlink(release_file)
        end
      end

      def compare?(old_file, new_file)
        if targz?
          ::File.open(old_file, 'rb') do |file|
            ::Zlib::GzipReader.wrap(file) do |io|
              ::Gem::Package::TarReader.new(io) do |tar|
                tar.each do |tarfile|
                  return false unless ::Dir.entries(new_file).include?(tarfile)
                end
              end
            end
          end
        else
          return if ::File.directory?(new_file)
          new_checksum = Chef::Digester.generate_md5_checksum_for_file(new_file)
          old_checksum = Chef::Digester.generate_md5_checksum_for_file(old_file)
          return new_checksum == old_checksum
        end
      end

      def do_release
        return if compare?(cached_file, release_file)
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
        return unless targz?
        ::File.open(cached_copy, 'rb') do |file|
          ::Zlib::GzipReader.wrap(file) do |io|
            ::Gem::Package::TarReader.new(io) do |tar|
              tar.each do |tarfile|
                destination_file = ::File.join(destination, tarfile.full_name)
                if tarfile.directory? # Create directory
                  ::FileUtils.mkdir_p(destination_file, mode: tarfile.header.mode, verbose: false)
                  ::FileUtils.chown(get_uid(tarfile), get_gid(tarfile), destination_file)
                elsif tarfile.file? # Create file
                  ::File.open destination_file, 'wb' do |f|
                    f.write tarfile.read
                  end
                  ::FileUtils.chmod(tarfile.header.mode, destination_file, verbose: false)
                  ::FileUtils.touch(destination_file, mtime: tarfile.header.mtime)
                  ::FileUtils.chown(get_uid(tarfile), get_gid(tarfile), destination_file)
                elsif tarfilee.header.typeflag == '2' # Create symlink!
                  ::File.symlink tarfile.header.linkname, destination_file
                end
              end
            end
          end
        end
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
    end
  end
end
