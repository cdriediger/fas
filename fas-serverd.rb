#!/usr/bin/ruby

require 'dante'
require 'yaml'
#require 'json'
require './lib/fas-server.rb'

$server_config_path = File.absolute_path("./etc/config_server.yaml")
$server_config = YAML.load_file($server_config_path)
$server_role = $server_config['server_role']


#module STONITH
#
#  def self.run
#    Thread.abort_on_exception=true
#    ip = $server_config['server_ip']
#    port = $server_config['server_port'].to_i + 1
#    secet = $server_config['shared_secret']
#    @server = TCPServer.new(ip, port)
#    loop do
#      Thread.start(@server.accept) do |client|
#        puts "New Client connected: #{client}"
#        while recived_data = client.gets
#          data = JSON.parse(recived_data)
#          if data[0] == secet and data[1] == 'stonith'
#            puts "Got STONITH Signal"
#            puts "Killing fas-server.."
#            kill
#            run_server
#            kill
#            run_stonith
#          end
#        end
#      end
#    end
#  end
#
#end

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
  puts("ServerName: FasServerd_#$server_role")
  Dante.run('FasServerd' + $server_role) do
    fas_server = FasServer.new($server_config_path)
    fas_server.run
  end
end

#def run_stonith
#  ARGV[2] = $server_config['logfile'] + "_stonith"
#  Dante.run('FasServerdStonith') do
#    STONITH::run
#  end
#end

puts "Usage: #{File.absolute_path(File.dirname(__FILE__))}#{__FILE__[1..-1]} {start|stop|restart|run}" if ARGV.empty?

if ARGV[0] == 'start'
  start
  run_server
  #if $server_role == 'master'
  #  start
  #  run_stonith
  #end
elsif ARGV[0] == 'stop'
  kill
  run_server
  #if $server_role == 'master'
  #  kill
  #  run_stonith
  #end
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
