require 'thor'
require 'highline'
require 'ec2ssh/ssh_config'
require 'ec2ssh/exceptions'
require 'ec2ssh/migrator'

module Ec2ssh
  class CLI < Thor
    class_option :dotfile, banner: '$HOME/.ec2ssh', default: "#{ENV['HOME']}/.ec2ssh"
    class_option :verbose, banner: 'enable debug log', default: false

    desc 'init', 'Add ec2ssh mark to ssh_config'
    def init
      check_dotfile_version
      command = make_command :init
      command.run
    rescue MarkAlreadyExists
      red "Marker already exists in #{command.ssh_config_path}"
    end

    desc 'update', 'Update ec2 hosts list in ssh_config'
    method_option :aws_key, banner: 'aws key name', default: 'default'
    def update
      check_dotfile_existence
      check_dotfile_version
      set_aws_logging
      command = make_command :update
      command.run
      green "Updated #{command.ssh_config_path}"
    rescue AwsKeyNotFound
      red "Set aws keys at #{command.dotfile_path}"
    rescue MarkNotFound
      red "Marker not found in #{command.ssh_config_path}"
      red "Execute '#{$0} init' first!"
    end

    desc 'remove', 'Remove ec2ssh mark from ssh_config'
    def remove
      check_dotfile_existence
      check_dotfile_version
      command = make_command :remove
      command.run
      green "Removed mark from #{command.ssh_config_path}"
    rescue MarkNotFound
      red "Marker not found in #{command.ssh_config_path}"
    end

    desc 'migrate', 'Migrate dotfile from old versions'
    def migrate
      command = make_command :migrate
      command.run
    end

    no_tasks do
      def check_dotfile_version
        return unless File.exist?(options.dotfile)
        migrator = Migrator.new options.dotfile
        if migrator.check_version < '3'
          red "#{options.dotfile} is old style."
          red "Try '#{$0} migrate' to migrate to version 3"
          abort
        end
      end

      def check_dotfile_existence
        unless File.exist?(options.dotfile)
          red "#{options.dotfile} doesn't exist."
          red "Try '#{$0} init' to generate it or specify the path with --dotfile option"
          abort
        end
      end

      def make_command(cmd)
        require "ec2ssh/command/#{cmd}"
        cls = eval "Ec2ssh::Command::#{cmd.capitalize}"
        cls.new(self)
      end

      def set_aws_logging
        if options.verbose
          require 'logger'
          require 'aws-sdk'
          logger = ::Logger.new($stdout)
          logger.level = ::Logger::DEBUG
          ::AWS.config logger: logger
        end
      end

      def hl
        @hl ||= ::HighLine.new
      end

      [:red,:green,:yellow].each do |col|
        define_method(col) do |str|
          puts hl.color(str, col)
        end
      end
    end
  end
end
