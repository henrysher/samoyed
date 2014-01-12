require 'rubygems'
require 'rbvmomi'
require 'vsphere/findPath'

def destroy vim, vmcfg
  begin
    result, vmPath = findPath(vim, vmcfg, "vm")
    if not result
      return result, vmPath
    end

  rescue Exception => msg
    return false, msg
  end

  begin
    vmPath.Destroy_Task.wait_for_completion
  rescue Exception => msg
    return false, msg
  end

  status = "Destroyed"
  return true, status
end

