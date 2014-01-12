require 'service/sshcmd'

def reboot  host, user, options

  chgroot = "sudo"
  cmd = "#{chgroot} /sbin/reboot"
  option = options
  option[:cmd] = cmd
  # p cmd
  result, msg = sshexec(host, user, option)
  # p result, msg
  if not result
    return false, msg
  end

  ## FIXME
  sleep(10)
  result = false
  starttime = Time.now.to_i
  nowtime = Time.now.to_i

  while(not result and (nowtime-starttime) < 500)
    result = false
    cmd = "uname -a"
    option = options
    option[:cmd] = cmd
    # p cmd
    result, msg = sshexec(host, user, option)
    if result
      if msg.to_s.include?("Linux")
         result = true
      else
         result = false
      end
    end
    nowtime = Time.now.to_i
    sleep(3)
  end

  if not result
    puts msg
    return false, msg
  end

  msg = "SUCESS"
  return true, msg
end
