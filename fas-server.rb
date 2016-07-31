#! /usr/bin/ruby

require 'json'
require 'socket'
require 'timeout'
require 'yaml'
require 'rufus/scheduler'
require './server_reciver.rb'
require './router.rb'
require './server_clients.rb'
require './plugins.rb'
require './server_slaves.rb'
require './fas-protocol.rb'
require './logger.rb'

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
    @slaves = Slaves.new
    @routingtable.add_signals({'register'=>@clients.method(:register),
                               'ping reply'=>@clients.method(:input_ping_reply),
                               'become master'=>method(:become_master),
                               'client offline'=>@clients.method(:set_offline),
                               'require plugin'=>@clients.method(:send_plugin)})
    @routingtable.add_relay_signal('register')
    
    puts '--------------'
    @routingtable.each_pair {|signal, action| puts "#{signal} -> #{action}"}
    puts '--------------'
    @router = Router.new(@routingtable, @clients, @slaves)
    @loopback = Loopback.new(@router)
  end

  def run
    @reciver = ServerReciver.new($server_ip, $server_port, @router)
    @reciver.run
    @plugins = Plugins.new(@routingtable, @config, @loopback)
    @routingtable.add_config_actionlists
    @routingtable.add_config_inputs 
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

  def become_master(id, data)
    puts("!! Becoming master !!")
    puts "|#{id}|#{data}|"
    begin
      kill_socket = TCPSocket.new(@master_server_ip, @master_server_port.to_i + 1)
      kill_socket.puts(JSON.generate([@config['shared_secret'], 'stonith']))
      kill_socket.close
    rescue Errno::ECONNREFUSED => e
      puts("Can not connect STONITH Daemon\nError: #{e}")
    end
    $server_role = 'master'
  end

end