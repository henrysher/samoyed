require 'service/sshcmd'

def instvmtool host, user, options={}

  ##FIXME
  return true, "vmtool will not be installed right now...sorry..."

  chgroot = "sudo"
  cmd = "#{chgroot} /usr/sbin/vmware-checkvm"
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)
  msgbox = "VMware software version"
  if msg.include?(msgbox)
    return true, msg
  end

  remotepath  = "/tmp/vmware.tar.gz"
  localpath = "config/ics/VMwareTools-8.6.0-425873.tar.gz"
  options[:remotepath] = remotepath
  options[:localpath] = localpath
  p options
  result, msg = sshupload(host, user, options)
  if not result
    logger.fatal logtitle + "#{msg}"
    puts msg
    return false, msg
  end

  cmd = "#{chgroot} tar -zxvf /tmp/vmware.tar.gz -C /tmp"
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)  
  if not result
    puts msg
    return false, msg
  end

  cmd = "#{chgroot} /tmp/vmware-tools-distrib/vmware-install.pl --default"
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)  
  if not result
    puts msg
    return false, msg
  end

  msg = "Success"
  return true, msg
end


