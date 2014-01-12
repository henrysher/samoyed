#!/usr/bin/env ruby
require 'rubygems'
require 'rbvmomi'

VIM = RbVmomi::VIM

vm_name = "test-ruby-api-2"
opts = {
    :host => '10.204.133.21',
    :port => 443,
    :ssl => true,
    :user => 'administrator',
    :password => '@icss_21',
    :insecure => true,
#    :debug => true,
}

vim = VIM.connect opts
rootFolder = vim.serviceInstance.content.rootFolder
dc = vim.serviceInstance.find_datacenter("zKiller-1")
print dc,"\n"
datastore = dc.find_datastore("zkiller-storage1")
iso_datastore = dc.find_datastore("zkiller-iso")
print datastore, "\n"
vmFolder = dc.vmFolder
print vmFolder,"\n"
hosts = dc.hostFolder.children
rap = hosts.first.resourcePool
rp = rap.find("AutomationTest")
#rp = hosts.first.grep(vim::ResourcePool).first
print rp,"\n"
fil = "test5.iso"
remote_path = "/" + fil
#local_path = "/root/src/rbvmomi/examples/test.rb"
local_path = "/tmp/" + fil
#datastore.upload(remote_path, local_path)

vm_cfg = {
  :name => vm_name,
  :guestId => 'otherGuest',
  :files => { :vmPathName => "[zkiller-storage1]"},
  :numCPUs => 1,
  :memoryMB => 2048,
  :deviceChange => [
    {
      :operation => :add,
      :device => VIM.VirtualLsiLogicController(
        :key => 1000,
        :busNumber => 0,
        :sharedBus => :noSharing
      )
    }, {
      :operation => :add,
      :fileOperation => :create,
      :device => VIM.VirtualDisk(
        :key => 0,
        :backing => VIM.VirtualDiskFlatVer2BackingInfo(
          :fileName => '[zkiller-storage1]',
          :diskMode => :persistent,
          :thinProvisioned => true
        ),
        :controllerKey => 1000,
        :unitNumber => 0,
        :capacityInKB => 40000000
      )
    }, {
      :operation => :add,
      :device => VIM.VirtualE1000(
        :key => 0,
        :deviceInfo => {
          :label => 'Network Adapter 1',
          :summary => 'VM Network'
        },
        :backing => VIM.VirtualEthernetCardNetworkBackingInfo(
          :deviceName => 'VM Network'
        ),
        :addressType => 'generated'
      )
    }, {
      :operation => :add,
      :device => VIM.VirtualCdrom(
        :controllerKey => 200,
        :key => 0,
        :deviceInfo => {
          :label => 'CD/DVD Drive 1',
          :summary => "[zkiller-iso] #{remote_path}",
        },
        :backing => VIM.VirtualCdromIsoBackingInfo(
          :fileName => "[zkiller-iso] #{remote_path}"
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

vmFolder.CreateVM_Task(:config => vm_cfg, :pool => rp).wait_for_completion
vm = dc.find_vm(vm_name)
print vm, "\n"

snap1 = vm.CreateSnapshot_Task(
  :description => "test",
  :memory => false,
  :name => "test",
  :quiesce => false).wait_for_completion

vm.PowerOnVM_Task.wait_for_completion

#snap2 = vm.CreateSnapshot_Task(
#  :description => "offer",
#  :memory => false,
#  :name => "offer",
#  :quiesce => false).wait_for_completion

#snap1.RevertToSnapshot_Task.wait_for_completion
#p "revert to test, ready... please check...."
#sleep(10)
#vm.PowerOffVM_Task.wait_for_completion
#sleep(10)
#vm.Destroy_Task.wait_for_completion
vim.close()
