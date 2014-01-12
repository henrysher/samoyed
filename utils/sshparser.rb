require 'service/sshcmd'

def sshparser machineId, machinecfg

  host = machinecfg[machineId]['publicip']
  user = machinecfg[machineId]['user']
  pass = machinecfg[machineId]['password']
  sshkey = machinecfg[machineId]['sshkey']
  proxy = machinecfg[machineId]['proxy']

  options = {}
  if pass != nil
    if pass.size != 0
      options[:password] = pass
    end
  end
  if sshkey != nil 
    if sshkey.size != 0
      options[:keys] = [sshkey]
    end
  end

  if proxy != nil
    if proxy.include?(':')
      proxy = proxy.split(':')
    end
    if proxy.size == 2
      proxy_host = proxy[0]
      proxy_port = proxy[1].to_i
      if proxy_host.size != 0 and proxy_port.size != 0
        result, options[:proxy] = sshproxy(proxy_host, proxy_port)
      end
    end
  end

  return host, user, options
end
