class ServerReciver

  def initialize(ip, port, router)
    @ip = ip
    @port = port
    @router = router
    @reciver = nil
  end

  def run
    @socket = TCPServer.new(@ip, @port)
    @reciver = Thread.new { reciver }
  end

  def reciver
    loop do
      Thread.start(@socket.accept) do |socket|
        clientaddr = socket.peeraddr[3]
        $Log.info("New Connection from #{clientaddr}")
        while recived_data = socket.gets
          data = FasProtocol.decode(recived_data)
          if data
            @router.route(clientaddr, data, socket)
          end
        end
        socket.close
      end
    end
  end

  def close
    $Log.info('terminate reciver')
    begin
      @reciver.terminate
      @reciver.join
    rescue IOError

    end
    @socket.close
  end

end
