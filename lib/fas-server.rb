#! /usr/bin/ruby

# Global require
require 'json'
require 'socket'
require 'timeout'
require 'yaml'
require 'rufus/scheduler'
require './lib/server_reciver.rb'
require './lib/router.rb'
require './lib/plugins.rb'
require './lib/fas-protocol.rb'
require './lib/logger.rb'

#Server require
require 'securerandom'
require './lib/server_clients.rb'


class FasServer

  def initialize(server_config_file)
    # Start Logging
    $Log = Log.new('server_log')
    $Log.level = Logger::DEBUG
    $Log.info('Start FasServer')
    # Set role (server|client)
    $role = :server
    # Show Exception risen in Threads
    Thread.abort_on_exception=true
    
    # Load server config
    @config_path = File.absolute_path(server_config_file)
    if not File.exists?(@config_path)
      $Log.fatal_error("Could not find Config at: #{@config_path}")
    else
      @config = YAML.load_file(@config_path)
      $Log.info(@config)
      $Log.info("Loading client config from: #{@config_path}")
    end
    
    # Load site config
    @site_config_path = File.absolute_path(@config['site_config'])
    if not File.exists?(@site_config_path)
      $Log.fatal_error("Could not find Config at: #{@site_config_path}")
    else
      @site_config = YAML.load_file(@site_config_path)
      $Log.info("Loading site config from: #{@site_config_path}")
    end
    
    # get IP-Adress to listen on
    unless @config.has_key?('server_ip')
      $Log.fatal_error("No 'server_ip' found in #{@config_path}!!")
    end
    $server_ip = @config['server_ip']
    $Log.info("Going to listen on IP: #{$server_ip}")
    
    # get TCP-Port to listen on 
    if @config.has_key?('server_port')
      $server_port = @config['server_port'].to_i
    else
      $server_port = 20000
      $Log.info("No 'server_port' found in #{@config_path}")
    end
    $Log.info("Going to listen on port: #{$server_port}")
    
    # Setup clients class. Handels management of clients an comunication with clients
    @clients = Clients.new(@site_config)

    # Setup routingtable. Handels all routes
    @routingtable = RoutingTable.new(@site_config, @clients)
        
    # Adding default routes
    @routingtable.add_signals({:register=>@clients.method(:register),
                               :ping_reply=>@clients.method(:input_ping_reply),
                               :client_offline=>@clients.method(:set_offline),
                               :require_plugin=>@clients.method(:send_plugin)})
       
    # Setup Router. Rout data by signal to the correct function 
    @router = Router.new(@routingtable, @clients)
      
    # Load and configure plugins
    @plugins = Plugins.new(@routingtable, @config)
    
    # Create actionlists from config
    @routingtable.add_config_actionlists
    
    # Route input signals to actionlists
    @routingtable.add_config_inputs
    
    # Setup Reciver. Recives packages from clients an prepares them for routing
    @reciver = ServerReciver.new($server_ip, $server_port, @router)

    # Debugoutput out routingtable
    puts '--------------'
    @routingtable.each_pair do |signal, action|
      if action.is_a?(RemoteAction)
        $Log.info("#{signal.to_s} -> #{action} on #{action.client}")
        $Log.info("-> GroupMembers: #{action.client.clients}") if action.client.is_a?(ClientGroup)
      else
        $Log.info("#{signal.to_s} -> #{action}")
      end
    end
    puts '--------------'
  end

  def run
    # Start reciver thread
    @reciver.run
    
    # Setup exit variable
    exit_requested = false
    
    # Setup traps to set exit variables to true
    Kernel.trap( "SIGTERM" ) { exit_requested = true }
    Kernel.trap( "INT" ) { exit_requested = true }
    
    # Let main thread sleep unil exit is requestet via traps 
    until exit_requested
      sleep(1)
    end
    
    $Log.info("Exiting FasServer")
    
    # Inform clients about server going offline
    @clients.server_offline
    
    # Stop reciver
    @reciver.close
  end

end