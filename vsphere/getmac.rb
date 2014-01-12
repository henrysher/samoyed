require 'rubygems'
require 'rbvmomi'
require 'vsphere/findPath'

def getmac vim, vmcfg

  begin
    result, vmPath = findPath(vim, vmcfg, "vm")
    if not result
      return result, vmPath
    end
  rescue Exception => msg
    return false, msg
  end

  macs = vmPath.macs
  return true, macs
end


