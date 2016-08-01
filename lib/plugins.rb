class Plugins < Hash

  def initialize(routingtable, config, loopback=nil)
    @routingtable = routingtable
    @loopback = loopback
    @pluginlist = []
    if config.has_key?('plugins')
      pluginsconfig = config['plugins']
      pluginsconfig.each_key do |pluginname|
        $Log.info("Adding #{pluginname} to PluginList")
        @pluginlist << pluginname
      end
    end
    $Log.info("PluginList: #{@pluginlist}")
    @scheduler = Rufus::Scheduler.new
    if $role == "client"
      @routingtable.add_signal('plugin data', self.method(:recive_plugin))
    end
    $Log.info("\nPlugins:")
    $Log.info("PluginConfig: #{config}")
    @pluginlist.each do |pluginname|
      pluginconfig = {}
      if pluginsconfig.has_key?(pluginname)
        if pluginsconfig[pluginname].has_key?('config')
          pluginconfig = pluginsconfig[pluginname]['config']
        end
        if pluginsconfig[pluginname].has_key?('active')
          if pluginsconfig[pluginname]['active']
            load_plugin(pluginname, pluginconfig)
          end
        end
      end
    end
    $plugins_loaded = true
  end

  attr_accessor :pluginlist

  def pause
    $Log.info("pausing plugin scheduler")
    @scheduler.pause
  end

  def load_plugin(pluginname, config={})
    $Log.info(" Will load #{pluginname}")
    pluginpath = File.absolute_path("./plugins/" + pluginname + ".rb")
    $Log.info(" Pluginpath: " + pluginpath)
    if config
      $Log.info("  PluginConfig: #{config}")
    else
      $Log.info("  No config")
    end
    if File.exists?(pluginpath)
      $Log.info("Going to load plugin...")
      require pluginpath
      plugin = Plugin.new(pluginname, config, @scheduler, @loopback)
      if plugin.signals
        $Log.info("  Actions: " + plugin.signals.to_s)
        plugin.signals.each do |signal|
          @routingtable.add_signal(signal[0], signal[1])
        end
      end
      self[pluginname] = plugin
    else
      $Log.error("  Plugin not found. Requesting it from server")
      $connection.send('require plugin', pluginname)
      $wait_for_plugins += 1
    end
  end

  def recive_plugin(ip, data)
    $Log.info("Reciving new Plugin")
    pluginname, pluginconfig, plugindata_base64 = data
    $Log.info("  Pluginfilename: '#{pluginname}'")
    pluginspath = File.absolute_path("./plugins/" + pluginname + ".rb")
    $Log.info("  Pluginpath: '#{pluginspath}'")
    pluginfileobj = File.open(pluginspath, 'w')
    pluginfileobj.write(Base64.decode64(plugindata_base64))
    pluginfileobj.close
    load_plugin(pluginname, pluginconfig)
    $wait_for_plugins -= 1
  end
end

class Plugin

  def initialize(pluginname, config, scheduler, loopback)
    @pluginname = pluginname
    @config = config
    @scheduler = scheduler
    @loopback = loopback
    $Log.info("  Loading Plugin: #{pluginname}")
    extend Object.const_get(pluginname)
    $Log.info("  Extended Object")
    init_plugin($role)
    $Log.info("  Initialized Plugin")
    @file = File.absolute_path("./plugins/" + pluginname + ".rb")
    $Log.info("  Path: " + @file)
    $Log.info("  Name: #{@name}")
    $Log.info("  File: #{@file}")
    $Log.info("  Comment: #{@comment}")
  end

  def send(signalname, data)
    signal = @pluginname + "." + signalname
    $connection.send(signal, data)
  end

  attr_accessor :name
  attr_accessor :file
  attr_accessor :comment
  attr_reader :signals
end
