class ServerReciver

  def initialize(ip, port, router)
    @ip = ip
    @port = port
    @router = router
    @reciver = nil
  end

  def run
    @server = TCPServer.new(@ip, @port)
    @reciver = Thread.new { reciver }
  end

  def reciver
    loop do
      Thread.start(@server.accept) do |socket|
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
    @server.close
  end

end

class Loopback

  def initialize(router)
    @router = router
  end

  def send(signal, data, arguments={})
    data = {'source_id' => '0', 'signal'=>signal, 'payload'=>data, 'arguments'=>arguments}
    @router.route('127.0.0.1', '0', data)
  end

end
