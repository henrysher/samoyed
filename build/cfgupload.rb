require 'service/sshcmd'
require 'service/run'
require 'utils/setini'
require 'utils/copy'
require 'utils/awskey'
require 'utils/sshparser'

def s3cfg_gen cfgpath, logger
    logtitle = "CfgGen::"
    chgroot = ""
    cmd = "#{chgroot} /bin/cp -fv config/ics/config-autotest.ini /opt/icsops/tools/s3config/tagreplace/"
    logger.info logtitle + "#{cmd}"
    result, msg = run(cmd)
    logger.info logtitle + "#{msg}"
    if not result
      return false, msg
    end

    cmd = "#{chgroot} /bin/cp -fv config/ics/config.ini /opt/icsops/tools/s3config/tagreplace/"
    logger.info logtitle + "#{cmd}"
    result, msg = run(cmd)
    logger.info logtitle + "#{msg}"
    if not result
      return false, msg
    end

    cmd = "#{chgroot} /bin/cp -fv /opt/icsops/tools/s3config/templategenerator/#{cfgpath} /opt/icsops/tools/s3config/tagreplace/"
    logger.info logtitle + "#{cmd}"
    result, msg = run(cmd)
    logger.info logtitle + "#{msg}"
    if not result
      return false, msg
    end

    cmd = "cd /opt/icsops/tools/s3config/tagreplace/; #{chgroot} ./GenerateAllRegionsConfig.sh #{cfgpath}"
    logger.info logtitle + "#{cmd}"
    result, msg = run(cmd)
    logger.info logtitle + "#{msg}"
    if not result
      return false, msg
    end

    cmd = "cd /opt/icsops/tools/s3config/tagreplace/; #{chgroot} ./ConfigGenerate.sh #{cfgpath}"
    logger.info logtitle + "#{cmd}"
    result, msg = run(cmd)
    logger.info logtitle + "#{msg}"
    if not result
       return false, msg
    end

    return true, "Success"
end

def cfgupload cfgpath, bucket, buildno, yumrepo, logger, mode=false
  logtitle = "CfgUpload::"
  logger.info "========== Entering ICS Configuration Installation =========="
  ## FIXME
  awskey()

  # environ = yumrepo["environ"]
  testing = yumrepo["testing"]
  repocfg = yumrepo["repocfg"]

  tmprpath = "/tmp/ics.repo"
  result, msg = copy(repocfg, tmprpath)
  if not result
    puts msg
    return false, msg
  end

  result, msg = setini(tmprpath, '', 'enabled', '0', true)
  result, msg = setini(tmprpath, 'centos-base', 'enabled', '1')
  result, msg = setini(tmprpath, 'ics-base', 'enabled', '1')
  result, msg = setini(tmprpath, testing, 'enabled', '1')

  if not result
    logger.fatal logtitle + "#{msg}"
    puts msg
    return false, msg
  end

  cmd = "/bin/mkdir -p /tmp/backup"
  result, msg = run(cmd)

  cmd = "/bin/mv /etc/yum.repos.d/*.repo /tmp/backup"
  result, msg = run(cmd)

  ics_repo = tmprpath.split('/')[-1]
  cmd = "/bin/cp -f #{tmprpath} /etc/yum.repos.d/#{ics_repo}"
  result, msg = run(cmd)
  if not result
    return false, msg
  end

  ## FIXME 
  chgroot = ""

  cmd = "/usr/bin/yum info IWSVA | awk '$1 ~ /Version/ {print $3}' | awk 'BEGIN  { FS = \".\" }; {print $1$2}'"
  logger.info logtitle + "#{cmd}"
  result, msg = run(cmd)
  logger.info logtitle + "#{msg}"
  if not result
    return false, msg
  end
  version = msg

  cmd = "#{chgroot} /usr/bin/yum remove -y ICS-S3Config-Generator ICS-S3Config-Template"
  logger.info logtitle + "#{cmd}"
  result, msg = run(cmd)
  logger.info logtitle + "#{msg}"

  cmd = "#{chgroot} /bin/rm -fr /opt/icsops/tools/"
  logger.info logtitle + "#{cmd}"
  result, msg = run(cmd)
  logger.info logtitle + "#{msg}"

  cmd = "#{chgroot} /usr/bin/yum clean all"
  logger.info logtitle + "#{cmd}"
  result, msg = run(cmd)
  logger.info logtitle + "#{msg}"
  
  cmd = "#{chgroot} /usr/bin/yum install -y ICS-S3Config-Generator ICS-S3Config-Template"
  logger.info logtitle + "#{cmd}"
  result, msg = run(cmd)
  logger.info logtitle + "#{msg}"
  ## FIXME: no error handling
  if not result
    return false, msg
  end

  cmd = "#{chgroot} /bin/rpm -qa | grep ICS-S3Config-Generator"
  logger.info logtitle + "#{cmd}"
  result, msg = run(cmd)
  logger.info logtitle + "#{msg}"
  if not msg.include?(buildno)
     msg = "No such build #{buildno} in this YUM..."
     return false, msg
  end

  cmd = "#{chgroot} /bin/rpm -qa | grep ICS-S3Config-Template"
  logger.info logtitle + "#{cmd}"
  result, msg = run(cmd)
  logger.info logtitle + "#{msg}"
  if not msg.include?(buildno)
     msg = "No such build #{buildno} in this YUM..."
     return false, msg
  end

  cfgpath =  File.basename(cfgpath)
  cfgpath = cfgpath.gsub(/{version}/, version)
  result, msg = s3cfg_gen(cfgpath, logger)
    if not result
      if msg.downcase.include?("tags are not replaced")
        puts "\n=======================================================\n"
        puts "Some Tags are missing in config/ics/config-autotest.ini\n"
        puts "Now run 'UpdateConfigTag' to add missing tags\n"
        puts "=======================================================\n"
        cmd = "cd /opt/icsops/tools/s3config/tagreplace/; #{chgroot} /usr/bin/perl UpdateConfigTag config-autotest.ini config-beta-as.ini config-autotest-new.ini"
        logger.info logtitle + "#{cmd}"
        result, msg = run(cmd)
        logger.info logtitle + "#{msg}"

        timestamp = Time.now.year.to_s + "-" + Time.now.mon.to_s + "-" + Time.now.day.to_s + "-" + Time.now.hour.to_s + "-" + Time.now.min.to_s
        cmd = "#{chgroot} /bin/cp -fv config/ics/config-autotest.ini config/ics/config-autotest.ini.#{timestamp}"
        logger.info logtitle + "#{cmd}"
        result, msg = run(cmd)
        logger.info logtitle + "#{msg}"

        cmd = "#{chgroot} /bin/cp -fv /opt/icsops/tools/s3config/tagreplace/config-autotest-new.ini config/ics/config-autotest.ini"
        logger.info logtitle + "#{cmd}"
        result, msg = run(cmd)
        logger.info logtitle + "#{msg}"

        puts "\nPlease check the new generated S3 Tag config file 'config/ics/config-autotest.ini'.  \n" 
        puts "After your update, please re-run this tool again. \n"
        msg = ""
      end
      if not mode
        return false, msg
      end
      result, msg = s3cfg_gen(cfgpath, logger)
      if not result
        return false, msg
      end
    end

  # cmd = "cd /opt/icsops/tools/s3config/tagreplace/Output/; #{chgroot} tar zxvf s3_config.tgz"
  # logger.info logtitle + "#{cmd}"
  # result, msg = run(cmd)
  # logger.info logtitle + "#{msg}"
  # if not result
  #   return false, msg
  # end

  ## FIXME: so many hardcoded
  s3cfg_path = File.join(Dir.pwd, "config/ics/s3cfg")
  cmd = "cd /opt/icsops/tools/s3config/tagreplace/output/s3_config/us-west-2/; /usr/local/bin/s3cmd sync -c #{s3cfg_path} . s3://#{bucket}/ --verbose"
  logger.info logtitle + "#{cmd}"
  result, msg = run(cmd)
  logger.info logtitle + "#{msg}"
  ## FIXME no error handling
  if not result
    return false, msg
  end

  msg = "Success"
  logger.fatal logtitle + "#{msg}"
  return true, msg
end

