require 'net/ftp'
require 'service/run'
require 'utils/crypt'
require 'utils/setini'
require 'utils/copy'
require 'rubygems'
require 'nokogiri'

def repoupdate role, rolecfg, repocfg, testing, localpath
  p role
  baserepo = rolecfg[role]['baserepo'].split(',')
  baserepo << testing

  packages = rolecfg[role]['packages']

  tmprcfg = "/tmp/ics.repo"
  result, msg = copy(repocfg, tmprcfg)
  if not result
    puts msg
    return false, msg
  end

  setini(tmprcfg, '', 'enabled', '0', true)

  for repo in baserepo
    # FIXME
    if role.include?("cassandra") and repo == "centos-base"
      next
    end
    setini(tmprcfg, repo, 'enabled', '1')
  end

  cmd = "/bin/mv -fv /etc/yum.repos.d/CentOS*.repo /tmp"
  result, msg = run(cmd)

  ics_repo = tmprcfg.split('/')[-1]
  cmd = "/bin/cp -f #{tmprcfg} /etc/yum.repos.d/#{ics_repo}"
  # p cmd
  result, msg = run(cmd)
  if not result
    return false, msg
  end

  cmd = "/usr/bin/yum clean all"
  # p cmd
  result, msg = run(cmd)
  if not result
    return false, msg
  end

  cmd = "/usr/bin/createrepo #{localpath}"
  # p cmd
  result, msg = run(cmd)
  if not result
    return false, msg
  end

  cmd = "/usr/bin/yum-groups-manager -n \"#{role}\" --id=#{role} --save=\"/tmp/#{role}_comps.xml\" --mandatory #{packages} --dependencies"
  # p cmd
  result, msg = run(cmd)
  if not result
    return false, msg
  end
 
  msg = "Success"
  return true, msg

end

def groupupdate roles, localpath
  begin
    groupxml = File.open("/tmp/all_comps.xml", "w")
  rescue Exception => msg
    return false, msg
  end
 
  groupheader = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n
                <!DOCTYPE comps PUBLIC \"-//Red Hat, Inc.//DTD Comps info//EN\" \"comps.dtd\">\n
                <comps>\n"
  groupxml.write(groupheader)

  for role in roles
    begin
      rolexml = File.open("/tmp/#{role}_comps.xml")
      groupinfo = Nokogiri::XML(rolexml).xpath("//comps//group").to_s
      rolexml.close()
      groupxml.write(groupinfo)
    rescue Exception => msg
      return false, msg
    end
  end

  groupend = "</comps>\n"
  groupxml.write(groupend)
  groupxml.close()

  cmd = "/usr/bin/createrepo --update -g /tmp/all_comps.xml #{localpath}"
  result, msg = run(cmd)
  if not result
    return false, msg
  end

  cmd = "/usr/bin/yum clean all"
  result, msg = run(cmd)
  if not result
    return false, msg
  end

  msg = "Sucess"
  return true, msg
end

def yumupdate  yumrepo, local, rolecfg, logger
  logtitle = "YumUpdate::"
  logger.info "========== ENTERING YUMREPO UPDATE =========="
  begin
    server = yumrepo["server"]
    project = yumrepo["project"]
    version = yumrepo["version"]
    release = yumrepo["release"]
    environ = yumrepo["environ"]
    testing = yumrepo["testing"]
    platform = yumrepo["platform"]
    
    remotepath = yumrepo["remotepath"]
    localpath = yumrepo["localpath"]

    username = yumrepo["username"]
    password =yumrepo["password"]
    role = yumrepo["role"]
    repocfg = yumrepo["repocfg"]
    keypass = yumrepo["keypass"]

  rescue Exception => msg
    puts msg
    logger.fatal logtitle + "#{msg}"
    return false, msg
  end

  begin
    ## FIXME: Hardcoded here.
    buildurl = 'ftp://' + server
    if not yumrepo.include?("prefix")
      project_prefix = "project"
    else
      project_prefix = yumrepo["prefix"]
    end
    buildurl = File.join(
      buildurl, 
      project_prefix,
      yumrepo["project"],
      yumrepo["remotepath"],
      yumrepo["version"],
      yumrepo["release"],
      yumrepo["environ"],
      yumrepo["testing"]
      #yumrepo["platform"]
    )
  rescue Exception => msg
    puts msg
    logger.fatal logtitle + "#{msg}"
    ftp.close()
    return false, msg
  end

  begin
    key_file = open(keypass, 'rb')
    key_text = key_file.read()
    key_file.close()
  rescue Exception => msg
    logger.fatal logtitle + "#{msg}"
    return false, msg
  end
  logger.info logtitle + "#{buildurl}"

  cmd = "/bin/mkdir -p #{localpath}"
  result, msg = run(cmd)
  logger.info logtitle + "#{cmd}"
  logger.info logtitle + "#{msg}"

  cmd = "/bin/umount #{localpath}"
  result, msg = run(cmd)
  logger.info logtitle + "#{cmd}"
  logger.info logtitle + "#{msg}"

  cmd = "/bin/rm -rf #{localpath}"
  result, msg = run(cmd)
  logger.info logtitle + "#{cmd}"
  logger.info logtitle + "#{msg}"

  cmd = "/bin/mkdir -p #{localpath}"
  logger.info logtitle + "#{cmd}"
  result, msg  = run(cmd)
  if not result
    logger.fatal logtitle + "#{msg}"
    return false, msg
  end

  password = decrypt(password, key_text)
  cmd = "/usr/bin/curlftpfs #{buildurl} #{localpath} -o user=#{username}:#{password}"
  #logger.info logtitle + "#{cmd}"
  result, msg  = run(cmd, false)
  if not result
    logger.fatal logtitle + "#{msg}"
    return false, msg
  end

  ## FIXME: hardcoded #{old} folder
  cmd = "/bin/mkdir -p #{localpath}/old"
  logger.info logtitle + "#{cmd}"
  result, msg = run(cmd)
  if not result
    logger.fatal logtitle + "#{msg}"
    return false, msg
  end

  ## FIXME: one build might not have all packages except "rawhide" "temp" repos
  if testing.downcase.include?("rawhide") or testing.downcase.include?("temp")
    cmd = "/bin/rm -rf #{localpath}/#{platform}/*"
    logger.info logtitle + "#{cmd}"
    result, msg = run(cmd)
    logger.info logtitle + "#{msg}"
  end

  localp = localpath
  localpath = File.join(localpath, platform)
  for package in local
    cmd = "/bin/cp -fv #{package} #{localpath}"
    logger.info logtitle + "#{cmd}"
    result, msg = run(cmd)
    if not result
      logger.fatal logtitle + "#{msg}"
      return false, msg
    end
  end

  roles = role.split(',')
  for role in roles
    result, msg = repoupdate(role, rolecfg, repocfg, testing, localpath)
    if not result
      logger.fatal logtitle + "--> #{role} <-- " + "#{msg}"
      return result, msg
    else
      logger.info logtitle + "--> #{role} <-- " + "#{msg}"
    end
  end
  result, msg = groupupdate(roles, localpath)
  if not result
    logger.fatal logtitle + "#{msg}"
    return result, msg
  else
    logger.info logtitle + "#{msg}"
  end

  cmd = "/bin/umount #{localp}"
  logger.info logtitle + "#{cmd}"
  result, msg = run(cmd)
  if not result
    logger.fatal logtitle + "#{msg}"
    return false, msg
  end

  msg = "Success"
  logger.info logtitle + "#{msg}"
  return true, msg
end

