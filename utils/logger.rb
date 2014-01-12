require 'logger'

class MultiDelegator
  def initialize(*targets)
    @targets = targets
  end

  def self.delegate(*methods)
    methods.each do |m|
      define_method(m) do |*args|
        @targets.map { |t| t.send(m, *args) }
      end
    end
    self
  end

  class <<self
    alias to new
  end
end


def logger logpath
  if File.exists?(logpath)
    begin
      logfile = File.open(logpath, File::WRONLY | File::APPEND)
    rescue Exception => msg
       puts msg
       return false, msg
    end

    # logobj = Logger.new(logfile, 10, 50000)
    logobj = Logger.new MultiDelegator.delegate(:write, :close).to(STDOUT, logfile)
    return true, logobj 
  else
    msg = "no such file #{logpath}"
    return false, msg
  end
end
