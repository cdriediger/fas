require "net/https"

module Pushover

  def init_plugin(mode)
    @name = "Pushover"  #Change Me
    @comment = "send Pushover notification"  #Change me to
    #@signals = {"notify"=>self.method(:notify)}
  end

  def notify(id, data)
    $Log.error("No Token found in Pushover config") unless @config.has_key?('token')
    $Log.error("No User found in Pushover config") unless @config.has_key?('user')
    if @config.has_key?('use_ssl')
      if @config['use_ssl']
        if @config.has_key?('url')
          url = URI.parse(@config['url'])
        else
          url = URI.parse("https://api.pushover.net/1/messages.json")
        end
        use_ssl = true
      else
        if @config.has_key?('url')
          url = URI.parse(@config['url'])
        else
          url = URI.parse("http://api.pushover.net/1/messages.json")
        end
        use_ssl = false
      end
    else
      if @config.has_key?('url')
        url = URI.parse(@config['url'])
      else
        url = URI.parse("http://api.pushover.net/1/messages.json")
      end
    end
	req = Net::HTTP::Post.new(url.path)
	req.set_form_data({
      :token => @config['token'],
      :user => @config['user'],
      :message => data,
	})
    res = Net::HTTP.new(url.host, url.port)
    res.use_ssl = false
    res.verify_mode = OpenSSL::SSL::VERIFY_PEER
    res.start {|http| http.request(req) }
  end

end
