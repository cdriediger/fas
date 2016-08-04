require 'logger'

class Log

  def initialize(path)
    logfiles = Dir[path + ".debug.*"]
    logfiles.map! {|path| /\d{1,3}/.match(path).to_s.to_i}
    logfiles.map! {|number| number.to_i}
    if logfiles.empty?
      @Logfile = path + ".1.debug"
    else
      @Logfile = path + (logfiles.sort[-1] + 1).to_s  + ".debug."
    end
    puts "Logfile: #{@Logfile}"
    @logger = Logger.new(@Logfile)
  end

  def level=(loglevel)
    @logger.level = loglevel
  end

  def debug(msg)
    @logger.debug(msg)
#    if $print_debug
#    puts(msg)
#    end
  end

  def info(msg)
    @logger.info(msg)
    puts("INFO: " + msg.to_s)
  end

  def error(msg)
    @logger.error(msg)
    puts("ERROR: " + msg.to_s)
  end

  def fatal_error(msg)
    error("FATAL ERROR: " + msg)
    Kernel.exit!
  end
end
