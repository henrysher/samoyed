require "utils/runfw"
require "utils/ntp"
require "utils/dns"

def srvcfg vpath, role, rolecfg, machinecfg, servercfg, buildno=nil, bucket=nil, logger
  logtitle = "SRVCFG::"

  script = rolecfg[role]['script']

#  logger.info logtitle + "firewall setup..."
#  result, msg = runfw(vpath, role, rolecfg, machinecfg, servercfg)
#  logger.info logtitle + "#{msg}"
#  if not result
#    logger.fatal logtitle + "#{msg}"
#    return false, msg
#  end
  
  logger.info logtitle + "DNS setup..."
  result, msg = rundns(vpath, role, rolecfg, machinecfg, servercfg)
  logger.info logtitle + "#{msg}"
  if not result
    logger.fatal logtitle + "#{msg}"
    return false, msg
  end

  logger.info logtitle + "NTP setup..."
  result, msg = runntp(vpath, role, rolecfg, machinecfg, servercfg)
  logger.info logtitle + "#{msg}"
  if not result
    logger.fatal logtitle + "#{msg}"
    return false, msg
  end

  require "#{vpath}/#{script}"
  logger.info logtitle + "require #{vpath}/#{script}"
  
  result, msg = runcfg(rolecfg, machinecfg, buildno, bucket)
  logger.info logtitle + "#{msg}"
  if not result
    logger.fatal logtitle + "#{msg}"
    return false, msg
  end

  result, msg = runsrv(rolecfg, machinecfg)
  logger.info logtitle + "#{msg}"
  if not result
    logger.fatal logtitle + "#{msg}"
    return false, msg
  end

  msg = "Successfully finish service configuration for the role #{role}..."
  logger.info logtitle + "#{msg}"
  return true, msg

end


