require 'service/sshcmd'
require 'utils/setyaml'
require 'utils/backup'
require 'utils/outdeps'
require 'utils/reboot'
require 'utils/bootstrap'
require 'utils/instvmtool'
## FIXME:
require 'rubygems'
require 'psych'
require 'service/run'

## Role: Cassandra
#
def runcfg rolecfg, machinecfg, buildno, bucket
  role = "cassandras"
  
  dcname = rolecfg[role]['dcname']
  machines = rolecfg[role]['machine'].split(",")
  ## FIXME: seednode --> DC1:RAC1, DC2:RAC1, etc.
  seednode = ''
  for machineId in machines
    dcenter = machineId.split(':')[0]
    dcnum = dcenter.split('DC')[-1]
    mrac = machineId.split(':')[1]
    mrnum = mrac.split('RAC')[-1]
    # p dcenter, dcnum
    # p mrac, mrnum
    if mrnum.to_i == 1
      seednode += machinecfg[machineId]['publicip'].to_s + ','
    end
  end
  # p seednode
  seednodes = seednode.chop
  # p seednodes
  tokenbase = 2**127/machines.size
  # p tokenbase
  # p machines

  ## FIXME
  localpath = "/tmp/cassandra-topology.properties"
  cmd = "echo '[ics-autotest]' > #{localpath}"
  # p cmd
  result, msg = run(cmd)
  # p result
  if not result
    return false, msg
  end

  ## FIXME
  for machineId in machines
    key = machinecfg[machineId]['publicip']
    value = machineId
    result, msg = setini(localpath, 'ics-autotest', key, value)
    if not result
      puts msg
      return result, msg
    end
  end

  cmd = "sed -i \"s/.*ics-autotest.*//g\" #{localpath}"
  # p cmd
  result, msg = run(cmd)
  # p result, msg
  if not result
    return false, msg
  end

  for machineId in machines

  host, user, options, outdep = outdeps(role, rolecfg, machinecfg, machineId)
  result = instvmtool(host, user, options)
  if not result
    return false, msg
  end
  dcenter = machineId.split(':')[0]
  dcnum = dcenter.split('DC')[-1]
  mrac = machineId.split(':')[1]
  mrnum = mrac.split('RAC')[-1]
  # p dcenter, dcnum
  # p mrac, mrnum

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

  key = "cluster_name"
  value = dcname 
  result, msg = setyaml(localpath, key, value)
  if not result
    puts msg
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
  value = (mrnum.to_i-1)*2*tokenbase + (dcnum.to_i-1) 
  # p value
  result, msg = setyaml(localpath, key, value)
  if not result
    puts msg
    return false, msg
  end

  key = "broadcast_address"
  value = host 
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

  key = "endpoint_snitch"
  value = "PropertyFileSnitch"
  result, msg = setyaml(localpath, key, value)
  if not result
    puts msg
    return false, msg
  end

  localpath = "/tmp/cassandra.yaml"
  content = Psych.load_file(localpath)
  content['seed_provider'][0]['parameters'][0]['seeds'] = seednodes
  # p content
  output = content.to_yaml
  begin
    o_file = File.open(localpath, "w")
    o_file.write(output)
    o_file.close()
  rescue Exception => msg
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

  remotepath = "/etc/cassandra/default.conf/cassandra-topology.properties"
  localpath = "/tmp/cassandra-topology.properties"
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
  role = "cassandras"

  machines = rolecfg[role]['machine'].split(",")
  init_machines = rolecfg[role]['initm'].split(",")

  # p machines
  for machineId in machines

  host, user, options, outdep = outdeps(role, rolecfg, machinecfg, machineId)
  # p host
  services = rolecfg[role]['services'].split(',')

  #for service in services
  #  cmd = "#{service} stop"
  #  option = options
  #  option[:cmd] = cmd
  #  # p cmd
  #  result, msg = sshexec(host, user, option)
  #  p result

  #  cmd = "#{service} start"
  #  option = options
  #  option[:cmd] = cmd
  #  # p cmd
  #  result, msg = sshexec(host, user, option)
  #  p result
  #  if not result
  #    return false, msg
  #  end
  #end

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

  for machineId in machines

  host, user, options, outdep = outdeps(role, rolecfg, machinecfg, machineId)
  # p host

  if not init_machines.include?(machineId)
    msg = "no need to initialize... on this machine: #{machineId}"
    puts msg
    next
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
  rschema = "/usr/ics/tool/src/build_cass_schma.txt"

  cmd = "sed -i \"s/create keyspace Profiles;/create keyspace Profiles with placement_strategy='NetworkTopologyStrategy' and strategy_options={DC1:2,DC2:2};/g\" #{rschema}"
  option = options
  option[:cmd] = cmd
  # p cmd
  result, msg = sshexec(host, user, option)
  # p result, msg
  if not result
    return false, msg
  end

  cmd = "sed -i -r \"s/drop(.*);/\\/\\*drop\\1;\\*\\//g\" #{rschema}"
  option = options
  option[:cmd] = cmd
  # p cmd
  result, msg = sshexec(host, user, option)
  # p result, msg
  if not result
    return false, msg
  end

  result = false
  starttime = Time.now.to_i
  nowtime = Time.now.to_i

  while(not result and (nowtime-starttime) < 100)
    result = false 
    cmd = "/usr/bin/cassandra-cli < #{rschema}"
    # cmd = "/usr/bin/cassandra-cli -h localhost -f #{rschema}"
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

  rinitdata = "/usr/ics/tool/src/cass_initdata.txt"
  result = false
  starttime = Time.now.to_i
  nowtime = Time.now.to_i

  while(not result and (nowtime-starttime) < 100)
    result = false 
    cmd = "/usr/bin/cassandra-cli < #{rinitdata}"
    # cmd = "/usr/bin/cassandra-cli -h localhost -f #{rinitdata}"
    option = options
    option[:cmd] = cmd
    # p cmd
    result, msg = sshexec(host, user, option)
    # p result, msg
    if result
      result = not(msg.to_s.downcase.include?("exception") or msg.to_s.downcase.include?("No such file or directory"))
    end
    # p result
    nowtime = Time.now.to_i
    sleep(10)
  end

  if not result
    puts msg
    return false, msg
  end

  # result = reboot(host, user, options)
  # if not result
  #  return false, msg
  # end

  end
  msg = "Success"
  return true, msg
end
