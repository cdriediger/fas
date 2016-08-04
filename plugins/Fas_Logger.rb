module Fas_Logger

  def init_plugin(mode)
    @name = "Fas_Logger"
    @comment = "Plugins loggs payloads routed to it"
  end

  def info(ip, data, arguments=nil)
    $Log.info("Fas_Logger: IP: #{ip}, DATA: #{data}, ARGUMENTS: #{arguments}")
  end

end
