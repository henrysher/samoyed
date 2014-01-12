#!/usr/bin/env ruby
$:.unshift File.dirname(__FILE__)
require 'rubygems'
require 'service/run'

pid = Process.pid
pidfile = "/tmp/cloud-yum-sync.pid"

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
    msg = "cloud-yum-sync is running, exit now..."
    puts msg
    Process.exit!
  rescue Exception => msg
    puts msg
    msg = "Delete the pid file: #{pidfile}"
    puts msg
    begin
      File.unlink(pidfile)
    rescue Exception => msg
      puts msg
      Process.exit!
    end
  end
end

begin
  o_file = File.open(pidfile, "w")
  pid = Process.pid
  o_file.write(pid)
  o_file.close()
rescue Exception => msg
  puts msg
  Process.exit!
end

def prepare_key localpath, remotepath="/root/.s3cfg"
  cmd = "/bin/cp -v #{localpath}  #{remotepath}"
  result, msg = run(cmd)
end

def s3sync localpath, remotepath
  localdir = File.dirname(localpath)
  filedir = File.basename(localpath)
  cmd = "cd #{localdir}; /usr/local/bin/s3cmd sync #{filedir}/* #{remotepath}/ --delete-removed -v " 
  result, msg = run(cmd)
end

def yumsync buckets, sync_repos, base_localdir, base_remotedir 
  for bucket in buckets 
    for repo in sync_repos
      remotepath = File.join( "s3://#{bucket}", base_remotedir, repo)
      localpath = File.join(base_localdir, repo)
      s3sync(localpath, remotepath) 
    end
  end
end

## Dev Account ##
sync_repos = ["ics-base", "ics-release", "ics-specific"]
version = "1.0"
base_localdir = "/var/www/html/zKiller/ics/#{version}/devel"
base_remotedir = "/yum/ics/#{version}/devel/"

buckets = ["zkiller-repo"]
prepare_key("/root/.s3cfg_stg")
yumsync(buckets, sync_repos, base_localdir, base_remotedir)

## QA Account ##
buckets = ["icsqa-yum-uw2"]
prepare_key("/root/.s3cfg_qa")
yumsync(buckets, sync_repos, base_localdir, base_remotedir)

## Pro Account ##
buckets = ["ics-yum-ue-pro", "ics-yum-uw2-pro", "ics-yum-as-pro", "ics-yum-as2-pro", "ics-yum-se-pro"]
prepare_key("/root/.s3cfg_pro")
yumsync(buckets, sync_repos, base_localdir, base_remotedir)

## Beta Account ##
buckets = ["ics-yum-uw2-eb"]
prepare_key("/root/.s3cfg_beta")
yumsync(buckets, sync_repos, base_localdir, base_remotedir)

if File.exist?(pidfile)
  begin
    File.unlink(pidfile)
  rescue Exception => msg
    puts msg
  end
end
