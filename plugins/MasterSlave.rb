require './transmiter.rb'

module MasterSlave

    def init_plugin(mode)
        @name = 'MasterSlave'  #Change Me
        @comment = ""  #Change me to
        @signals = {'master ping reply'=>method(:insert_ping_reply)}
        #@jobs = [self.method(:send_testsignal),]
        role = @config['server_role']
        master_server_ip = @config['master_server_ip']
        master_server_port = @config['master_server_port']
        server_role = @config['server_role']
        @master_ping_reply_queue = []
        @master_transmitter = Transmiter.new(master_server_ip, master_server_port, $server_ip)
        @next_ping_id = 1
        if $role == 'server'
          if server_role == 'slave'
            connect_to_master(master_server_ip, master_server_port)
            @scheduler.every '10s' do
              send_ping_to_master
            end
          end
        end
    end

    def connect_to_master(master_server_ip, master_server_port)
      puts "Connecting to master_server: #{master_server_ip}:#{master_server_port}"
      begin
        @master_transmitter.connect
        @master_transmitter.slave_send = true
        @master_transmitter.send('1', 'register slave', [$server_ip, $server_port])
      rescue Errno::ECONNREFUSED
        puts("Can not connect to Master Server")
      end
    end

    def send_ping_to_master
      id = @next_ping_id
      success = false
      @next_ping_id += 1
      puts("Sending Ping Request #{id} to #{@master_server_ip}:#{@master_server_port}")
      @master_transmitter.send('1', 'slave ping request', id)
      4.times do
        if @master_ping_reply_queue.include?(id)
          @master_ping_reply_queue.delete(id)
          puts("Got back ping reply")
          success = true
          break
        end
        sleep(1)
      end
      unless success
        @loopback.send('become master', true)
      end
    end

    def insert_ping_reply(id, ping_id)
      puts("Recived master ping reply ID: #{ping_id}")
      @master_ping_reply_queue << ping_id
    end

end
