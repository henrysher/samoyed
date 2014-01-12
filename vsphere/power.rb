require 'rubygems'
require 'rbvmomi'
require 'vsphere/findPath'

def poweron vim, vmcfg
  begin
    result, vmPath = findPath(vim, vmcfg, "vm")
    if not result
      return result, vmPath
    end

  rescue Exception => msg
    return false, msg
  end

  begin
    vmPath.PowerOnVM_Task.wait_for_completion
  rescue Exception => msg
    return false, msg
  end

  status = "PowerOn"
  return true, status
end

def poweroff vim, vmcfg
  begin
    result, vmPath = findPath(vim, vmcfg, "vm")
    if not result
      return result, vmPath
    end
  rescue Exception => msg
    return false, msg
  end

  begin
    vmPath.PowerOffVM_Task.wait_for_completion
  rescue Exception => msg
    return false, msg
  end

  status = "Poweroff"
  return true, status
end

