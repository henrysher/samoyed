require 'service/sshcmd'
require 'utils/setyaml'
require 'utils/backup'
require 'utils/outdeps'
require 'utils/reboot'
require 'utils/bootstrap'
require 'utils/instvmtool'

def runcfg rolecfg, machinecfg, buildno, bucket
  role = "mongodb"
  machines = rolecfg[role]['machine'].split(",")
  # p machines
  for machineId in machines

  host, user, options, outdep = outdeps(role, rolecfg, machinecfg, machineId)
  result = instvmtool(host, user, options)
  if not result
    return false, msg
  end

  localpath = "config/ics/mongo-auth.init"
  remotepath = "/tmp/mongo-auth.init"
  option = options
  option[:remotepath] = remotepath
  option[:localpath] = localpath
  result, msg = sshupload(host, user, option)
  if not result
    puts msg
    return false, msg
  end

  end
  msg = "Success"
  return true, msg

end


def runsrv rolecfg, machinecfg
  role = "mongodb"
  machines = rolecfg[role]['machine'].split(",")
  # p machines
  for machineId in machines

  host, user, options, outdep = outdeps(role, rolecfg, machinecfg, machineId)
  services = rolecfg[role]['services'].split(',')
  
  #for service in services
  #  cmd = "#{service} stop"
  #  option = options
  #  option[:cmd] = cmd
  #  # p cmd
  #  result, msg = sshexec(host, user, option)
  #  p result

  #  cmd = "#{service} start"
  #  option = options
  #  option[:cmd] = cmd
  #  # p cmd
  #  result, msg = sshexec(host, user, option)
  #  p result
  #  if not result
  #    return false, msg
  #  end
  #end

  cmd = "/sbin/chkconfig mongod --level 2345 on"
  option = options
  option[:cmd] = cmd
  # p cmd
  result, msg = sshexec(host, user, option)
  # p result
  if not result
    return false, msg
  end

  result = reboot(host, user, options)
  if not result
    return false, msg
  end

  ## As to start mongod needs some time, wait for at least 60 secs.
  result = false
  starttime = Time.now.to_i
  nowtime = Time.now.to_i

  while(not result and (nowtime-starttime) < 100)
    result = false 
    cmd = "/usr/bin/mongo < /tmp/mongo-auth.init"
    option = options
    option[:cmd] = cmd
    result, msg = sshexec(host, user, option)
    if result
      result = not(msg.to_s.downcase.include?("exception"))
    end
    nowtime = Time.now.to_i
    sleep(10)
  end

  if not result
    return false, msg
  end

  result = reboot(host, user, options)
  if not result
    return false, msg
  end

  end
  msg = "Success"
  return true, msg
end
