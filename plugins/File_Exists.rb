module File_Exists

    def init_plugin(mode)
        @name = "File_Exists"  #Change Me
        @comment = "Plugins notifys if File Exists"  #Change me to
        if mode == :client
            @filepath = @config['file_path']
            @exists = File.exists?(@filepath)
            @scheduler.every @config['search_every'] do
                search_for_file
            end
        end
    end

    def notify(ip, data)
        puts("File '#{@filepath}' does now exists")
    end

    def notify_not(ip, data)
        puts("File '#{@filepath}' does not exists anymore")
    end

    def stop
        @listining = false
    end

    def search_for_file
        puts("Searching file #{@filepath}")
        if File.exists?(@filepath) and not @exists
            send(:file_exists, @filepath)
            @exists = true
        elsif not File.exists?(@filepath) and @exists
            send(:file_not_exists, @filepath)
            @exists = false
        end
    end
end
