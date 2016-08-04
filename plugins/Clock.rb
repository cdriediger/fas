module Clock

    def init_plugin(mode)
        @name = "Clock"  #Change Me
        @comment = "Clock"  #Change me to
        if $role == :client
            if @config.has_key?('send_every')
                @scheduler.every @config['send_every'] do
                    send_time
                end
            end
        end
    end

    def send_time
        send('time_now', Time.now)
    end

    def print_time(id, data)
        puts "Time: #{data}"
    end

end
