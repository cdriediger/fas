module TestPayload

    def init_plugin(mode)
        @name = "TestPayload"  #Change Me
        @comment = "TestPayload"  #Change me to
        if $role == :client
            if @config.has_key?('send_every') and @config.has_key?('payload')
                @scheduler.every @config['send_every'] do
                    send_payload
                end
            end
        end
    end

    def send_payload
        send(:data, @config['payload'])
    end

end
