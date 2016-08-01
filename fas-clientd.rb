#!/usr/bin/ruby

require 'dante'
require 'yaml'
require './lib/fas-client.rb'

$client_config_path = File.absolute_path("./etc/config_client.yaml")

def start
  ARGV[0] = "-d"
  if File.exist?($client_config_path)
    config = YAML.load_file($client_config_path)
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
