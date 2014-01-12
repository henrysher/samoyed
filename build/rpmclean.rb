require 'net/ftp'
require 'service/run'
require 'utils/crypt'
require 'utils/setini'
require 'utils/copy'
require 'rubygems'
require 'nokogiri'

def isdigit? s
  result = s.match(/[^0-9]/) == nil ? true: false
  return result
end

def isnumber? s
  s.each_char {|letter|
    if not isdigit?(letter)
      return false
    end
  }
  return true
end

def rpmclean  yumrepo, local, rolecfg, buildnum, logger
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
    if not yumrepo.include?("prefix")
      project_prefix = "project"
    else
      project_prefix = yumrepo["prefix"]
    end
    buildurl = 'ftp://' + server
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

  cmd = "/bin/umount #{localpath}"
  result, msg = run(cmd)
  logger.info logtitle + "#{cmd}"
  logger.info logtitle + "#{msg}"

  cmd = "/bin/mkdir -p #{localpath} "
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

  if not isnumber?(buildnum)
    msg = "Build Number is invalid."
    return false, msg
  end

  max = 50
  i = 3
  while(i <= max)
  build_to_delete = buildnum.to_i - i
  cmd = "/bin/rm -rf #{localpath}/#{platform}/*#{build_to_delete}*"
  # p cmd
  logger.info logtitle + "#{cmd}"
  result, msg = run(cmd)
  logger.info logtitle + "#{msg}"
  i += 1
  end

  cmd = "/bin/umount #{localpath}"
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

