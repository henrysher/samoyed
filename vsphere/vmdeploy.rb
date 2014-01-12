require "service/sshcmd"
require "utils/sshparser"
require "utils/parser"
require "vsphere/connect"
require "vsphere/snapshot"
require "vsphere/power"

def vsparser vconfig

  result, msg = parser(vconfig, "deploy")
  if not result
    return false, msg
  end
  machinecfg = File.join(File.dirname(vconfig), msg["machines"])
  #logger.info logtitle + "CONFIG - machines.cfg located at #{machinecfg}"

  servercfg = File.join(File.dirname(vconfig), msg["servers"])
  #logger.info logtitle + "CONFIG - servers.cfg located at #{servercfg}"

  return parser(machinecfg)[1],  parser(servercfg)[1]
end

def rundeploy vconfig, machineIds, logger

  logtitle = "VMDEPLOY::"

  vmcfg = {}
  machinecfg, servercfg = vsparser(vconfig)

  for machines in machineIds
    p machines
    for machineId in machines.split(',')
    minfo = machinecfg[machineId]

    p minfo
    vmcfg.update(minfo)

    esxName = minfo["server"]
    esxcfg = servercfg[esxName]
    
    vccfg = servercfg[esxcfg['platform']]

    result, vmspec = parser(vconfig, "VM")
    if not result
      return false, vmspec
    end

    result, snapshot = parser(vconfig, "Snapshot")
    if not result
      return false, snapshot
    end

    vmcfg.update(esxcfg)
    vmcfg.update(vccfg)
    vmcfg.update(vmspec)
    vmcfg.update(snapshot)
    # p vmcfg
    msg = "CONFIG - VM Configuration ==> #{vmcfg}"
    logger.info logtitle + msg

    result, vim = connect(vmcfg)
    if not result
      return false, vim
    end
    msg = "CONNECT TO VM SERVER: SUCCESS!"
    p msg
    logger.info logtitle + msg

    result, vmSnapshot = findPath(vim, vmcfg, "snapshot")
    if not result
      return false, vmSnapshot
    end
    msg = "Find the snapshot of this VM: SUCCESS!"
    p msg
    logger.info logtitle + msg

    result, path = revertSnapshot(vmSnapshot.snapshot)
    if not result
      return false, path
    end
    msg =  "Revert to the snapshot: SUCCESS!"
    p msg
    logger.info logtitle + msg

    result, status = poweron(vim, vmcfg)
    p status

    if not result
      if status.to_s.include?("InvalidPowerState")
        p "This VM is already Powered On..."
      else
        return false, status
      end
    else
      msg = "Power On this VM: SUCCESS!"
      p msg
      logger.info logtitle + msg
    end
  end
  end

  flag = 0
  starttime = Time.now.to_i
  nowtime = Time.now.to_i

  while(flag < machineIds.size and (nowtime-starttime) < 600)
    flag = 0 
    for machines in machineIds
      for machineId in machines.split(',')
      host, user, options = sshparser(machineId, machinecfg)
      cmd = "uname -a"
      options[:cmd] = cmd
      res, msg = sshexec(host, user, options)
      if res and msg.to_s.include?("Linux")
        flag += 1
      end
      msgs  = host + ":  " + cmd + "  =>  " + "#{msg}"
      puts msgs
      logger.info logtitle + msgs
      end
    end
    nowtime = Time.now.to_i
    sleep(5)
  end
  if flag < machineIds.size
    msg = "Cannot connect to these VMs..."
    logger.fatal logtitle + msg
    return false, msg
  end
  return true, [machinecfg,servercfg]

end
