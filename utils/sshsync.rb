require 'service/run'

def prepare_deps 
  cmd = "/usr/bin/yum install -y rsync"
  result, msg = run(cmd)
  if not result
    puts msg
    return false, msg
  end
end

def sync_from_remote remoteIp, remotepath, localpath
  prepare_deps
  p remotepath
  privatekey = "config/ics/" + remoteIp + ".private.key"

  cmd = "chmod 400 #{privatekey}"
  result, msg = run(cmd)

  cmd = "/usr/bin/rsync -avHxe \"ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i #{privatekey} \" root@#{remoteIp}:#{remotepath} #{localpath} --chmod=a+rx --delete"
  result, msg = run(cmd)
  if not result
    puts msg
    return false, msg
  end
  return true, msg
end

def sync_to_remote remoteIp, remotepath, localpath
  prepare_deps
  p remotepath
  privatekey = "config/ics/" + remoteIp + ".private.key"

  cmd = "chmod 400 #{privatekey}"
  result, msg = run(cmd)

  cmd = "/usr/bin/rsync -avHxe \"ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i #{privatekey} \" #{localpath} root@#{remoteIp}:#{remotepath} --chmod=a+rx --delete"
  result, msg = run(cmd)
  if not result
    puts msg
    return false, msg
  end
  return true, msg
end
