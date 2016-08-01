class Connection

  def initialize(server_ip, server_port, local_ip, server_offline_scheduler, restart_method)
    @server_ip = server_ip
    @server_port = server_port
    @local_ip = local_ip
    @server_offline_scheduler = server_offline_scheduler
    @restart_method = restart_method
    @connected = false
  end

  def connected?
    return @connected
  end

  def server_offline(ip=nil, server_ip=@server_ip)
    $Log.info("Server #{server_ip} is offline")
    if server_ip == @server_ip
      close(server_offline=true)
      sleep(1)
      $Log.info("Try reconnecting to server ..")
      connect(reconnect=true)
    else
      $Log.error("Got 'server_offline' from wrong server")
    end
  end

  def connect(reconnect=false)
    loop do
      $Log.info("Connecting to Server #{@server_ip}:#{@server_port}")
      @server = Transmiter.new(@server_ip, @server_port, @local_ip)
      success = @server.connect
      if success
        $Log.info("Connected")
        #@server_offline_scheduler.in '20s' do
        #  server_offline
        #end
        if reconnect
          @restart_method.call
        else
          @router = Router.new($routingtable)
          @reciver = ClientReciver.new(@router, @server.socket)
          @reciver.run
          send('register', @local_ip)
          send('ping reply', @local_ip.to_s)
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
      self.send('client offline', @local_ip)
    end
    @connected = false
    $plugins.pause if $plugins
    @server_offline_scheduler.jobs[0].unschedule unless @server_offline_scheduler.jobs.empty?
    @server.close
    $Log.info("closed server")
  end

  def send_testsignal
    puts("Sending Signal")
    self.send('testsignal', true)
  end

  def send(signal, data)
    $Log.info("Sending #{signal} Data: #{data}")
    server_offline unless @server.send($id, signal, data)
  end
end