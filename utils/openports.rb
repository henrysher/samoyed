require 'rubygems'
require 'net/ssh'

def openports host, user, pass, ports, timeout=10, verbose=false
  ports = ports.split(',')
  output = []
  Net::SSH.start(host, user, :password => pass, :timeout => timeout, :verbose => verbose) do |ssh|
    for port in ports
      p port
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

