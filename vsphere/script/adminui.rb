require 'service/sshcmd'
require 'utils/setini'
require 'utils/backup'
require 'utils/outdeps'
require 'utils/bootstrap'
require 'utils/reboot'
require 'utils/instvmtool'

## Role: AdminUI
#
def runcfg rolecfg, machinecfg, buildno, bucket
  role = "adminui"

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
  role = "adminui"

  machines = rolecfg[role]['machine'].split(",")

  for machineId in machines

  host, user, options, outdep = outdeps(role, rolecfg, machinecfg, machineId)
  services = rolecfg[role]['services'].split(',')

  result = reboot(host, user, options)
  if not result
    return false, msg
  end

  cmd = "cd /usr/ics/UI/frontend/htdocs/widget/repository/widgetPool/;/usr/bin/php interface_request.php initWFDBSchema.php"
  # p cmd
  option = options
  option[:cmd] = cmd
  result, msg = sshexec(host, user, option)
  # p result, msg
  if not result
    return false, msg
  end

  cmd = "cd /usr/ics/UI/frontend/htdocs/widget/repository/widgetPool/;/usr/bin/php interface_request.php synWidgetXMLToDB.php"
  # p cmd
  option = options
  option[:cmd] = cmd
  result, msg = sshexec(host, user, option)
  # p result, msg
  if not result
    return false, msg
  end

  end

  msg = "Success"
  return true, msg
end
