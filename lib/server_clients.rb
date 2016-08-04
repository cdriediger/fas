require 'base64'

class Clients < Hash

  def initialize(site_config)
    @site_config = site_config
    @pingids = [1,2,3,4,5]
    self['*'] = ClientGroup.new('*')
    $Log.info("Parsing clients:")
    @site_config['clients'].each do |client_config|
      $Log.info("New client: #{client_config}")
      id, attributes = client_config
      id = id.to_s
      ip, port, roomname, comment, plugins = attributes.values
      client = Client.new(id, ip, port, roomname, comment, plugins)
      self[id] = client
      self['*'].add_client(client)
      self[roomname] = ClientGroup.new(roomname) unless self.has_key?(roomname)
      self[roomname].add_client(client)
    end
    if @site_config.has_key?('clientgroups')
      @site_config['clientgroups'].each do |clientgroupname, clientname_list|
        if self.has_key?(clientgroupname)
          $Log.error("clientGroup #{clientgroupname} already exists")
          return
        end
        self[clientgroupname] = ClientGroup.new(clientgroupname)
        clientname_list.each do |clientname|
          if self.has_key?(clientname)
            self[clientgroupname].add_client(self[clientname])
          else
            $Log.error("No such client #{clientname}")
          end
        end
      end
    end
    #@ping_thread = Thread.new{self.check_online}
  end

  def close()
    @ping_thread.terminate
    self.each_pair do |client_id, client|
      client.close
    end
  end

  def register(source_port, id, socket)
    $Log.info("Register client: #{id}")
    client = self[id]
    if client
      if client.online?
        $Log.error("Online client trys to register again. Setting client offline")
        client.set_offline
      end
      client.set_online(socket)
      client.push_config
    else
      $Log.error("No such client #{id}")
    end
  end

  def set_offline(senderip, id)
    client = self[id]
    if client
      if client.online?
        client.set_offline
        $Log.info("client #{client.id} logged out")
      else
        $Log.error("Cannot loggout client: #{id}. Client is offline")
      end
    else
      $Log.error("No such client: #{id}")
    end
  end

  def send_plugin(client_id, pluginname)
    $Log.info("Plugin Transmit Request for #{pluginname} from #{client_id}")
    if self.has_key?(client_id)
      self[client_id].send_plugin(pluginname)
    else
      $Log.error("No such client #{client_id}")
    end
  end

  def by_ip(ip)
    self.each_pair do |client_id, client|
      next if client.is_a?(ClientGroup)
      return client if client.ip == ip
    end
    return nil
  end

  def input_ping_reply(client_id, ping_id)
    $Log.info("Got Pingreply from #{client_id} ID: #{ping_id}")
    if self.has_key?(client_id)
      self[client_id].ping_reply_queue << ping_id
    else
      $Log.error("No such client #{client_id}")
    end
  end

  def server_offline()
    self.each_pair do |client_id, client|
      if client.is_a?(Client)
        client.server_offline if client.online?
      end
    end
  end

  def check_online()
    threads = []
    loop do
      self.each_pair do |client_id, client|
        if client.is_a?(Client)
          if client.online?
            threads << Thread.start{self.ping(client)}
            sleep(0.1)
          end
        end
      end
      for thread in threads
        thread.join
        threads.delete(thread)
      end
      sleep(10)
    end
  end

  def ping(client)
    id = SecureRandom.uuid()
    $Log.info("Sending Ping Request #{id} to #{client.ip.to_s} #{client}")
    client.send_ping(id)
    4.times do
      if client.ping_reply_queue.include?(id)
        client.ping_reply_queue.delete(id)
        return true
      end
      sleep(1)
    end
    client.set_offline
    return false
  end

end

class ClientGroup

  def initialize(name)
    $Log.info("Creating new clientGroup #{name}")
    @name = name
    @clients = []
  end

  def add_client(client)
    $Log.info("Adding client #{client.id} to clientGroup #{@name}")
    @clients << client
    client.add_to_clientgroup(@name)
  end

  def add_remote_signal(signalname)
    @clients.each do |client|
      client.add_remote_signal(signalname) if client.is_a?(Client)
    end
  end

  def send(remote_signal, payload, arguments={}, source_id="0")
    @clients.each do |client|
      if client.online?
        $Log.info("Sending remoteAction to client: #{client.id}")
        client.send(remote_signal, payload, arguments, source_id)
      else
        $Log.info("client #{client.id} is offline")
      end
    end
  end

  def online?
    return true
  end

  def id
    return @name
  end

  def clients
    clientname_list = []
    @clients.each do |client|
      clientname_list << client.id
    end
    return clientname_list
  end

  attr_reader :name

end

class Client

  def initialize(id, ip, port, room, comment, plugins)
    $Log.info("Initialized new client #{self}")
    @id = id
    @ip = ip
    @port = port
    @room = room
    @plugins = plugins
    @remote_signals = []
    @comment = comment
    @clientgroups = []
    @ping_reply_queue = []
    @socket = nil
    @online = false
  end

  def close
    self.set_offline
  end

  def add_to_clientgroup(clientgroupname)
    @clientgroups << clientgroupname
  end

  def set_online(socket)
    if @online
      $Log.error("Trying to set online client #{@id} online")
      return
    end
    @socket = socket
    @online = true
    $Log.info("Client: #{@id} is online")
  end

  def set_offline
    unless @online
      $Log.error("Trying to set offline client #{@id} offline")
      return
    end
    @online = false
    @socket = nil
    $Log.info("Client: #{@id} is offline")
  end

  def online?
    return @online
  end

  def add_remote_signal(signal_name)
    if @remote_signals.include?(signal_name)
      $Log.error("Remote-Signal: #{signal_name} already exists @ client: #{@id}")
      return
    end
    @remote_signals << signal_name
  end

  def send_ping(id)
    send(:ping_request, id)
  end

  def push_config()
    $Log.info('pushing config')
    config = {'id'=>@id, 'plugins'=>@plugins, 'remote_signals'=>@remote_signals}
    send(:client_config, config)
  end

  def send_plugin(pluginname)
    unless @plugins.has_key?(pluginname)
      $Log.error("Plugin #{pluginname} not found")
      return
    end
    filepath = File.absolute_path("./plugins/#{pluginname}.rb")
    unless File.exists?(filepath)
      $Log.error("Plugin '#{pluginname}' not found in #{filepath}")
      return
    end
    $Log.info("Sending Plugin #{filepath} to #{@ip}")
    plugindata_base64 = Base64.encode64(IO.read(filepath))
    #if @plugins[pluginname].has_key?('config')
    #  pluginconfig = @plugins[pluginname]['config']
    #else
    #  pluginconfig = {}
    #end
    send(:plugin_data, [pluginname, pluginconfig, plugindata_base64])
    $Log.info("Plugin send")
  end

  def server_offline()
    send(:server_going_offline, $server_ip)
    begin
      @socket.close
    rescue IOError

    end
  end

  def send(remote_signal, payload, arguments={}, source_id="0")
    if online?
      begin
        Timeout::timeout(2) do
          remote_signal = remote_signal.to_s if remote_signal.is_a?(Symbol)
          packet = FasProtocol.generate(source_id, remote_signal, payload, arguments)
          @socket.puts(packet)
          $Log.info("send #{packet} to #{@ip}:#{@port}")
        end
      rescue Errno::ECONNREFUSED, Errno::EPIPE, IOError => e
        $Log.error("Error while sending Data to #{@ip}:#{@port}: #{e}")
        set_offline
      rescue Timeout::Error
        $Log.error("Connection to #{@ip}:#{@port} timeouted")
        set_offline
      end
    else
      $Log.error("Client #{@ip}:#{port} is offline. Can not send Data")
    end
  end

  attr_reader :id
  attr_reader :ip
  attr_reader :port
  attr_reader :room
  attr_reader :plugins
  attr_reader :remote_signal
  attr_reader :comment
  attr_reader :clientgroups
  attr_accessor :ping_reply_queue

end
