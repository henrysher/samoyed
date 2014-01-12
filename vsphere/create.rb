require 'rubygems'
require 'rbvmomi'

def create vim, vmcfg, isocfg, isoPath
  isoPath = '/' + isoPath
  begin
    datacenter = vmcfg['datacenter']
    datastore = vmcfg['datastore']
    isostore = vmcfg['isostore']
    resourcePool = vmcfg['resourcepool']
    host = vmcfg['host']
    remotePath = isoPath
    localPath = isocfg['destdir']

    vmName = vmcfg['vmname']
    numCPUs = vmcfg['numCPUs'].to_i
    memoryMB = vmcfg['memoryMB'].to_i
    diskKB = vmcfg['diskKB'].to_i
    guestId = vmcfg['guestType']
    switchName = vmcfg['switchName']
  rescue Exception => msg
    return false, msg
  end

  begin
    rootFolder = vim.serviceInstance.content.rootFolder
    datacenterPath = vim.serviceInstance.find_datacenter(datacenter)
    datastorePath = datacenterPath.find_datastore(datastore)
    isostorePath = datacenterPath.find_datastore(isostore)
    vmFolder = datacenterPath.vmFolder
    hosts = datacenterPath.hostFolder.find(host)
    
    resourcePath = hosts.resourcePool.find(resourcePool)
  rescue Exception => msg
    return false, msg
  end

  begin
    vm_cfg = {
      :name => vmName,
      :guestId => guestId,
      :files => { :vmPathName => "[#{datastore}]" },
      :numCPUs => numCPUs,
      :memoryMB => memoryMB,
      :deviceChange => [
      {
        :operation => :add,
        :device => VIM.VirtualLsiLogicController(
          :key => 1000,
          :busNumber => 0,
          :sharedBus => :noSharing
        )
      },{
       :operation => :add,
        :fileOperation => :create,
        :device => VIM.VirtualDisk(
          :key => 0,
          :backing => VIM.VirtualDiskFlatVer2BackingInfo(
            :fileName => "[#{datastore}]",
            :diskMode => :persistent,
            :thinProvisioned => true
          ),
          :controllerKey => 1000,
          :unitNumber => 0,
          :capacityInKB => diskKB
        )
      },{
        :operation => :add,
        :device => VIM.VirtualE1000(
          :key => 0,
          :deviceInfo => {
            :label => 'Network Adapter 1',
            :summary => switchName
          },
          :backing => VIM.VirtualEthernetCardNetworkBackingInfo(
            :deviceName => switchName
          ),
          #:addressType => 'generated'
          :addressType => 'manual',
          :macAddress => '00:50:56:00:00:11',
        )
      },{
        :operation => :add,
        :device => VIM.VirtualCdrom(
          :controllerKey => 200,
          :key => 0,
          :deviceInfo => {
            :label => 'CD/DVD Drive 1',
            :summary => "[#{datastore}] #{remotePath}",
          },
          :backing => VIM.VirtualCdromIsoBackingInfo(
            :fileName => "[#{datastore}] #{remotePath}"
          ),
          :connectable => VIM.VirtualDeviceConnectInfo(
            :allowGuestControl => true,
            :connected => true,
            :startConnected => true
          )
        )
      }
    ],    
     :extraConfig => [
       {
         :key => 'bios.bootOrder',
         :value => 'ethernet0'
       }
    ]
   }
  
  rescue Exception => msg
    return false, msg
  end

  begin
    vmFolder.CreateVM_Task(:config => vm_cfg, :pool => resourcePath).wait_for_completion
    vmPath = datacenterPath.find_vm(vmName)
  rescue Exception => msg
    return false, msg
  end

  return true, vmPath
end
