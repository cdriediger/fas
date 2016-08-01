#! /usr/bin/ruby

require 'json'
require 'socket'
require 'timeout'
require 'yaml'
require 'rufus/scheduler'
require './lib/server_reciver.rb'
require './lib/router.rb'
require './lib/server_clients.rb'
require './lib/plugins.rb'
require './lib/fas-protocol.rb'
require './lib/logger.rb'

class FasServer

  def initialize(server_config_file)
    $Log = Log.new('server_log')
    $Log.level = Logger::DEBUG
    $Log.info('Start FasServer')
    $role = "server"
    Thread.abort_on_exception=true
    @config = YAML.load_file(server_config_file)
    $Log.info("Loading ServerConfig from #{server_config_file}")
    site_config_path = File.absolute_path(@config['site_config'])
    @site_config = YAML.load_file(site_config_path)
    $Log.info("Loading SiteConfig from #{site_config_path}")
    if @config.has_key?('server_ip')
      $server_ip = @config['server_ip']
      $Log.info("Using IP: #{@config['server_ip']}")
    else
      $Log.fatal_error("No Server IP configured in ServerConfig")
    end
    if @config.has_key?('server_port')
      $server_port = @config['server_port'].to_i
      $Log.info("Using Port: #{@config['server_port']}")
    else
      $server_port = 20000
      $Log.info("No Server IP configured. Using 20000")
    end
    @routingtable = RoutingTable.new(@site_config)
    @clients = Clients.new(@site_config)
    @routingtable.set_clients(@clients)
    @routingtable.add_signals({'register'=>@clients.method(:register),
                               'ping reply'=>@clients.method(:input_ping_reply),
                               'client offline'=>@clients.method(:set_offline),
                               'require plugin'=>@clients.method(:send_plugin)})
    puts '--------------'
    @routingtable.each_pair {|signal, action| puts "#{signal} -> #{action}"}
    puts '--------------'
    @router = Router.new(@routingtable, @clients)
    @loopback = Loopback.new(@router)
    @plugins = Plugins.new(@routingtable, @config, @loopback)
    @routingtable.add_config_actionlists
    @routingtable.add_config_inputs
    @reciver = ServerReciver.new($server_ip, $server_port, @router)
  end

  def run
    @reciver.run
    exit_requested = false
    Kernel.trap( "SIGTERM" ) { exit_requested = true }
    Kernel.trap( "INT" ) { exit_requested = true }
    until exit_requested
      sleep(1)
    end
    $Log.info("Exiting FasServer")
    @clients.server_offline
    @reciver.close
  end

end