require 'chef/provider/lwrp_base'
require 'chef/digester'
require 'fileutils'

class Chef
  class Provider
    # Chef Provider class for deploy_artifact
    class DeployArtifact < Chef::Provider::LWRPBase
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
        cached_dir = ::File.join(new_resource.path, 'cached-copy')
        releases_dir = ::File.join(new_resource.path, 'releases')
        cached_copy = ::File.join(cached_dir, new_resource.file)
        cached_checksum = Chef::Digester.generate_md5_checksum_for_file(cached_copy)
        release_directory = ::File.join(releases_dir, cached_checksum)

        do_mkdir(cached_dir)
        do_mkdir(releases_dir)
        do_mkdir(release_directory)

        do_deploy_cached(release_directory, cached_checksum, cached_copy)

        untar(cached_copy, release_directory)

        do_before_symlink(new_resource.before_symlink)

        symlink_current(::File.join(new_resource.path, new_resource.file), release_directory)

        if new_resource.restart_command.is_a?(Proc)
          Chef::Log.info("#{new_resource} running restart_command as embedded recipe")
          converge_by('running restart_command') do
            recipe_eval(&new_resource.restart_command)
          end
        end

        check_old_releases(releases_dir)
      end

      def do_mkdir(directory)
        return false if ::File.exist?(directory)
        Chef::Log.info("#{new_resource} Creating directory - #{directory}")
        converge_by("create directory #{directory}") do
          FileUtils.mkdir_p(directory)
        end
      end

      def do_before_symlink(callback)
        return false unless callback.is_a?(Proc)
        Chef::Log.info("#{new_resource} running before_symlink as embedded recipe")
        converge_by('running before_symlink callback') do
          recipe_eval(&new_resource.before_symlink)
        end
        new_resource.updated_by_last_action(true)
      end

      def check_old_releases(releases_dir)
        old_releases = ::Dir.entries(releases_dir).sort_by { |a| ::File.mtime(::File.join(releases_dir, a)) }
        Chef::Log.info("#{new_resource} old_releases #{old_releases}")
      end

      def symlink_current(current_file, release_directory)
        return false unless ::File.exist?(release_directory)
        current_release = ::File.join(release_directory, new_resource.file)
        cur_rel_checksum = Chef::Digester.generate_md5_checksum_for_file(current_release)

        if ::File.exist?(current_file)
          old_checksum = Chef::Digester.generate_md5_checksum_for_file(current_file)
          unless cur_rel_checksum == old_checksum
            Chef::Log.info("#{new_resource} - removing old current symlink #{old_checksum}")
            converge_by("removing old current release #{old_checksum}") do
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

        # TODO: Rollback
        return false if ::File.exist?(current_file)
        Chef::Log.info("#{new_resource} - creating symlink for current release #{cur_rel_checksum}")
        converge_by("linking new release #{cur_rel_checksum} as current") do
          ::File.symlink(current_release, current_file)
        end
        new_resource.updated_by_last_action(true)
      end

      def do_deploy_cached(release_directory, cached_checksum, cached_copy)
        return false unless ::File.exist?(cached_copy)
        release_file = ::File.join(release_directory, new_resource.file)
        Chef::Log.info("#{new_resource} - found current cached release - #{cached_checksum}")

        if ::File.exist?(release_file)
          release_checksum = Chef::Digester.generate_md5_checksum_for_file(release_file)
          return false if release_checksum == cached_checksum
          Chef::Log.info("#{new_resource} - removing non-matching release to re-deploy")
          converge_by("removing non-matching release #{release_checksum}") do
            ::File.unlink(release_file)
          end
        end

        Chef::Log.info("#{new_resource} - copying cached file #{cached_checksum} into release directory")
        converge_by("copy cached file #{cached_checksum} to release directory #{release_directory}") do
          FileUtils.cp(cached_copy, release_directory)
        end
        new_resource.updated_by_last_action(true)
      end

      def untar(file, destination)
        return false unless File.extname(file) == 'tar.gz'
        Zlib::GzipReader.wrap(file) do |io|
          Gem::Package::TarReader.new(io) do |tar|
            tar.each do |tarfile|
              destination_file = File.join(destination, tarfile.full_name)

              File.open destination_file, 'wb' do |f|
                f.print tarfile.read
              end
            end
          end
        end
      end
    end
  end
end
