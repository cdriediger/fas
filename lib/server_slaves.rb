require 'base64'

class Slaves < Hash

  def register(source_port, payload)
    ip, port = payload
    puts("Register slave server #{ip}:#{port} source_port: #{source_port}")
    self[ip] = Slave.new(ip, port, source_port)
    puts "Slaves: #{self.keys}"
  end

  def relay(signal, payload, source_id)
    self.each_pair do |slave_ip, slave|
      slave.send(signal, payload, source_id)
    end
  end

  def input_ping_request(slave_ip, ping_id)
    puts slave_ip
    slave = self[slave_ip]
    puts "Got Ping reguest from #{slave.ip} ID: #{ping_id}"
    slave.reply_ping(ping_id)
  end

  def server_offline()
    self.each_pair do |slave_ip, slave|
      slave.server_offline
    end
  end

end

class Slave

  def initialize(ip, port, source_port)
    puts("Initialized new Slave #{ip}:#{port}")
    @ip = ip
    @port = port
    @source_port = source_port
    @con = Transmiter.new @ip, @port, $server_ip
    @con.connect
  end

  def close
    @con.close
  end

  def server_offline()
    send("server going offline", $server_ip)
  end

  def reply_ping(ping_id)
    send('master ping reply', ping_id)
  end

  def send(signal, data, source_id="0")
    success = @con.send(source_id, signal, data)
    if success
      puts("Sended Data successfully")
    else
      puts("Failed to send Data")
    end
  end

  attr_reader :ip
  attr_reader :port
  attr_reader :source_port
  attr_accessor :ping_reply_queue
end
