require 'rubygems'
require 'net/ssh'
require 'utils/sshparser'
require 'utils/parser'

def rundns vpath, role, rolecfg, machinecfg, servercfg
 begin
    require "#{vpath}/dns"
  rescue Exception => msg
    return false, msg
  end

  result, msg = dnssetup(role, rolecfg, machinecfg, servercfg)
  puts msg
  return result, msg  
end
