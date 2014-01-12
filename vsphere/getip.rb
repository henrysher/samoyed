require 'rubygems'
require 'rbvmomi'
require 'vsphere/findPath'

def getip vim, vmcfg

  begin
    result, vmPath = findPath(vim, vmcfg, "vm")
    if not result
      return result, vmPath
    end
  rescue Exception => msg
    return false, msg
  end

  summary = vmPath.summary
  return false, "VM is not powered on" unless summary.runtime.powerState == 'poweredOn'

  if summary.guest.ipAddress and summary.guest.ipAddress != '127.0.0.1'
    ip = summary.guest.ipAddress
  #elsif note = YAML.load(summary.config.annotation) and note.is_a? Hash and note.member? 'ip'
  #  note['ip']
  else
    msg = "no IP known for this VM"
    return false, msg
  end

  return true, ip
end


