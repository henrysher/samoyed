require 'rubygems'
require 'service/run'

def fixtime ntpserver
  cmd = "service ntpd stop"
  result, msg = run(cmd)
  if not result
    return false, msg
  end

  cmd = "ntpdate #{ntpserver}"
  result, msg = run(cmd)
  if not result
    return false, msg
  end

  cmd = "service ntpd start"
  result, msg = run(cmd)
  if not result
    return false, msg
  end
  return true, "Success"
end
