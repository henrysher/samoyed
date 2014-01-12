require 'service/sshcmd'
require 'utils/setini'
require 'utils/parser'
require 'utils/backup'
require 'utils/outdeps'
require 'utils/bootstrap'
require 'utils/reboot'
require 'utils/instvmtool'

## Role: Global Cache
#
def runcfg rolecfg, machinecfg, buildno, bucket
  role = "logclient"

  machines = rolecfg[role]['machine'].split(",")
  # p machines
  for machineId in machines

  host, user, options, outdep = outdeps(role, rolecfg, machinecfg, machineId)

  result = cfgdownload(host, user, options, role, buildno, bucket)
  if not result
    return false, msg
  end
  result = instvmtool(host, user, options)
  if not result
    return false, msg
  end

  end
  msg = "Success"
  return true, msg

end

def runsrv rolecfg, machinecfg
  role = "logclient"
  machines = rolecfg[role]['machine'].split(",")
  # p machines
  for machineId in machines

  host, user, options, outdep = outdeps(role, rolecfg, machinecfg, machineId)
  services = rolecfg[role]['services'].split(',')

  result = reboot(host, user, options)
  if not result
    return false, msg
  end

  end
  msg = "Success"
  return true, msg
end
