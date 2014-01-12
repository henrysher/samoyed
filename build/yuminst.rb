require 'service/sshcmd'
require 'utils/setini'
require 'utils/copy'
require 'utils/sshparser'

def yuminst role, enabled, rolecfg, machinecfg, repopath, testing, logger
  logtitle = "YumInst::"
  logger.info "========== Entering YUM Installation =========="

  baserepo = rolecfg[role]['baserepo'].split(',')
  baserepo << testing
  packages = rolecfg[role]['packages'].split(' ')

  machines = rolecfg[role]['machine'].split(',')

  for machineId in machines

  host, user, options = sshparser(machineId, machinecfg)
  p host, user, options

  if role.include?("cassandra")
    role = "cassandra"
  end

  ## FIXME 
  chgroot = "sudo"

  cmd = "/bin/sed -i \"s/Defaults.*requiretty/#Defaults  requiretty/g\" /etc/sudoers"
  # p cmd
  logger.info logtitle + "#{cmd}"
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)
  logger.info logtitle + "#{msg}"

  cmd = "/bin/sed -i \"s/rhgb//g\" /boot/grub/grub.conf"
  logger.info logtitle + "#{cmd}"
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)
  logger.info logtitle + "#{msg}"

  cmd = "/bin/sed -i \"s/#\\*\\.\\* @@remote-host/\\*\\.\\* @@10.204.133.240/g\" /etc/rsyslog.conf"
  logger.info logtitle + "#{cmd}"
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)
  logger.info logtitle + "#{msg}"

  cmd = "/bin/mv /etc/localtime /tmp"
  logger.info logtitle + "#{cmd}"
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)
  logger.info logtitle + "#{msg}"

  cmd = "/bin/ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime"
  logger.info logtitle + "#{cmd}"
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)
  logger.info logtitle + "#{msg}"

  cmd = "date"
  logger.info logtitle + "#{cmd}"
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)
  logger.info logtitle + "#{msg}"

  # FIXME: scanner will read this file to take its own dhcp hooks and make things bad
  cmd = "#{chgroot} /bin/rm -fv /var/lib/dhclient/resolv.conf.predhclient.eth0"
  # p cmd
  option = options
  option[:cmd] = cmd
  result, msg = sshexec(host, user, option)
  if not result
    return false, msg
  end

  tmprpath = "/tmp/ics.repo"
  result, msg = copy(repopath, tmprpath)
  if not result
    logger.fatal logtitle + "#{msg}"
    puts msg
    return false, msg
  end

  p enabled
  if enabled.include?(',')
    enableds = enabled.split(',')
  else
    enableds = enabled
  end

  if enabled == "enabled"
    enableds = ["enabled"]
  end

  for enabled in enableds
    result, msg = setini(tmprpath, '', enabled, '0', true)
    if not result
      logger.fatal logtitle + "#{msg}"
      puts msg
      return false, msg
    end

    for repo in baserepo
      setini(tmprpath, repo, enabled, '1')
    end
  end

  ## FIXME
  cmd = "#{chgroot} mkdir -p /tmp/repobackup; #{chgroot} /bin/mv /etc/yum.repos.d/*.repo /tmp/repobackup"
  # p cmd
  logger.info logtitle + "#{cmd}"
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)
  logger.info logtitle + "#{msg}"

  ics_repo = tmprpath.split('/')[-1]
  remotepath = "/tmp/#{ics_repo}"
  options[:remotepath] = remotepath
  options[:localpath] = tmprpath
  result, msg = sshupload(host, user, options)
  if not result
    logger.fatal logtitle + "#{msg}"
    return false, msg
  end

  options[:remotepath] = "/etc/motd"
  options[:localpath] = "config/ics/motd"
  result, msg = sshupload(host, user, options)
  if not result
    logger.fatal logtitle + "#{msg}"
    return false, msg
  end

  cmd = "#{chgroot} /bin/cp -f /tmp/#{ics_repo} /etc/yum.repos.d/"
  # p cmd
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)
  if not result
    logger.fatal logtitle + "#{msg}"
    return false, msg
  end

  cmd = "#{chgroot} /usr/bin/yum clean all"
  # p cmd
  logger.info logtitle + "#{cmd}"
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)
  if not result
    logger.fatal logtitle + "#{msg}"
    return false, msg
  end

  cmd = "#{chgroot} /usr/bin/yum grouplist"
  # p cmd
  logger.info logtitle + "#{cmd}"
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)
  if not result
    logger.fatal logtitle + "#{msg}"
    return false, msg
  end

  ## FIXME
  role_exclude_list = ["forwardproxy", "yumready","monitor", "splunk", "skynetagent", "ceagent", "cdnserver", "scoagent"]
  if not msg.include?(role) and not role_exclude_list.include?(role)
    msg = "No such group in YUM repo..."
    logger.fatal logtitle + "#{msg}"
    return false, msg
  end

  ## FIXME
  cmd = "#{chgroot} /usr/bin/yum install ntp -y"
  # p cmd
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)
  if not result
    logger.fatal logtitle + "#{msg}"
    puts msg
    return false, msg
  end

  cmd = "#{chgroot} /usr/bin/yum install openssh-clients telnet wget vim -y"
  # p cmd
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)
  if not result
    logger.fatal logtitle + "#{msg}"
    puts msg
    return false, msg
  end

  if not role_exclude_list.include?(role)
    cmd = "#{chgroot} /usr/bin/yum groupinstall #{role} -y"
    # p cmd
    logger.info logtitle + "#{cmd}"
    options[:cmd] = cmd
    result, msg = sshexec(host, user, options)
    logger.info logtitle + "#{msg}"
    if not result
      logger.fatal logtitle + "#{msg}"
      return false, msg
    end
  end

  for package in packages
    cmd = "#{chgroot} /bin/rpm -qa #{package}"
    # p cmd
    logger.info logtitle + "#{cmd}"
    options[:cmd] = cmd
    result, msg = sshexec(host, user, options)
    if not result
      logger.fatal logtitle + "#{msg}"
      return false, msg
    end
    if not msg.include?(package)
      msg = "Missing this package: #{package}..."
      logger.fatal logtitle + "#{msg}"
      return false, msg
    end
  end

  cmd = "#{chgroot} /usr/bin/yum install ICS-BootStrap  -y"
  # p cmd
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)
  if not result
    logger.fatal logtitle + "#{msg}"
    puts msg
    return false, msg
  end

  cmd = "#{chgroot} /usr/bin/yum install ICS-Splunk-Client  -y"
  # p cmd
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)
  if not result
    logger.fatal logtitle + "#{msg}"
    puts msg
    return false, msg
  end

  cmd = "#{chgroot} /usr/bin/yum install rubygem-aws-sdk rubygem-json  -y"
  # p cmd
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)
  if not result
    logger.fatal logtitle + "#{msg}"
    puts msg
    return false, msg
  end

  # FIXME
  cmd = "#{chgroot} /sbin/chkconfig stage2 off"
  # p cmd
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)
  if not result
    logger.fatal logtitle + "#{msg}"
    puts msg
    return false, msg
  end

  cmd = "#{chgroot} /sbin/chkconfig stage3 off"
  # p cmd
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)
  if not result
    logger.fatal logtitle + "#{msg}"
    puts msg
    return false, msg
  end

  cmd = "#{chgroot} /usr/bin/yum install net-snmp  -y"
  # p cmd
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)
  if not result
    logger.fatal logtitle + "#{msg}"
    puts msg
    return false, msg
  end

  cmd = "#{chgroot} /sbin/chkconfig snmpd --level 2345 on"
  # p cmd
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)
  if not result
    logger.fatal logtitle + "#{msg}"
    puts msg
    return false, msg
  end

  cmd = "#{chgroot} /sbin/chkconfig iptables --level 2345 off"
  # p cmd
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)
  if not result
    logger.fatal logtitle + "#{msg}"
    puts msg
    return false, msg
  end

  cmd = "#{chgroot} /sbin/chkconfig ip6tables --level 2345 off"
  # p cmd
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)
  if not result
    logger.fatal logtitle + "#{msg}"
    puts msg
    return false, msg
  end

  cmd = "#{chgroot} /bin/rm -f /opt/trend/tmicss/etc/configs_downloaded"
  # p cmd
  options[:cmd] = cmd
  result, msg = sshexec(host, user, options)
  if not result
    logger.fatal logtitle + "#{msg}"
    puts msg
    return false, msg
  end
 end

 msg = "Success"
 logger.fatal logtitle + "#{msg}"
 return true, msg
end

