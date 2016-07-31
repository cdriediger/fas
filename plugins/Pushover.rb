require "net/https"

module Pushover

    def init_plugin(mode)
        @name = "Pushover"  #Change Me
        @comment = "send Pushover notification"  #Change me to
        @signals = {"notify"=>self.method(:notify)}
        #@jobs = [self.method(:send_testsignal),]
    end

    def notify(id, data)
	url = URI.parse("https://api.pushover.net/1/messages.json")
	req = Net::HTTP::Post.new(url.path)
	req.set_form_data({
  	  :token => "anbjhwch9nzdnhpkvt3hg3vt36xtwp",
          :user => "uGF8ao5xrXhdCdBph9vJCrZpp5zJHe",
          :message => data,
	})
	res = Net::HTTP.new(url.host, url.port)
	res.use_ssl = true
	res.verify_mode = OpenSSL::SSL::VERIFY_PEER
	res.start {|http| http.request(req) }
    end

end
