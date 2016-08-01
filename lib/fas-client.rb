#! /usr/bin/ruby

require 'socket'
require 'json'
require 'timeout'
require 'yaml'
require 'base64'
require 'rufus/scheduler'
require './lib/client_reciver.rb'
require './lib/router.rb'
require './lib/client_connection.rb'
require './lib/plugins.rb'
require './lib/transmiter.rb'
require './lib/fas-protocol.rb'
require './lib/logger.rb'

class FasClient

  def initialize(client_config_file)
    $Log = Log.new('./client_log')
    $Log.level = Logger::DEBUG
    $Log.info('Start FasClient')
    $id = nil
    $role = "client"
    Thread.abort_on_exception=true
    @config_path = client_config_file
    if not File.exists?(@config_path)
      $Log.fatal_error("Could not find Config #{@config_path}")
    else
      @config = YAML.load_file(@config_path)
    end
    unless @config.has_key?('server_ip')
      $Log.fatal_error("NO server_ip FOUND in #{@config_path}!!")
    end
    $server_ip = @config['server_ip']
    if @config.has_key?('server_port')
      $server_port = @config['server_port']
    else
      $server_port = "20000"
    end
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
    @server_offline_scheduler = Rufus::Scheduler.new
    $connection = Connection.new($server_ip, $server_port, $local_ip, @server_offline_scheduler, method(:restart))
    $routingtable = RoutingTable.new
    $routingtable.add_signals({'ping request' => self.method(:ping_replay),
                               'client config' => self.method(:parse_config),
                               'server going offline' => $connection.method(:server_offline),
                               'restart' => self.method(:restart)})
    $jobs = []
    $plugins_loaded = false
    $wait_for_plugins = 0
  end

  def ping_replay(ip, id)
    $Log.info("Got Ping request #{id}")
    #@server_offline_scheduler.jobs[0].unschedule
    #@server_offline_scheduler.in '20s' do
    #  $connection.server_offline
    #end
    $connection.send('ping reply', id)
  end

  def parse_config(ip, config)
    $Log.info("Parsing Config #{config}")
    $id = config['id']
    $Log.info("    ID: #{$id}\n    Plugins: #{config['plugins']}\n    Signals: #{config['remote_signals']}")
    $plugins = Plugins.new($routingtable, config)
    add_remote_signals(config['remote_signals'])
  end

  def add_remote_signals(remote_signals)
    remote_signals.each do |signalname|
      pluginname, pluginmethodname = signalname.split('.')
      $Log.info("Adding Remote Signal: Pluginname: #{pluginname}, Plugin Method Name: #{pluginmethodname}")
      unless $plugins.has_key?(pluginname)
        $Log.error("No such Plugin #{pluginname}") unless $plugins.has_key?(pluginname)
        return
      end
      plugin = $plugins[pluginname]
      pluginmethod = plugin.method(pluginmethodname)
      $routingtable.add_signal(signalname, pluginmethod)
    end
  end

  def restart
    $Log.info('Restarting Client')
    require 'rbconfig'
    self_path = File.absolute_path(__FILE__)
    self_path.gsub!('/','\\') if (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)
    Kernel.exec(self_path, 'run')
  end

  def run
    $connection.connect
    exit_requested = false
    Kernel.trap( "SIGTERM" ) { exit_requested = true }
    Kernel.trap( "INT" ) { exit_requested = true }
    until exit_requested
      sleep(1)
    end
    $connection.close if $connection.connected?
  end
end

if not ARGV.empty? and ARGV[0] == 'run'
  fas_client = FasClient.new(File.absolute_path("./etc/config_client.yaml"))
  fas_client.run
end
