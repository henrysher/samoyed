require 'rubygems'
require 'rbvmomi'

def findPath vim, vmcfg, opt

  begin
    datacenter = vmcfg['datacenter']
    datastore = vmcfg['datastore']
    isostore = vmcfg['isostore']
    resourcePool = vmcfg['resourcepool']
    vmName = vmcfg['vmname']
    if vmcfg.include?('sname')
      sName = vmcfg['sname']
    end
  rescue Exception => msg
    return false, msg
  end

  begin
    rootFolder = vim.serviceInstance.content.rootFolder
    datacenterPath = vim.serviceInstance.find_datacenter(datacenter)
    datastorePath = datacenterPath.find_datastore(datastore)
    isostorePath = datacenterPath.find_datastore(isostore)
    vmFolder = datacenterPath.vmFolder
    hosts = datacenterPath.hostFolder.children
    resourcePath = hosts.first.resourcePool.find(resourcePool)
    vmPath = datacenterPath.find_vm(vmName)
    if vmPath == nil
      vmPath = vmFolder.childEntity.first.traverse vmName, RbVmomi::VIM::VirtualMachine
    end
    if sName != nil
      vmSnapshot = vmPath.snapshot.rootSnapshotList.find {|x| x.name == sName}
    end
  rescue Exception => msg
    return false, msg
  end

  if opt.include?("datacenter")
    return true, datacenterPath
  elsif opt.include?("datastore")
    return true, datastorePath
  elsif opt.include?("isostore")
    return true, isostorePath
  elsif opt.include?("resourcepool")
    return true, resourcePath
  elsif opt.include?("vm")
    return true, vmPath
  elsif opt.include?("snapshot")
    return true, vmSnapshot
  else
    msg = "No matched result"
    return false, msg
  end
end
