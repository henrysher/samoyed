require 'service/run'
require 'utils/parser'
require 'utils/setini'

def localyuminfo repopath, enabled_repos, package, buildnum

  tmppath = "/tmp/ics.repo"
  cmd = "/bin/cp -fv #{repopath} #{tmppath}"
  result, msg = run(cmd)
  if not result
    return false, msg
  end

  if enabled_repos.include?(',')
    repos = enabled_repos.split(',')
  else
    repos = [enabled_repos]
  end

  result, msg = setini(tmppath, '', 'enabled', '0', true)
  if not result
    return false, msg
  end

  for repo in repos
    p repo
    result, msg = setini(tmppath, repo, 'enabled', '1')
    if not result
      return false, msg
    end
  end

  cmd = "mkdir -p /tmp/repobackup; /bin/mv /etc/yum.repos.d/*.repo /tmp/repobackup"
  result, msg = run(cmd)
  if not result
    return false, msg
  end

  cmd = "/bin/cp -f #{tmppath} /etc/yum.repos.d/"
  result, msg = run(cmd)
  if not result
    return false, msg
  end

  cmd = "/usr/bin/yum clean all"
  result, msg = run(cmd)
  if not result
    return false, msg
  end

  cmd = "/usr/bin/yum info #{package}"
  result, msg = run(cmd)
  if not result
    return false, msg
  end
  if not msg.include?(buildnum)
    msg = "no such build #{buildnum} in YUM now..."
    return false, msg
  end
  msg = "Success"
  return true, msg
end
