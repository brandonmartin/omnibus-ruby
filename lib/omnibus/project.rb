#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#
# omnibus project dsl reader
#

module Omnibus
  class Project
    include Rake::DSL

    NULL_ARG = Object.new

    attr_reader :dependencies

    def self.load(filename)
      new(IO.read(filename), filename)
    end

    def self.all_projects
      @@projects ||= []
    end

    def initialize(io, filename)
      @exclusions = Array.new
      @runtime_dependencies = Array.new
      instance_eval(io)
      render_tasks
    end

    def name(val=NULL_ARG)
      @name = val unless val.equal?(NULL_ARG)
      @name
    end

    def package_name(val=NULL_ARG)
      @package_name = val unless val.equal?(NULL_ARG)
      @package_name.nil? ? @name : @package_name
    end

    def install_path(val=NULL_ARG)
      @install_path = val unless val.equal?(NULL_ARG)
      @install_path
    end

    def iteration
      if platform_family == 'rhel'
        platform_version =~ /^(\d+)/
        maj = $1
        return "#{build_iteration}.el#{maj}"
      end
      return "#{build_iteration}.#{platform}.#{platform_version}"
    end

    def description(val=NULL_ARG)
      @description = val unless val.equal?(NULL_ARG)
      @description
    end

    def replaces(val=NULL_ARG)
      @replaces = val unless val.equal?(NULL_ARG)
      @replaces
    end

    def build_version(val=NULL_ARG)
      @build_version = val unless val.equal?(NULL_ARG)
      @build_version
    end

    def build_iteration(val=NULL_ARG)
      @build_iteration = val unless val.equal?(NULL_ARG)
      @build_iteration
    end

    def dependencies(val)
      @dependencies = val
    end

    def runtime_dependencies(val)
      @runtime_dependencies = val
    end

    def exclude(pattern)
      @exclusions << pattern
    end

    def platform_version
      OHAI.platform_version
    end

    def platform
      OHAI.platform
    end

    def platform_family
      OHAI.platform_family
    end

    def config
      Omnibus.config
    end

    def package_scripts_path
      "#{Omnibus.root}/package-scripts/#{name}"
    end

    def package_types
      case platform_family
      when 'debian'
        [ "deb" ]
      when 'fedora', 'rhel'
        [ "rpm" ]
      when 'solaris2'
        [ "solaris" ]
      else
        [ "makeself" ]
      end
    end

    private

    def fpm_command(pkg_type)
      command_and_opts = ["fpm",
                          "-s dir",
                          "-t #{pkg_type}",
                          "-v #{build_version}",
                          "-n #{package_name}",
                          "--iteration #{iteration}",
                          install_path,
                          "-m 'Opscode, Inc.'",
                          "--description 'The full stack of #{@name}'",
                          "--url http://www.opscode.com"]
      if File.exist?("#{package_scripts_path}/postinst")
        command_and_opts << "--post-install '#{package_scripts_path}/postinst'"
      end
      # solaris packages don't support --pre-uninstall
      if File.exist?("#{package_scripts_path}/prerm") && pkg_type != "solaris"
        command_and_opts << "--pre-uninstall '#{package_scripts_path}/prerm'"
      end
      # solaris packages don't support --post-uninstall
      if File.exist?("#{package_scripts_path}/postrm") && pkg_type != "solaris"
        command_and_opts << "--post-uninstall '#{package_scripts_path}/postrm'"
      end

      @exclusions.each do |pattern|
        command_and_opts << "--exclude '#{pattern}'"
      end

      @runtime_dependencies.each do |runtime_dep|
        command_and_opts << "--depends '#{runtime_dep}'"
      end

      command_and_opts << " --replaces #{@replaces}" if @replaces
      command_and_opts
    end

    def makeself_command
      command_and_opts = [ File.expand_path(File.join(Omnibus.gem_root, "bin", "makeself.sh")),
                           "--gzip",
                           install_path,
                           "#{package_name}-#{build_version}_#{iteration}.sh",
                           "'The full stack of #{@name}'"
                         ]
      command_and_opts << "./makeselfinst" if File.exists?("#{package_scripts_path}/makeselfinst")
      command_and_opts
    end

    def render_tasks
      directory config.package_dir
      directory "pkg"

      namespace :projects do

        package_types.each do |pkg_type|
          namespace @name do
            desc "package #{@name} into a #{pkg_type}"
            task pkg_type => (@dependencies.map {|dep| "software:#{dep}"}) do

              package_commands = []
              if pkg_type == "makeself"
                # copy the makeself installer into package
                if File.exists?("#{package_scripts_path}/makeselfinst")
                  package_commands << "cp #{package_scripts_path}/makeselfinst #{install_path}/"
                end

                # run the makeself program
                package_commands << makeself_command.join(" ")

                # rm the makeself installer (for incremental builds)
                package_commands << "rm -f #{install_path}/makeselfinst"
              else # pkg_type == "fpm"
                package_commands <<  fpm_command(pkg_type).join(" ")
              end

              # run the commands
              package_commands.each do |cmd|
                puts "[project:#{name}] Executing `#{cmd}`"

                shell = Mixlib::ShellOut.new(cmd,
                                             :live_stream => STDOUT,
                                             :timeout => 3600,
                                             :cwd => config.package_dir)
                shell.run_command
                shell.error!
              end
            end

            task pkg_type => config.package_dir
            task pkg_type => "#{@name}:health_check"
          end
        end

        task "#{@name}:copy" => (package_types.map {|pkg_type| "#{@name}:#{pkg_type}"}) do
          cp_cmd = "cp #{config.package_dir}/* pkg/"
          shell = Mixlib::ShellOut.new(cp_cmd)
          shell.run_command
          shell.error!
        end
        task "#{@name}:copy" => "pkg"

        desc "package #{@name}"
        task @name => "#{@name}:copy"

        desc "run the health check on the #{@name} install path"
        task "#{@name}:health_check" do
          Omnibus::HealthCheck.run(install_path)
        end
      end
    end
  end
end
