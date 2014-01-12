require 'service/run'

def copy local, remote
  cmd = "/bin/cp -fv #{local} #{remote}"
  result, msg = run(cmd)
  if not result
    return false, msg
  else
    msg = "Success"
    return true, msg
  end
end

