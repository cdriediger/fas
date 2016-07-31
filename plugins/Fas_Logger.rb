module Fas_Logger

  def init_plugin(mode)
    @name = "Fas_Logger"  #Change Me
    @comment = "Plugins loggs payloads routed to it"  #Change me to
  end

  def info(ip, data, arguments=nil)
    puts("INFO: #{data}")
  end

end
