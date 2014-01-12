require 'json'
require 'utils/parser'
require 'service/sshcmd'

def cfgdownload  host, user, options, role, buildno, bucket

  ## FIXME
  key_path = "/etc/boto.cfg"
  result, msg = parser(key_path, 'Credentials')
  if not result
    return false, msg
  end
  aws_key = msg

  puts "====== Machine Bootstrapping ======"
  ## FIXME
  mapping = {'adminui'=>'AdminPortal',
             'logquery'=>'AdminPortal',
             'alertserver'=>'Alert',
             'forwardproxy'=>'ForwardProxy',
             'logserver'=>'LogWriter',
             'monitor'=>'Monitor',
             'globalcache'=>'ProfileCache',
    	     'scanner'=>'ScannerDy',
    	     'logclient'=>'ScannerDy',
             'ldapserver'=>'VpcLdap',
             'skynetagent'=>'SkynetAgent',
             'ceagent'=>'CEAgent',
             'scoagent'=>'SCOAgent',
  }

  cmd = "/usr/bin/yum info IWSVA"
  option = options
  option[:cmd] = cmd
  result, msg = sshexec(host, user, option)
  if not result
    return false, msg
  end

  tmps = msg
  tmps.gsub!(/ /,"")
  tmps = tmps.split("\n")
  for tmp in tmps
    if tmp.downcase.include?("version")
      vertmp = tmp.split(":")
      # p vertmp
      ver_tmp = vertmp[1].split("-")[0].split(".")
      icsver = ver_tmp[0] + ver_tmp[1]
      # p icsver
      break
    end
  end

  vmname = mapping[role].downcase.to_s + "-" + "uw2" + "-" + icsver + "-" + buildno.to_s
  # p vmname

  orig_f = "config/ics/tmicss.json"
  temp_f = "config/ics/tmicss.json.tmp"
  dest_f = "/opt/trend/tmicss/tmicss.json"

  begin
    f = File.open(orig_f, "r")
  rescue Exception => msg
    return false, msg
  end

  begin
    content = JSON.load(f)
  rescue Exception => msg
    return false, msg
  end

  begin
    f.close()
  rescue Exception => msg
    return false, msg
  end

  if content['Tags'] != nil
    if content['Tags']['Name'] != nil and content['Tags']['Role'] != nil
      content['Tags']['Role'] = mapping[role]
      content['Tags']['Name'] = vmname 
    else
      msg = "No such tags: Role, Name"
      return false, msg
    end
  else
      msg = "No such item: Tags"
      return false, msg
  end 
 
  if content['S3'] != nil
    if content['S3']['ConfigBucket'] != nil 
      content['S3']['ConfigBucket'] = bucket
    else
      msg = "No such item: ConfigBucket"
      return false, msg
      end
  else
    msg = "No such item: S3"
    return false, msg
  end

  if content['Credentials'] != nil
    if content['Credentials']['AWS_ACCESS_KEY_ID'] != nil and content['Credentials']['AWS_SECRET_ACCESS_KEY'] != nil
      content['Credentials']['AWS_ACCESS_KEY_ID'] = aws_key['aws_access_key_id']
      content['Credentials']['AWS_SECRET_ACCESS_KEY'] = aws_key['aws_secret_access_key']
    else
      msg = "No such items: AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY"
      return false, msg
      end
  else
    msg = "No such item: S3"
    return false, msg
  end
 
  # p content

  begin
    f = File.open(temp_f, "w")
  rescue Exception => msg
    return false, msg
  end

  begin
    JSON.dump(content, f)
  rescue Exception => msg
    return false, msg
  end
  
  begin
    f.close()
  rescue Exception => msg
    return false, msg
  end

  cmd = "mkdir -p /opt/trend/tmicss"
  option = options
  option[:cmd] = cmd
  result, msg = sshexec(host, user, option)
  if not result
    return false, msg
  end

  option = options
  option[:remotepath] = dest_f
  option[:localpath] = temp_f
  result, msg = sshupload(host, user, option)
  if not result
    puts msg
    return false, msg
  end

  option = options
  option[:remotepath] = "/opt/trend/tmicss/tmcfgs3.rb"
  option[:localpath] = "config/ics/tmcfgs3.rb"
  result, msg = sshupload(host, user, option)
  if not result
    puts msg
    return false, msg
  end

  option = options
  option[:remotepath] = "/opt/trend/tmicss/tmlog.rb"
  option[:localpath] = "config/ics/tmlog.rb"
  result, msg = sshupload(host, user, option)
  if not result
    puts msg
    return false, msg
  end

  option = options
  option[:remotepath] = "/opt/trend/tmicss/tmicss_install_configs.rb"
  option[:localpath] = "config/ics/tmicss_install_configs.rb"
  result, msg = sshupload(host, user, option)
  if not result
    puts msg
    return false, msg
  end

  cmd = "/usr/bin/ruby /opt/trend/tmicss/tmicss_install_configs.rb"
  option = options
  option[:cmd] = cmd
  result, msg = sshexec(host, user, option)
  if not result
    return false, msg
  end

  msg = "Success"
  return true, msg

end
 
