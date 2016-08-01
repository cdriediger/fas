#!/usr/bin/ruby

require 'dante'
require 'yaml'
require './lib/fas-server.rb'

$server_config_path = File.absolute_path("./etc/config_server.yaml")
$server_config = YAML.load_file($server_config_path)
$server_role = $server_config['server_role']


def start
  ARGV[0] = "-d"
  if $server_config.has_key?('logfile')
    ARGV[1] = "-l"
    ARGV[2] = $server_config['logfile']
  end
end

def kill
  ARGV[0] = "-k"
end

def run_server
  puts("ServerName: FasServerd")
  Dante.run('FasServerd') do
    fas_server = FasServer.new($server_config_path)
    fas_server.run
  end
end

puts "Usage: #{File.absolute_path(File.dirname(__FILE__))}#{__FILE__[1..-1]} {start|stop|restart|run}" if ARGV.empty?

if ARGV[0] == 'start'
  start
  run_server
elsif ARGV[0] == 'stop'
  kill
  run_server
elsif ARGV[0] == 'restart'
  kill
  run_server
  sleep(1)
  start
  run_server
elsif ARGV[0] == 'run'
  fas_server = FasServer.new($server_config_path)
  fas_server.run
end
