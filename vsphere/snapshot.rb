require 'rubygems'
require 'rbvmomi'
require 'vsphere/findPath'

def takeSnapshot vim, vmcfg, snapshot
  begin
    result, vmPath = findPath(vim, vmcfg, "vm")
    if not result
      return result, vmPath
    end
  rescue Exception => msg
    return false, msg
  end
  
  begin
    snapshotPath = vmPath.CreateSnapshot_Task(
        :description => snapshot['description'],
        :memory => snapshot['memory']=="true",
        :name => snapshot['name'],
        :quiesce => snapshot['quiesce']=="true"
    ).wait_for_completion
  rescue Exception => msg
    return false, msg
  end

  return true, snapshotPath
end

def revertSnapshot currentPath
  begin
    newPath = currentPath.RevertToSnapshot_Task.wait_for_completion
  rescue Exception => msg
    return false, msg
  end

  return true, newPath
end

