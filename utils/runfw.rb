def runfw vpath, role, rolecfg, machinecfg, servercfg

  begin
    require "#{vpath}/runfw"
  rescue Exception => msg
    return false, msg
  end

  result, msg = fwsetup(role, rolecfg, machinecfg, servercfg)
  puts msg
  return result, msg

end

