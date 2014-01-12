require 'service/run'
require 'utils/copy'
require 'utils/setini'


def set_yum_repo yumrepo, repos
  testing = yumrepo["testing"]
  repocfg = yumrepo["repocfg"]

  tmprpath = "/tmp/ics.repo"
  result, msg = copy(repocfg, tmprpath)
  if not result
    puts msg
    return false, msg
  end

  result, msg = setini(tmprpath, '', 'enabled', '0', true)
  for repo in repos
    result, msg = setini(tmprpath, repo, 'enabled', '1')
  end

  if not result
    logger.fatal logtitle + "#{msg}"
    puts msg
    return false, msg
  end

  cmd = "/bin/mkdir -p /tmp/backup"
  result, msg = run(cmd)

  cmd = "/bin/mv /etc/yum.repos.d/*.repo /tmp/backup"
  result, msg = run(cmd)

  ics_repo = tmprpath.split('/')[-1]
  cmd = "/bin/cp -f #{tmprpath} /etc/yum.repos.d/#{ics_repo}"
  result, msg = run(cmd)
end

def detect_build package, yumrepo=nil, repos=nil

  if repos != nil and yumrepo != nil
    result, msg = set_yum_repo(yumrepo, repos)
    if not result
      return false, msg
    end
  end

  cmd = "/usr/bin/yum info #{package} | awk '$1 ~ /Version/ {print $3}' | awk 'BEGIN  { FS = \".\" }; {print $1$2}'"
  result, msg = run(cmd)
  if not result
    return false, msg
  end
  version = msg

  cmd = "/usr/bin/yum info #{package} | awk '$1 ~ /Version/ {print $3}' | awk 'BEGIN  { FS = \".\" }; {print $4}'"
  result, msg = run(cmd)
  if not result
    return false, msg
  end
  build = msg
  return version, build

end
