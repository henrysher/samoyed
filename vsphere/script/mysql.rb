require 'service/sshcmd'
require 'service/run'
require 'utils/copy'
require 'utils/outdeps'
require 'utils/bootstrap'
require 'utils/reboot'
require 'utils/instvmtool'

## Role: MySQL
#
def runcfg rolecfg, machinecfg, buildno, bucket
  role = "mysql"
 
  machines = rolecfg[role]['machine'].split(",")
  for machineId in machines
    host, user, options, outdep = outdeps(role, rolecfg, machinecfg, machineId)
    result = instvmtool(host, user, options)
    if not result
      return false, msg
    end
  end

  msg = "Success"
  return true, msg

end


def runsrv rolecfg, machinecfg
  role = "mysql"

  machines = rolecfg[role]['machine'].split(",")
  for machineId in machines

  host, user, options, outdep = outdeps(role, rolecfg, machinecfg, machineId)
  services = rolecfg[role]['services'].split(',')
  
  for service in services
    cmd = "#{service} stop"
    option = options
    option[:cmd] = cmd
    result, msg = sshexec(host, user, option)

    cmd = "#{service} start"
    option = options
    option[:cmd] = cmd
    result, msg = sshexec(host, user, option)
    if not result
      return false, msg
    end
  end

  ## Initialize MySQL
  ## config/ics/mysql_session.sql
  cmd = "/usr/bin/mysql_install_db --user=mysql"
  option = options
  option[:cmd] = cmd
  result, msg = sshexec(host, user, option)
  if not result
    return false, msg
  end

  mysqladmin = "root"
  mysqluser = rolecfg[role]['sqluser']
  mysqlpass = rolecfg[role]['sqlpass']
  cmd = "/usr/bin/mysqladmin -u #{mysqladmin} password #{mysqlpass}"
  option = options
  option[:cmd] = cmd
  result, msg = sshexec(host, user, option)
  if not result
    return false, msg
  end

  schema = rolecfg[role]['schema']
  initdata = rolecfg[role]['initdata']

  cmd = "/usr/bin/yum install -y ICS-Tool"
  option = options
  option[:cmd] = cmd
  result, msg = sshexec(host, user, option)
  if not result
    return false, msg
  end

  stmp = "/usr/ics/tool/src/mysql_session.sql"

  sqlcmd = "\"GRANT ALL PRIVILEGES ON *.* TO '#{mysqluser}'@'localhost' IDENTIFIED BY '#{mysqlpass}' WITH  GRANT OPTION;\nGRANT ALL PRIVILEGES ON *.* TO '#{mysqluser}'@'%' IDENTIFIED BY '#{mysqlpass}' WITH  GRANT OPTION;\nflush privileges;\""
  cmd = "echo #{sqlcmd} >> #{stmp}"
  option = options
  option[:cmd] = cmd
  result, msg = sshexec(host, user, option)
  if not result
    puts msg
    return false, msg
  end

  dbname = "operation"
  sqlcmd = "\"use #{dbname};\n update users set password='1ff36598c19e1e6bbbb2edcea898c764bd2593b0065b8aca403dba7ffc6c162a8e2ed9e06829dd466cabd2e4edc1f0126335f7c932072874abcb8f7909846cb3';\""
  cmd = "echo #{sqlcmd} >> #{stmp}"
  option = options
  option[:cmd] = cmd
  result, msg = sshexec(host, user, option)
  if not result
    puts msg
    return false, msg
  end

  cmd = "/usr/bin/mysql -u #{mysqladmin} --password=#{mysqlpass} < #{stmp}"
  option = options
  option[:cmd] = cmd
  result, msg = sshexec(host, user, option)
  if not result
    return false, msg
  end

  cmd = "/sbin/chkconfig mysqld --level 2345 on"
  option = options
  option[:cmd] = cmd
  result, msg = sshexec(host, user, option)
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
