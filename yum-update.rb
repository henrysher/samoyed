#!/usr/bin/env ruby
$:.unshift File.dirname(__FILE__)
require "utils/parser"
require "build/rdetector"
require "build/rdownloads"
require "build/rpmclean"
require "build/yumupdate"
require 'utils/yumbackup'
require 'utils/yumsync'
require 'utils/sshsync'
require "service/run"
require "utils/logger"
require 'utils/setini'
require 'utils/update'
require 'utils/yumkey'
require "trollop"

begin_time = Time.now.to_i

def delpidf pidfile
  if File.exist?(pidfile)
    begin
      File.unlink(pidfile)
    rescue Exception => msg
      puts msg
      return false, msg
    end
  else
    msg = "#{pidfile} is missing..."
    return false, msg
  end
  return true, msg
end

sbanner = "========== START. =========="
ebanner = "========== Finished. =========="

logfile = "/var/log/samoyed.log"
result, msg = logger(logfile)
if not result
  puts msg
  Process.exit!
end

opts = Trollop::options do
  version "Samoyed 0.1.0 (c) 2012 Henry Huang"
  banner <<-EOS
This is a dog food of ICS product YUM Sync.
Usage :
./yum-update.rb [phase] [buildnum] [repo]
EOS
  opt :phase, "Development phase on this build: beta, dev or rel",  	   :default => "dev"
  opt :buildnum, "Build number for the deployment: 1151", 	   :default => "Latest"
  opt :repo,  "Yum Repo Name for this build: rawhide or local-test", :default => "rawhide"
  opt :sync2us,  "Sync to Yum Repon on US Lab: 10.202.240.157",  :default => "10.202.240.157"
  opt :sync2repos, "Yum Repo Name synced to US Lab: all, ics, ics-base or local-test, etc.", :default => "ics"
  opt :mode, "sync to local or us-lab YUM server: all, local, uslab", :default => "local"
  opt :env, "Development Environment: official or pd",      :type => :string, :default => "official"
  opt :update, "Update samoyed scripts automatically", :type => :bool, :default => false
  opt :flag, "Flag for detecting latest build", :type => :string, :default => nil
end

p opts[:phase], opts[:buildnum], opts[:repo], opts[:sync2us], opts[:sync2repos], opts[:flag]
#FIXME
if opts[:env] == "official"

if opts[:phase] == "dev"
  phase = "ICSS"
  environ = "ics-specific"
elsif opts[:phase] == "beta"
  phase = "ICSS_BETA"
  environ = "ics-beta"
elsif opts[:phase] == "rel"
  phase = "ICSS_REL"
  environ = "ics-release"
else
  logger.error "no such phase"
  exit(status=false)
end

elsif opts[:env] == "pd"
  phase = ""
  environ = "ics-specific"
else
  logger.error "no such env"
  exit(status=false)
end

if opts[:sync2repos] == "ics"
  opts[:sync2repos] = ["ics-base", "rawhide", "cloud-test", "local-test", "stable"]
elsif opts[:sync2repos] == "pd"
  opts[:sync2repos] = ["rawhide"]
elsif opts[:sync2repos] == "temp"
  opts[:sync2repos] = ["temp"]
elsif opts[:sync2repos] == "all"
  opts[:sync2repos] = ["centos-base", "openvm-base", "ics-base", "rawhide", "cloud-test", "local-test", "stable"]
else 
  opts[:sync2repos] = [opts[:sync2repos]]
end


logger = msg
logger.info sbanner
pid = Process.pid
logtitle = "REPOUPDATE::MAIN::"

pidfile = "/tmp/yum-update.pid"

if File.exist?(pidfile)
  begin
    o_file = File.open(pidfile, "r")
    pid = o_file.read().to_i
    o_file.close()
  rescue Exception => msg
    puts msg
    logger.fatal logtitle + "#{msg}"
    logger.info ebanner
    logger.close()
    Process.exit!
  end

  begin
    Process.getpgid(pid)
    msg = "yum-update is running, exit now..."
    puts msg
    logger.fatal logtitle + "#{msg}"
    logger.info ebanner
    logger.close()
    Process.exit!
  rescue Exception => msg
    puts msg
    logger.fatal logtitle + "#{msg}" + ", but #{pidfile} still existing..."
    msg = "Delete the pid file: #{pidfile}"
    puts msg
    begin
      File.unlink(pidfile)
    rescue Exception => msg
      puts msg
      logger.fatal logtitle + "#{msg}"
      logger.info ebanner
      logger.close()
      Process.exit!
    end
    logger.info  logtitle + "#{msg}"
  end
end

begin
  o_file = File.open(pidfile, "w")
  pid = Process.pid
  o_file.write(pid)
  o_file.close()
rescue Exception => msg
  puts msg
  logger.fatal logtitle + "#{msg}"
  logger.info ebanner
  logger.close()
  Process.exit!
end

result, msg = update_rev(opts[:update])
if not result
  exit(status=false)
end
  
build_configFile = "config/build.cfg." + opts[:phase].to_s

resultb, build = parser(build_configFile, "Build")
resultp, project = parser(build_configFile, "Project")
if resultb and resultp
  logger.info logtitle + "BUILDINFO::#{build}"
  logger.info logtitle + "PROJECTINFO:#{project}"
else
  logger.fatal logtitle + "BUILDINFO::#{build}"
  logger.fatal logtitle + "PROJECTINFO::#{project}"
  result, msg  = delpidf(pidfile)
  if result
    logger.info logtitle + "#{msg}"
  else
    logger.fatal logtitle + "#{msg}"
  end

  logger.info ebanner
  logger.close()
  Process.exit!
end

#cmd = "/bin/rm -fv #{build['localpath']}/*"
#result, msg = run(cmd)

project['name'] = phase
build['buildnum'] = opts[:buildnum]

result, download = rdetector(build, project, logger)
if not result
  logger.fatal logtitle + "DETECTOR::#{download}"
  result, msg = delpidf(pidfile)
  if result
    logger.info logtitle + "#{msg}"
  else
    logger.fatal logtitle + "#{msg}"
  end

  logger.info ebanner
  logger.close()
  Process.exit!
end
build_num = download[:num]
logger.info logtitle + "DETECTOR::#{download}"

buildnum = ''
if opts[:flag] == nil
  f_buildnum = "/tmp/buildnum-#{opts[:phase]}.txt"
else 
  f_buildnum = "/tmp/" + opts[:flag].to_s + "-#{opts[:phase]}.txt"
end

if File.exist?(f_buildnum)
    o_file = File.open(f_buildnum, "r")
    buildnum, nrepo = o_file.read().split(',')
    o_file.close()
end

p buildnum, download[:num]
if buildnum != download[:num] or (buildnum == download[:num] and nrepo != opts[:repo])

  result, local = rdownloads(build, download, logger)
  if not result
    logger.fatal logtitle + "DOWNLOAD::#{local}"
    result, msg = delpidf(pidfile)
    if result
      logger.info logtitle + "#{msg}"
    else
      logger.fatal logtitle + "#{msg}"
    end

    logger.info ebanner
    logger.close()
    Process.exit!
  end
  logger.info logtitle + "DOWNLOAD::#{local}"

  repo_configFile = "config/yumrepo.cfg." + opts[:phase].to_s
  yumkey(repo_configFile)

  section = "YumRepo"
  result, yumrepo = parser(repo_configFile, section)
  if not result
    logger.fatal logtitle + "YUMUPDATE::#{yumrepo}"
    result, msg = delpidf(pidfile)
    if result
      logger.info logtitle + "#{msg}"
    else
      logger.fatal logtitle + "#{msg}"
    end

    logger.info ebanner
    logger.close()
    Process.exit!
  end
  yumrepo['environ'] = environ
  yumrepo['testing'] = opts[:repo]
  yumrepo['repocfg'] = "config/ics/ics.repo." + opts[:phase].to_s
  logger.info logtitle + "YUMUPDATE::#{yumrepo}"

  role_configFile = "config/role.cfg." + opts[:phase].to_s
  result, rolecfg = parser(role_configFile)
  if not result
    logger.fatal logtitle + "YUMUPDATE::#{rolecfg}"
    result, msg = delpidf(pidfile)
    if result
      logger.info logtitle + "#{msg}"
    else
      logger.fatal logtitle + "#{msg}"
    end

    logger.info ebanner
    logger.close()
    Process.exit!
  end
  logger.info logtitle + "YUMUPDATE::#{rolecfg}"

  if opts[:mode].downcase == "local" or opts[:mode].downcase == "all"

  result, msg = rpmclean(yumrepo, local, rolecfg, build_num, logger)
  if not result
    logger.fatal msg
    logger.close()
    Process.exit!
  end

  result, msg = yumupdate(yumrepo, local, rolecfg, logger)
  if not result
    logger.fatal logtitle + "YUMUPDATE::#{msg}"
    result, msg = delpidf(pidfile)
    if result
      logger.info logtitle + "#{msg}"
    else
      logger.fatal logtitle + "#{msg}"
    end

    logger.info ebanner
    logger.close()
    Process.exit!
  end
  logger.info logtitle + "YUMUPDATE::#{msg}"
  buildnum = download[:num]
  end

  if opts[:mode].downcase == "uslab" or opts[:mode].downcase == "all"

  backuppath = []
  for repo in opts[:sync2repos]
    result, msg = yumbackup(repo, yumrepo, logger)
    backuppath << msg
  end

  remoteIp = opts[:sync2us]

  privatekey = "config/ics/#{remoteIp}.private.key"
  cmd = "/bin/chmod 400 #{privatekey}"
  result, msg = run(cmd)

  remotepath = "/var/www/html/"
  splitter = yumrepo['project']
  for localpath in backuppath
    result, msg = yumsync(remoteIp, remotepath, localpath, splitter)
  end

  end

else
  msg = " --> your build is latest, so no need to update <--"
  logger.info msg
  logger.close()
  Process.exit!
end

begin
  o_file = File.open(f_buildnum, "w")
  o_file.write(buildnum + ',' + opts[:repo])
  o_file.close()
rescue Exception => msg
  logger.fatal logtitle = "#{msg}"
  puts msg
end

if File.exist?(pidfile)
  begin
    File.unlink(pidfile)
  rescue Exception => msg
    puts msg
    logger.fatal  logtitle + "#{msg}"
  end
end

end_time = Time.now.to_i
duration = (end_time - begin_time)/60

puts "=======> [Executed Duration: #{duration} minutes] <======="
logger.info  ebanner
logger.close()

  
