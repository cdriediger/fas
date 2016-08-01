#!/usr/bin/ruby

require 'dante'
require 'yaml'
require './lib/fas-client.rb'

$client_config_path = File.absolute_path("./etc/config_client.yaml")
if File.exist?($client_config_path)
  $client_config = YAML.load_file($client_config_path)
else
  puts "Client config not found at: #{$client_config_path}"
  Kernel.exit!
end

def set_start
  ARGV[0] = "-d"
  if $client_config.has_key?('logfile')
    ARGV[1] = "-l"
    ARGV[2] = $client_config['logfile']
  end
end

def set_stop
  ARGV[0] = "-k"
end

def daemonize
  Dante.run('FasClientd') do
    do_start
  end
end

def do_start
  fas_client = FasClient.new($client_config_path)
  fas_client.run
end

puts "Usage: #{File.absolute_path(File.dirname(__FILE__))}#{__FILE__[1..-1]} {start|stop|restart|run}" if ARGV.empty?

if ARGV[0] == 'start'
  set_start
  run
elsif ARGV[0] == 'stop'
  set_stop
  daemonize
elsif ARGV[0] == 'restart'
  set_stop
  daemonize
  sleep(1)
  set_start
  daemonize
elsif ARGV[0] == 'run'
  do_start
end