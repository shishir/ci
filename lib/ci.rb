require_relative "ci/version"
require "mixlib/cli"
require "mixlib/config"
require "mixlib/shellout"
require 'logger'
require "json"

module Ci
	class Pipeline
		def initialize(name, material, stages, options={})
			@name     = name
			@material = material
			@stages   = stages
			@logger   = options[:logger]
		end

		def run
			mkdir_p   = Mixlib::ShellOut.new("mkdir -p /tmp/#{@name}")
			@logger.info("Running mkdir -p /tmp/#{@name}")
			mkdir_p.run_command
			@logger.info(mkdir_p.stdout)
			mkdir_p.error!

			git_clone = Mixlib::ShellOut.new("git clone #{@material.repository} /tmp/#{@name}")
			@logger.info("Running git clone")
			git_clone.run_command

			@logger.info(git_clone.stdout)
			git_clone.error!
			@stages.each do |stage|
				stage.run
			end
		end


		def self.from_hash(hsh, options)
			name = hsh['name']
			working_dir = "/tmp/#{name}"
			material = Material.new(hsh['repository'])
			stages   = hsh['stages'].collect do |stage_hsh|
				Stage.from_hash(stage_hsh, working_dir, options)
			end
			Pipeline.new(name, material, stages, options)
		end
	end

	class Stage
		def initialize(name, commands, working_dir, options={})
			@name        = name
			@commands    = commands
			@working_dir = working_dir
			@logger      = options[:logger]
		end

		def run
			@commands.each do |command|
				c = Mixlib::ShellOut.new(command, :cwd => "#{@working_dir}")
				@logger.info("Running #{command}")
				c.run_command
				@logger.info(c.stdout)
				c.error!
			end
		end

		def self.from_hash(hsh, working_dir, options)
			Stage.new(hsh['name'], hsh['commands'], working_dir, options)
		end
	end

	class Material
		attr_reader :repository
		def initialize(repository)
			@repository = repository
		end
	end

	class Config
		attr_reader :pipeline
		def from_file(file_path)
			@config = JSON.parse(File.read(file_path))

			logger = Logger.new(STDOUT)
			@pipeline  = Pipeline.from_hash(@config['pipeline'], {:logger => logger})
			@pipeline.run
		end

	end

	class Cli
		include Mixlib::CLI

		option :config_file,
			:short  => "-c Config",
			:long   => "--config Config"

		option :build_directory,
			:short   => "-d directory",
			:long    => "--build-dir directory",
			:default => "/tmp"
	end
end

