module Fas_Logger

  def init_plugin(mode)
    @name = "Fas_Logger"
    @comment = "Plugins loggs payloads routed to it"
  end

  def info(ip, data, arguments={})
    if arguments.empty?
      $Log.info("Fas_Logger: IP: #{ip}, DATA: #{data}, ARGUMENTS: #{arguments}")
    else  
      if arguments['log_level'] == 'info'
        $Log.info("Fas_Logger: IP: #{ip}, DATA: #{data}, ARGUMENTS: #{arguments}")
      elsif arguments['log_level'] == 'error'
        $Log.error("Fas_Logger: IP: #{ip}, DATA: #{data}, ARGUMENTS: #{arguments}")
      end
    end
  end

end
