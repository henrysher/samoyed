require 'rubygems'
require 'net/ssh'
require 'utils/sshparser'
require 'utils/parser'

def dnssetup role, rolecfg, machinecfg, servercfg
  
  machines = rolecfg[role]['machine'].split(',')
  for machineId in machines

  host, user, options = sshparser(machineId, machinecfg)
  begin
    dnsserver = servercfg['Common Server']['DNS'].split(",")
  rescue Exception => msg
    # FIXME: no such value, skip it
    return true, msg 
  end

  cmd = "/bin/mv -fv /etc/resolv.conf /etc/resolv.conf.bak; :> /etc/resolv.conf"
  option = options
  option[:cmd] = cmd
  # p cmd
  result, msg = sshexec(host, user, option)

  for dnsser in dnsserver
    cmd = "echo \"nameserver #{dnsser}\" >> /etc/resolv.conf"
    option = options
    option[:cmd] = cmd
    # p cmd
    result, msg = sshexec(host, user, option)
  end

  end
  return result, msg
end
