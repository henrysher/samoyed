require 'rubygems'
require 'net/ssh'
require 'utils/indeps'

def openports host, user, options, ports

  output = []
  Net::SSH.start(host, user, options) do |ssh|
    for port in ports
      # p port
        cmd = "/etc/init.d/iptables save"
        out = ssh.exec!(cmd)
        output << out

        cmd = "/sbin/iptables -I INPUT -p tcp --dport #{port} -j ACCEPT"
        out = ssh.exec!(cmd)
        output << out

        cmd = "/etc/init.d/iptables save; /etc/init.d/iptables restart"
        out = ssh.exec!(cmd)
        output << out
    end
  end

  return true, output
end


def fwsetup role, rolecfg, machinecfg, servercfg
  host, user, options, indep, ports = indeps(role, rolecfg, machinecfg)
  if indep.size == 0
    openports(host, user, options, ports)
  else
    msg = "Failed to get the correct platform..."
    return false, msg
  end
  msg = "Open proper ports: #{ports} at the role #{role}"
  return true, msg
end



