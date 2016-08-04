module Template

    def init_plugin(mode)
        @name = "Template"  #Change Me
        @comment = "Template for creating new Plugins"  #Change me to
        #@signals = {"testsignal"=>self.method(:handle_testsignal)}
        #@jobs = [self.method(:send_testsignal),]
        if $role == :client
            if @config.has_key?('send_every')
                @scheduler.every @config['send_every'] do
                    send_testsignal
                end
            end
        end
    end

    def send_testsignal
        send(:testsignal, 'Blablabla Test Payload')
    end

    def print(id, data)
        puts "Recived: #{data} from: #{id}"
    end

end
