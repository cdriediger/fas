class Plugins < Hash

  def initialize(routingtable, config)
    @routingtable = routingtable
    @config = config
    @pluginlist = []
    if $role == "server"
      Dir["plugins/*"].each do |filepath| 
        @pluginlist << File.basename(filepath)
      end
    else
      if @config.has_key?('plugins')
        @pluginsconfig = @config['plugins']
        @pluginsconfig.each_key do |pluginname|
          $Log.info("Adding #{pluginname} to PluginList")
          @pluginlist << pluginname
        end
      end
    end
    $Log.info("PluginList: #{@pluginlist}")
    if $role == "client"
      load_plugins
    else
      load_plugin_dummys
    end
    $plugins_loaded = true
  end

  attr_accessor :pluginlist

  def pause
    $Log.info("pausing plugin scheduler")
    @scheduler.pause
  end

  def load_plugins
    @scheduler = Rufus::Scheduler.new
    @routingtable.add_signal('plugin data', self.method(:recive_plugin))
    $Log.info("\nPlugins:")
    @pluginlist.each do |pluginname|
      pluginconfig = {}
      if @pluginsconfig.has_key?(pluginname)
        if @pluginsconfig[pluginname].has_key?('config')
          pluginconfig = @pluginsconfig[pluginname]['config']
        end
        if @pluginsconfig[pluginname].has_key?('active')
          if @pluginsconfig[pluginname]['active']
            load_plugin(pluginname, pluginconfig)
          end
        end
      end
    end
  end

  def load_plugin_dummys
    $Log.info("\nPlugins:")
    @pluginlist.each do |pluginname|
      $Log.info(" Will load #{pluginname}")
      pluginpath = File.absolute_path("./plugins/" + pluginname + ".rb")
      if File.exists?(pluginpath)
        $Log.info("Going to load plugin...")
        self[pluginname] = PluginDummy.new(pluginname, {}, @scheduler)
      end
    end
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
      plugin = Plugin.new(pluginname, config, @scheduler)
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

class PluginDummy

  def initialize(pluginname, config, scheduler)
    @pluginname = pluginname
    @config = config
    @scheduler = scheduler
    $Log.info("  Loading Plugin: #{pluginname}")
    @file = File.absolute_path("./plugins/" + pluginname + ".rb")
  end

  attr_accessor :name
  attr_accessor :file
end

class Plugin < PluginDummy

  def initialize(pluginname, config, scheduler)
    super(pluginname, config, scheduler)
    extend Object.const_get(pluginname)
    $Log.info("  Extended Object")
    init_plugin($role)
    $Log.info("  Path: " + @file)
    $Log.info("  Name: #{@name}")
    $Log.info("  File: #{@file}")
    $Log.info("  Comment: #{@comment}")
  end

  def send(signalname, data)
    signal = @pluginname + "." + signalname
    $connection.send(signal, data)
  end

  attr_accessor :comment
  attr_reader :signals
end
