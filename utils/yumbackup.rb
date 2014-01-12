require 'service/run'
require 'utils/setini'
require 'utils/parser'
require 'utils/copy'
require 'rubygems'
require 'nokogiri'

def repobackup repo, repocfg, backuppath, splitter, localpath

  p repo, repocfg, backuppath, localpath

  tmprcfg = "/tmp/ics.repo"
  result, msg = copy(repocfg, tmprcfg)
  if not result
    puts msg
    return false, msg
  end

  setini(tmprcfg, '', 'enabled', '0', true)

  result, repoinfo = parser(repocfg, repo)
  p repoinfo
  baseurl = repoinfo["baseurl"]
  lastfolder = baseurl.split(splitter)[-1]
  
  setini(tmprcfg, repo, 'enabled', '1')

  backuppath = File.join(backuppath, lastfolder)
  p backuppath

  cmd = "/bin/mv /etc/yum.repos.d/CentOS*.repo /tmp"
  result, msg = run(cmd)

  cmd = "/bin/mkdir -p #{backuppath}"
  result, msg = run(cmd)


  ics_repo = tmprcfg.split('/')[-1]
  cmd = "/bin/cp -f #{tmprcfg} /etc/yum.repos.d/#{ics_repo}"
  result, msg = run(cmd)
  if not result
    return false, msg
  end

  cmd = "/usr/bin/yum clean all"
  result, msg = run(cmd)
  if not result
    return false, msg
  end

  cmd = "/usr/bin/reposync -r #{repo} -d -p #{backuppath} -n -m "
  result, msg = run(cmd)
  if not result
    return false, msg
  end

  # Never use openvm-base repo since now
  repotypes = ["ics-base","centos-base"]
  # repotypes = ["ics-base","centos-base","openvm-base"]
  if repotypes.include?(repo)
    cmd = "/usr/bin/createrepo #{backuppath}"
    result, msg = run(cmd)
    if not result
      return false, msg
    end
    return true, backuppath
  end


  cmd = "/usr/bin/createrepo -g #{backuppath}/comps.xml #{backuppath}"
  result, msg = run(cmd)
  if not result
    return false, msg
  end
  return true, backuppath

end

def yumbackup  repo, yumrepo, logger
  logtitle = "YumBackup::"
  logger.info "========== ENTERING YUMREPO UPDATE =========="
  begin
    server = yumrepo["server"]
    project = yumrepo["project"]
    version = yumrepo["version"]
    release = yumrepo["release"]
    environ = yumrepo["environ"]
    testing = yumrepo["testing"]
    platform = yumrepo["platform"]

    repocfg = yumrepo["repocfg"]
    entrypath = yumrepo["backuppath"]
    
    remotepath = yumrepo["remotepath"]
    localpath = yumrepo["localpath"]

  rescue Exception => msg
    puts msg
    logger.fatal logtitle + "#{msg}"
    return false, msg
  end

  begin
    ## FIXME: Hardcoded here.
    yumbackup = File.join(
      entrypath,
      yumrepo["project"]
      #yumrepo["remotepath"],
      #yumrepo["version"],
      #yumrepo["release"]
      #yumrepo["environ"],
      #yumrepo["testing"]
    )
  rescue Exception => msg
    puts msg
    logger.fatal logtitle + "#{msg}"
    return false, msg
  end

  splitter = yumrepo["project"]

  p yumbackup
  ## FIXME patch on /usr/bin/reposync
  begin
    o_file = File.open("/usr/bin/reposync","r")
    content = o_file.read()
    o_file.close()
    content = content.gsub(/local_repo_path = opts\.destdir \+ \'\/\' \+ repo\.id/, "local_repo_path = opts.destdir")
    o_file = File.open("/usr/bin/reposync", "w")
    o_file.write(content)
    o_file.close()
  rescue Exception => msg
    return false, msg
  end

  p repo
  result, msg = repobackup(repo, repocfg, yumbackup, splitter, localpath)
  if not result
    logger.fatal logtitle + "--> #{repo} <-- " + "#{msg}"
    return result, msg
  else
    mmsg = "Success"
    logger.info logtitle + "--> #{repo} <-- " + "#{mmsg}"
  end
  
  return true, msg
end

