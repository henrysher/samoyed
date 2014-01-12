require 'service/sshcmd'

def backup host, user, options={}
  remotepath  = options[:remotepath]
  cmd = "/bin/cp -f #{remotepath} #{remotepath}.backup"
  options[:cmd] = cmd
  options.delete(:remotepath)
  options.delete(:localpath)

  result, msg = sshexec(host, user, options)  
  if not result
    puts msg
    return false, msg
  else
    msg = "Success"
    return true, msg
  end

end


