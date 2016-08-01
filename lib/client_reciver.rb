class ClientReciver

  def initialize(router, socket)
    @router = router
    @socket = socket
    @clientaddr = @socket.peeraddr[3]
    @reciver = nil
  end

  def run
    @reciver = Thread.new{ reciver }
  end

  def reciver
    loop do
      begin
        recived_data = @socket.gets
        if recived_data
          data = FasProtocol.decode(recived_data)
          if data
            @router.route(@clientaddr, data)
          end
        end
      rescue IOError
        sleep(1)
      end
    end
  end

  def get_ip
    return @socket.local_address.to_s
  end

end
