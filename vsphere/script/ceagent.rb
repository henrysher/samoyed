require 'service/sshcmd'
require 'utils/setini'
require 'utils/backup'
require 'utils/outdeps'
require 'utils/bootstrap'
require 'utils/reboot'
require 'utils/instvmtool'

## Role: CEAgent
#
def runcfg rolecfg, machinecfg, buildno, bucket
  role = "ceagent"

  machines = rolecfg[role]['machine'].split(",")
  # p machines
  for machineId in machines
    host, user, options, outdep = outdeps(role, rolecfg, machinecfg, machineId)
 
    # we should install the RPM first and then download the configure
    cmd = "/usr/bin/yum -y install ICS-Skynet-Agent"
    # p cmd
    option = options
    option[:cmd] = cmd
    result, msg = sshexec(host, user, option)
    # p result, msg
    if not result
      return false, msg
    end

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
  role = "ceagent"

  machines = rolecfg[role]['machine'].split(",")

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
