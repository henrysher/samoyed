require 'service/run'

def update_rev trigger 

  if trigger
    cmd = "/bin/cp -fv hgtips/hgignore /tmp/hgignore"
    result, msg = run(cmd)
    if not result
      puts msg
      return false, msg
    end

    cmd = "/bin/cp -fv hgtips/hgrc .hg/hgrc"
    result, msg = run(cmd)
    if not result
      puts msg
      return false, msg
    end

    cmd = "/usr/local/bin/hg revert output/"
    result, msg = run(cmd)
    if not result
      puts msg
      return false, msg
    end

    cmd = "/usr/local/bin/hg fetch"
    result, msg = run(cmd)
    if not result
      puts msg
      return false, msg
    end
  end
  return true, "Success"

end


