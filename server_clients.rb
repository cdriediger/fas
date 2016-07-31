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
#    @ping_thread = Thread.new{self.check_online}
  end

  def close()
    @ping_thread.terminate
    self.each_pair do |client_id, client|
      client.close
    end
  end

  def register(source_port, ip, socket)
    $Log.info("Register #{ip}")
    client = self.by_ip(ip)
    if client
      if client.online?
        $Log.error("Online client trys to register again. Setting client offline")
        client.set_offline
      end
      client.set_online(socket)
      client.push_config
    else
      $Log.error("No such client #{ip}")
    end
  end

  def set_offline(senderip, ip)
    client = self.by_ip(ip)
    if client
      if client.online?
        client.set_offline
        $Log.info("client #{client.id} logged out")
      else
        $Log.error("Cannot loggout client #{ip}. Client is offline")
      end
    else
      $Log.error("No such client #{ip}")
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
    id = get_ping_id
    $Log.info("Sending Ping Request #{id} to #{client.ip.to_s} #{client}")
    client.send_ping(id)
    4.times do
      if client.ping_reply_queue.include?(id)
        return true
      end
      sleep(1)
    end
    client.set_offline
    return false
  end

  def get_ping_id
    if @pingids.length < 5
      last_id = @pingids[-1]
      if last_id > 99999
        last_id = 0
      end
      5.times do |i|
        @pingids << last_id + i
      end
    end
    id = @pingids.first
    @pingids.delete_at(0)
    return id
  end

end

class ClientGroup < Array

  def initialize(name)
    $Log.info("Creating new clientGroup #{name}")
    @name = name
  end

  def add_client(client)
    $Log.info("Adding client #{client.id} to clientGroup #{@name}")
    self << client
    client.add_to_clientgroup(@name)
  end

  def add_remote_signal(signalname)
    self.each do |client|
      client.add_remote_signal(signalname) if client.is_a?(Client)
    end
  end

  def send(signal, data, arguments={}, source_id="0")
    self.each do |client|
      if client.online?
        client.send(signal, data, source_id)
        puts "Sending remoteAction to client: #{client.id}"
      else
        puts "client #{client.id} is offline"
      end
    end
  end

  def online?
    return true
  end

  def id
    return @name
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
    send("ping request", id)
  end

  def push_config()
    $Log.info('pushing config')
    config = {'id'=>@id, 'plugins'=>@plugins, 'remote_signals'=>@remote_signals}
    send('client config', config)
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
    if @plugins[pluginname].has_key?('config')
      pluginconfig = @plugins[pluginname]['config']
    else
      pluginconfig = {}
    end
    send('plugin data', [pluginname, pluginconfig, plugindata_base64])
    $Log.info("Plugin send")
  end

  def server_offline()
    send("server going offline", $server_ip)
    begin
      @socket.close
    rescue IOError

    end
  end

  def send(signal, data, arguments={}, source_id="0")
    if online?
      begin
        Timeout::timeout(2) do
          packet = FasProtocol.generate(source_id, signal, data, arguments)
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
  attr_reader :remote_signals
  attr_reader :comment
  attr_reader :clientgroups
  attr_accessor :ping_reply_queue

end
