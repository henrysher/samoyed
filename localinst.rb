#!/usr/bin/env ruby
$:.unshift File.dirname(__FILE__)
require "utils/parser"
require "utils/setini"
require "build/rdetector"
require "build/rdownloads"
require "utils/vmdeploy"
require "utils/logger"
require "utils/update"
require "utils/sshsync"
require "utils/detectbuild"
require "trollop"

all_roles = ["mysql","mongodb","cassandras","globalcache","adminui","logquery","logserver","alertserver","scanner","logclient","ldapserver", "skynetagent", "ceagent", "cdnserver", "scoagent"]
nodb_roles = ["mysql","globalcache","adminui","logquery","logserver","alertserver","scanner","logclient","ldapserver", "skynetagent", "ceagent", "cdnserver"]
cluster_roles = ["mysql","mongodb","cassandras","globalcache","adminui","logquery","logserver","alertserver","scanner","logclient","ldapserver", "skynetagent", "ceagent", "cdnserver"]

begin_time = Time.now.to_i

logfile = "/var/log/samoyed.log"
if not File.exists?(logfile)
  begin
    o_file = File.new(logfile, File::CREAT|File::TRUNC|File::RDWR, 0644)
    o_file.close()
  rescue Exception => msg
    puts msg
    exit(status=false)
  end
end
result, msg = logger(logfile)
if not result
  puts msg
  exit(status=false)
end

logger = msg
logger.info "========== START. =========="

opts = Trollop::options do
  version "Samoyed 0.1.0 (c) 2012 Henry Huang"
  banner <<-EOS
This is a dog food of ICS product Auto-Deploy Tool.
Usage :
./localinst.rb [phase] [buildnum] [cfgbucket]
EOS
  opt :phase, "Development phase on this build: beta or dev",      :type => :string, :default => "dev"
  opt :env, "Development Environment: local or uslab",      :type => :string, :default => "local"
  opt :role, "ICS roles to install: adminui, scanner, all, etc.",  :type => :string, :default => "all"
  opt :buildnum, "Build number for the deployment: 1151",  :type => :string
  opt :cfgbucket, "S3 Bucket for your configuration", :type => :string
  opt :s3upload, "Upload your configurations to S3: only, both, no", :type => :string, :default => "both"
  opt :update, "Update samoyed scripts automatically", :type => :bool, :default => false
  opt :configupdate, "Update samoyed configs automatically", :type => :bool, :default => false
end

puts "========== Input Syntax Checking ============"
if opts[:phase] != "dev" and opts[:phase] != "beta" and opts[:phase] != "rel"
  p "no phase found, exit"
  exit(status=false)
elsif opts[:phase] == "rel"
  phase = "ops"
elsif opts[:phase] == "dev"
  phase = "ops"
elsif opts[:phase] == "beta"
  phase = "beta"
end

if opts[:role].downcase  == "all"
  roles = all_roles
elsif opts[:role].downcase == "cluster"
  roles = cluster_roles
elsif opts[:role].downcase == "nodb"
  roles = nodb_roles
elsif opts[:role].include?(",")
  roles = []
  for role in opts[:role].split(",")
    if all_roles.include?(role.downcase)
      roles << role 
    end
  end
elsif all_roles.include?(opts[:role].downcase) or cluster_roles.include?(opts[:role].downcase)
  roles = opts[:role].split(",")
else
  p "no role found, exit"
  exit(status=false)
end

if opts[:buildnum]
  buildno = opts[:buildnum]
else
  p "no buildnum found, use latest"
  buildno = 'latest'
end

if opts[:env]
  env = opts[:env]
else
  p "no env found, use local"
  buildno = 'local'
end

build_configFile = "config/build.cfg." + opts[:phase].to_s
result, build = parser(build_configFile, "Build")
result, project = parser(build_configFile, "Project")

if opts[:cfgbucket]
  bucket = opts[:cfgbucket]
elsif result and build['cfgbucket'] != nil
  bucket = build['cfgbucket']
else
  p "no bucket found, exit"
  exit(status=false)
end
puts "...OK\n"

puts "========== Updating Samoyed ============"
result, msg = update_rev(opts[:update])
if not result
  exit(status=false)
end
puts "...OK\n"

puts "========== Configuration ============"
machineIds = []

require 'build/yuminst'
require 'utils/parser'

configFile = "config/role.cfg." + opts[:phase].to_s
result, rolecfg = parser(configFile)
# p result

configFile = "config/yumrepo.cfg." + opts[:phase].to_s
result, yumcfg = parser(configFile, "YumRepo")
# p result, yumcfg

yumcfg['repocfg'] = "config/ics/ics.repo." + opts[:phase].to_s
repopath= yumcfg['repocfg']
testing = yumcfg['testing']

build['buildnum'] = buildno
if env == 'local'
  result, download = rdetector(build, project, logger)
  if not result
    puts "ERROR: #{download}"
    logger.fatal "DETECTOR::#{download}"
    if result
      logger.info "#{msg}"
    else
      logger.fatal "#{msg}"
    end

    logger.close()
    Process.exit!
  end
  if buildno == 'latest'
    buildno = download[:num]
  end
elsif env == 'uslab'
  icsver, buildnum = detect_build('IWSVA', yumcfg, repos=["centos-base", "ics-base", testing])
  if buildno == 'latest'
    buildno = buildnum
  elsif buildnum != buildno
    puts "ERRORS: no such build ##{buildno}, but only for build ##{buildnum}"
    exit(status=false)
  end
else
  puts "ERRORS: no such environment #{env}"
  exit(status=false)
end

puts "Phase: #{opts[:phase]}, Buildnum: #{buildno}, ConfigBucket: #{bucket}"
puts "Roles: #{roles}"
puts "...OK\n"

### BEGIN ###
puts "========== S3Config Upload =========="

cfgpath = "/opt/icsops/tools/icsops/tagreplace/config-#{phase}-{version}-#{buildno}.tgz"

if opts[:s3upload] != "no"
  require "build/cfgupload"
  result, msg = cfgupload(cfgpath, bucket, buildno, yumcfg, logger, opts[:configupdate])
  if not result
    puts msg
    exit
  end
else
  puts "No S3 config files uploaded"
end
puts "...OK\n"

if opts[:s3upload] == "only"
  exit
end

puts "========== Machine Preparation =========="

file = "config/environ.cfg"
result, vcont = parser(file, "deploy")
vplatform = vcont["platform"]
vpath = vcont[vplatform]
vconfig = vcont["config"]

for role in roles
  file = "config/role.cfg." + opts[:phase].to_s
  machineIds << parser(file, role)[1]['machine']
end

# p vplatform, vpath, vconfig
machineIds = machineIds.uniq
puts "These machines will be in the deployment: #{machineIds.sort}"

configFile = "config/build.cfg.dev"

#cmd = "/bin/rm -f #{build['localpath']}/*"
#result, msg = run(cmd)

result, msg = vmdeploy(vpath, vconfig, machineIds, logger)
if not result
  puts msg
  exit(status=false)
end
p result
machinecfg, servercfg = msg
# p machinecfg, servercfg
puts "...OK\n"

puts "========== Yum Installation =========="
enabled = ["enabled"]
for role in roles
  p role
  result, msg = yuminst(role, enabled, rolecfg, machinecfg, repopath, testing, logger)
  if not result
    puts msg
    exit(status=false)
  end
  p result, msg
end
puts "\n"

puts "========== Post Configuration =========="
require 'build/srvcfg'

for role in roles
  p role
  result, msg = srvcfg(vpath, role, rolecfg, machinecfg, servercfg, buildno, bucket, logger)
  if not result
    puts msg
    exit(status=false)
  end
  p "========= Trouble Shooting ============"
  p result, msg
  p "======================================="
end
puts "\n"

params = "output/parameters.txt"
result, msg = setini(params, "global", 'BUILDNUM', buildno)

end_time = Time.now.to_i
duration = (end_time - begin_time)/60

puts "=======> [Executed Duration: #{duration} minutes] <======="
logger.info "========== Finished. =========="
logger.close()
