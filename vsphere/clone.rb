require 'rubygems'
require 'rbvmomi'
require 'vsphere/findPath'

def clone vim, vmcfg, newvm
  begin
    result, vmPath = findPath(vim, vmcfg, "vm")
    if not result
      return result, vmPath
    end

  rescue Exception => msg
    return false, msg
  end


  begin
    relocateSpec = VIM.VirtualMachineRelocateSpec
    spec = VIM.VirtualMachineCloneSpec(:location => relocateSpec,
                                       :powerOn => false,
                                       :template => false)
    vmPath.CloneVM_Task(:folder => vmPath.parent, :name => newvm, :spec => spec).wait_for_completion
  rescue Exception => msg
    return false, msg
  end

  status = "Cloned"
  return true, status
end

