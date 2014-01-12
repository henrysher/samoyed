require 'service/sshcmd'
require 'utils/setyaml'
require 'utils/backup'
require 'utils/outdeps'
require 'utils/reboot'
require 'utils/bootstrap'
require 'utils/instvmtool'

## Role: Cassandra
#
def runcfg rolecfg, machinecfg, buildno, bucket
  role = "cassandra"

  machines = rolecfg[role]['machine'].split(",")
  # p machines

  for machineId in machines

  host, user, options, outdep = outdeps(role, rolecfg, machinecfg, machineId)
  result = instvmtool(host, user, options)
  if not result
    return false, msg
  end

  cmd = "useradd #{role}"
  option = options
  option[:cmd] = cmd
  result, msg = sshexec(host, user, option)
  if not result
    return false, msg
  end
 
  ## FIXME
  cmd = "echo 111111 | passwd #{role} --stdin"
  option = options
  option[:cmd] = cmd
  result, msg = sshexec(host, user, option)
  if not result
    return false, msg
  end

  ## FIXME
  tsudo = "cassandra ALL=(ALL)       ALL"
  cmd = "echo \"#{tsudo}\" >> /etc/sudoers"
  option = options
  option[:cmd] = cmd
  result, msg = sshexec(host, user, option)
  if not result
    return false, msg
  end

  ## FIXME
  cmd = "echo \"127.0.0.1 `hostname`\" >> /etc/hosts"
  option = options
  option[:cmd] = cmd
  result, msg = sshexec(host, user, option)
  if not result
    return false, msg
  end

  ## FIXME: /etc/cassandra/default.conf/cassandra.yaml
  ## listen_address: 10.64.79.241 (Cassandra local IP address)
  ## initial_token: 0
  ## rpc_address: 0.0.0.0
  remotepath = "/etc/cassandra/default.conf/cassandra.yaml"
  localpath = "/tmp/cassandra.yaml"
  option = options
  option[:remotepath] = remotepath
  option[:localpath] = localpath
  result, msg = sshdownload(host, user, option)
  if not result
    return false, msg
  end

  key = "listen_address"

  value = host
  result, msg = setyaml(localpath, key, value)
  if not result
    puts msg
    return false, msg
  end

  key = "initial_token"
  value = 0
  result, msg = setyaml(localpath, key, value)
  if not result
    puts msg
    return false, msg
  end

  key = "rpc_address"
  value = "0.0.0.0"
  result, msg = setyaml(localpath, key, value)
  if not result
    puts msg
    return false, msg
  end

  option = options
  option[:remotepath] = remotepath
  option[:localpath] = localpath
  result, msg = backup(host, user, option)
  if not result
    puts msg
    return false, msg
  end

  option = options
  option[:remotepath] = remotepath
  option[:localpath] = localpath
  result, msg = sshupload(host, user, option)
  if not result
    puts msg
    return false, msg
  end

  end
  msg = "Success"
  return true, msg

end


def runsrv rolecfg, machinecfg
  role = "cassandra"

  machines = rolecfg[role]['machine'].split(",")
  # p machines
  for machineId in machines

  host, user, options, outdep = outdeps(role, rolecfg, machinecfg, machineId)
  services = rolecfg[role]['services'].split(',')
  
  for service in services
    cmd = "#{service} stop"
    option = options
    option[:cmd] = cmd
    # p cmd
    result, msg = sshexec(host, user, option)
    # p result

    cmd = "#{service} start"
    option = options
    option[:cmd] = cmd
    # p cmd
    result, msg = sshexec(host, user, option)
    # p result
    if not result
      return false, msg
    end
  end

  ## Initialize Cassandra
  ## config/ics/build_cass_schma.txt
  cmd = "/usr/bin/yum install -y ICS-Tool"
  option = options
  option[:cmd] = cmd
  # p cmd
  result, msg = sshexec(host, user, option)
  # p result, msg
  if not result
    return false, msg
  end

  ## As to start cassandra needs some time, wait for at least 60 secs.
  result = false
  starttime = Time.now.to_i
  nowtime = Time.now.to_i
  rschema = "/usr/ics/tool/src/build_cass_schma.txt"

  while(not result and (nowtime-starttime) < 100)
    result = false 
    cmd = "/usr/bin/cassandra-cli < #{rschema}"
    # cmd = "/usr/bin/cassandra-cli -h localhost < #{rschema}"
    option = options
    option[:cmd] = cmd
    # p cmd
    result, msg = sshexec(host, user, option)
    # p result, msg
    if result
      result = not(msg.to_s.downcase.include?("exception"))
    end
    # p result
    nowtime = Time.now.to_i
    sleep(10)
  end

  if not result
    puts msg
    return false, msg
  end

  remotepath = "/usr/ics/tool/src/conf.py"
  localpath = "/tmp/conf.py"
  option = options
  option[:remotepath] = remotepath
  option[:localpath] = localpath
  result, msg = sshdownload(host, user, option)
  if not result
    return false, msg
  end

  cassId = rolecfg['cassandra']['machine']
  cassaddr = machinecfg[cassId]['publicip']
  mongoId = rolecfg['mongodb']['machine']
  mongoaddr = machinecfg[mongoId]['publicip']
  # p cassaddr, mongoaddr
  cmd = "echo \"cassandraAddress=[\'#{cassaddr}\'] \" >> /tmp/conf.py"
  # p cmd
  result, msg = run(cmd)
  # p result, msg
  if not result
    return false, msg
  end

  cmd = "echo \"mongoAddress = \'#{mongoaddr}\' \" >> /tmp/conf.py"
  # p cmd
  result, msg = run(cmd)
  # p result, msg
  if not result
    return false, msg
  end

  remotepath = "/usr/ics/tool/src/conf.py"
  localpath = "/tmp/conf.py"
  option = options
  option[:remotepath] = remotepath
  option[:localpath] = localpath
  result, msg = sshupload(host, user, option)
  if not result
    return false, msg
  end

  cmd = "cd /usr/ics/tool/src ; /usr/local/bin/python main.py new"
  option = options
  option[:cmd] = cmd
  # p cmd
  result, msg = sshexec(host, user, option)
  # p result, msg
  if not result
    return false, msg
  end

  cmd = "/sbin/chkconfig cassandra --level 2345 on"
  option = options
  option[:cmd] = cmd
  # p cmd
  result, msg = sshexec(host, user, option)
  # p result, msg
  if not result
    return false, msg
  end

  result = reboot(host, user, options)
  if not result
    return false, msg
  end

  end
  msg = "Success"
  return true, msg
end
