#! /usr/bin/ruby

#Global require
require 'json'
require 'socket'
require 'timeout'
require 'yaml'
require 'rufus/scheduler'
require './lib/client_reciver.rb'
require './lib/router.rb'
require './lib/plugins.rb'
require './lib/fas-protocol.rb'
require './lib/logger.rb'

#Client require
require './lib/client_connection.rb'
require './lib/transmiter.rb'


class FasClient

  def initialize(client_config_file)
    # Start Logging
    $Log = Log.new('./client_log')
    $Log.level = Logger::DEBUG
    $Log.info('Start FasClient')
    # Set role (server|client)
    $role = "client"
    # Show Exception risen in Threads
    Thread.abort_on_exception=true
    
    # Load client config
    @config_path = client_config_file
    if not File.exists?(@config_path)
      $Log.fatal_error("Could not find Config at: #{@config_path}")
    else
      @config = YAML.load_file(@config_path)
      $Log.info("Loading client config from: #{@config_path}")
    end
    
    # Introduce global id variable. Gets filled by server later. Id get transmitted to server to identify the client  
    $id = nil
    
    # get IP-Adress to connect to
    unless @config.has_key?('server_ip')
      $Log.fatal_error("No server_ip found in #{@config_path}!!")
    end
    $server_ip = @config['server_ip']
    $Log.info("Going to listen to server IP: #{$server_ip}")
    
    # get TCP-Port to connect to
    if @config.has_key?('server_port')
      $server_port = @config['server_port'].to_i
    else
      $server_port = 20000
      $Log.info("No 'server_port' found in #{@config_path}")
    end
    $Log.info("Going to listen to server port: #{$server_port}")
    
    # get local IP config. IP-Address and Port is used by server to identify the client an registration. Needs to be changed!
    if @config.has_key?('local_ip')
      $local_ip = @config['local_ip']
    else
      $Log.fatal_error("'local_ip' missing in config")
    end
    if @config.has_key?('local_port')
      $local_port = @config['local_port']
    else
      $local_port = "20001"
    end
    
    # Isn't used anymore. Need to remove this
    # Set server offline after 20 seconds if not reseted by ping reply
    @server_offline_scheduler = Rufus::Scheduler.new
    
    # Setup connection to server
    $connection = Connection.new($server_ip, $server_port, $local_ip, @server_offline_scheduler, method(:restart))
    
    # Setup routingtable 
    $routingtable = RoutingTable.new
    # Adding default routes
    $routingtable.add_signals({'ping request' => self.method(:ping_replay), 
                               'client config' => self.method(:parse_config),
                               'server going offline' => $connection.method(:server_offline),
                               'restart' => self.method(:restart)})
                               
    # Array in which plugins stored there repeating jobs. Its obsolete an need to be removed
    # such jobs are now handeld by scheduler in Plugins class  
    $jobs = []
    
    # Will become true if Plugins class loaded all plugins. Is this still usefull?
    $plugins_loaded = false
    
    # Stores the number ob plugins which needs to be send from the server. Handeld by Plugins class. Maybe rehome it there
    $wait_for_plugins = 0
  end

  # Send ping peply to server. Needs to be transferd to Connection Class
  def ping_replay(ip, id)
    $Log.info("Got Ping request #{id}")
    #@server_offline_scheduler.jobs[0].unschedule
    #@server_offline_scheduler.in '20s' do
    #  $connection.server_offline
    #end
    $connection.send('ping reply', id)
  end

  # Apply config send from server
  def parse_config(ip, config)
    $Log.info("Parsing Config:")
    $Log.info("  ID: #{config['id']}"
    $Log.info("  Plugins: #{config['plugins']}"
    $Log.info("  Signals: #{config['remote_signals']}")
    
    # Set global client id
    $id = config['id']
    
    # Setup Plugins (just load plugins specified by server) 
    $plugins = Plugins.new($routingtable, config)
    
    # Add Signals supplied by server
    $Log.info("  Adding remote signals:")
    add_remote_signals(config['remote_signals'])
  end

  # Remote Signals are a Hash inside config. 
  def add_remote_signals(remote_signals)
    remote_signals.each do |signalname|
      # Split signalname into pluginname and pluginmethod
      pluginname, pluginmethodname = signalname.split('.')
      $Log.info("    Adding Remote Signal: Pluginname: #{pluginname}, Plugin Method Name: #{pluginmethodname}")
      
      # Test if plugin is loaded
      unless $plugins.has_key?(pluginname)
        $Log.error("      No such Plugin #{pluginname}") unless $plugins.has_key?(pluginname)
        return
      end
      
      # Get plugin from plugins 
      plugin = $plugins[pluginname]
      # Get method from Plugin if availeble. Otherwise Log error
      begin
        pluginmethod = plugin.method(pluginmethodname)
      rescue NameError
        $Log.error("      Plugin: #{pluginname} has no such function: #{pluginmethodname}")
        return
      end
      
      # Route given signal to pluginmethod 
      $routingtable.add_signal(signalname, pluginmethod)
    end
  end

  # Restart client to pull config changes
  def restart
    $Log.info('Restarting Client')
    
    # Modify Path to ruby file if running on Windows
    require 'rbconfig'
    self_path = File.absolute_path(__FILE__)
    self_path.gsub!('/','\\') if (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)
    
    # Call this file an replace exising process
    Kernel.exec(self_path, 'run')
  end

  # Start client
  def run
    # Connect to Server an register client
    $connection.connect
    
    # Setup exit variable
    exit_requested = false
    
    # Setup traps to set exit variables to true
    Kernel.trap( "SIGTERM" ) { exit_requested = true }
    Kernel.trap( "INT" ) { exit_requested = true }
    
    # Let main thread sleep unil exit is requestet via traps
    until exit_requested
      sleep(1)
    end
    
    # Inform server and close connection
    $connection.close if $connection.connected?
  end
end