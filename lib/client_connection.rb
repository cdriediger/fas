class Connection

  def initialize(server_ip, server_port, restart_method)
    # Initialize connection parameter
    @server_ip = server_ip
    @server_port = server_port
    # Use this Method if connect(reconnect=true) is called
    @restart_method = restart_method
    @connected = false
  end

  def connected?
    return @connected
  end

  def server_offline(ip=nil, server_ip=@server_ip)
    # Method gets called if server send "going offline" message
    $Log.info("Server #{server_ip} is offline")
    # Test if message comes from the correct server
    if server_ip == @server_ip
      # close connection to server 
      close(server_offline=true)
      sleep(1)
      $Log.info("Try reconnecting to server ..")
      # start reconnect loop
      connect(reconnect=true)
    else
      # Ignore "going offline" message
      $Log.error("Got 'server_offline' from wrong server")
    end
  end

  def connect(reconnect=false)
    # Do the actual connect
    loop do
      $Log.info("Connecting to Server #{@server_ip}:#{@server_port}")
      @transmitter = Transmiter.new(@server_ip, @server_port)
      success = @transmitter.connect
      if success
        $Log.info("Connected")
        if reconnect
          @restart_method.call
        else
          @router = Router.new($routingtable)
          @reciver = ClientReciver.new(@router, @transmitter.socket)
          @reciver.run
          send(:register, $id)
          send(:ping_reply, $id)
          @connected = true
          break
        end
      end
      sleep(1)
    end
  end

  def close(server_offline=false)
    $Log.info("Closing server")
    if connected? and not server_offline
      $Log.info("sending client offline")
      self.send(:client_offline, $id)
    end
    @connected = false
    $plugins.pause if $plugins
    @transmitter.close
    $Log.info("closed server")
  end

  def send_testsignal
    $Log.info("Sending TestSignal")
    self.send(:testsignal, true)
  end

  def send(signal, data)
    $Log.info("Sending #{signal} Data: #{data}")
    signal = signal.to_s if signal.is_a?(Symbol)
    server_offline unless @transmitter.send($id, signal, data)
  end
end
