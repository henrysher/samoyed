require 'rubygems'
require 'net/ssh'
require 'utils/sshparser'
require 'utils/parser'

def ntpsetup role, rolecfg, machinecfg, servercfg
  
  machines = rolecfg[role]['machine'].split(',')
  for machineId in machines

  host, user, options = sshparser(machineId, machinecfg)
  ntpserver = servercfg['Common Server']['NTP']

  cmd = "/etc/init.d/ntpd stop"
  option = options
  option[:cmd] = cmd
  # p cmd
  result, msg = sshexec(host, user, option)

  cmd = "ntpdate #{ntpserver}"
  option = options
  option[:cmd] = cmd
  # p cmd
  result, msg = sshexec(host, user, option)

  cmd = "sed -i \"s/server/#server/g\"  /etc/ntp.conf"
  option = options
  option[:cmd] = cmd
  # p cmd
  result, msg = sshexec(host, user, option)

  cmd = "echo \"server #{ntpserver}\" >> /etc/ntp.conf"
  option = options
  option[:cmd] = cmd
  # p cmd
  result, msg = sshexec(host, user, option)

  cmd = "/etc/init.d/ntpd restart"
  option = options
  option[:cmd] = cmd
  # p cmd
  result, msg = sshexec(host, user, option)

  cmd = "/sbin/chkconfig ntpd --level 2345 on"
  option = options
  option[:cmd] = cmd
  # p cmd
  result, msg = sshexec(host, user, option)
  end
end
