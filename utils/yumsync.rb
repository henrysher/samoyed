require 'service/run'

def yumsync remoteIp, remotepath, localpath, splitter
  repofolder = File.join(splitter, localpath.split(splitter)[-1])
  remotepath = File.join(remotepath, repofolder)
  p remotepath
  privatekey = "config/ics/" + remoteIp + ".private.key"
  cmd = "/usr/bin/rsync -avHxe \"ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i #{privatekey} \" #{localpath} root@#{remoteIp}:#{remotepath} --chmod=a+rx --delete"
  # p cmd
  result, msg = run(cmd)
  if not result
    puts msg
    return false, msg
  end
  return true, msg
end
