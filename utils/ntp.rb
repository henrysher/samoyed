require 'rubygems'
require 'net/ssh'
require 'utils/sshparser'
require 'utils/parser'

def runntp vpath, role, rolecfg, machinecfg, servercfg
 begin
    require "#{vpath}/ntp"
  rescue Exception => msg
    return false, msg
  end

  result, msg = ntpsetup(role, rolecfg, machinecfg, servercfg)
  puts msg
  return result, msg  
end
