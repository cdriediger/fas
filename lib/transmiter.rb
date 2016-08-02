class Transmiter

  def initialize(dest_ip, dest_port)
    @ip = dest_ip
    @port = dest_port
    @connected = false
    @slave_send = false
  end

  def close
    @connected = false
    begin
      @socket.close if @socket
    rescue IOError
      $Log.error("Connection to server already lost")
      @socket = nil
    end
  end

  def connect
    begin
      @socket = TCPSocket.new(@ip, @port)
    rescue Errno::ECONNREFUSED => e
      $Log.error("Connecting to #{@ip}:#{@port} failed:\n  Error: #{e}")
      return false
    else
      @connected = true
      return true
    end
  end

  def slave_send=(slave_mode)
    $Log.info("Allowing slave to send Data")
    @slave_send = slave_mode
  end

  def send(source_id, signal, data)
    if $server_role == 'slave' and not @slave_send
      $Log.info("Slave Server can't send")
      return true
    end
    unless @connected
      $Log.error("HOST: #{@ip}:#{@port} IS OFFLINE")
      return false
    end
    begin
      Timeout::timeout(2) do
        packet = FasProtocol.generate(source_id, signal, data)
        @socket.puts(packet)
        return true
      end
    rescue Errno::ECONNREFUSED, Errno::EPIPE => e
      $Log.error("Error while sending Data to #{@ip}:#{@port}: #{e}")
      return false
    rescue Timeout::Error
      $Log.error("Connection to #{@ip}:#{@port} timeouted")
      return false
    end
  end

  attr_reader :connected
  attr_reader :socket

end
