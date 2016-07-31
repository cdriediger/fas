#!/usr/bin/ruby

require 'dante'
require 'yaml'
require './fas-client.rb'

def start
  ARGV[0] = "-d"
  configfilepath = File.absolute_path("./config_client.yaml")
  if File.exist?(configfilepath)
    config = YAML.load_file(configfilepath)
    if config.has_key?('logfile')
      ARGV[1] = "-l"
      ARGV[2] = config['logfile']
    end
  end
end

def kill
  ARGV[0] = "-k"
end

def run
  Dante.run('FasClient') do
    FasClient::run
  end
end

if ARGV[0] == 'start'
  start
  run
elsif ARGV[0] == 'stop'
  kill
  run
elsif ARGV[0] == 'restart'
  kill
  run
  start
end
