require 'rubygems'
require 'rbvmomi'

VIM = RbVmomi::VIM

def connect vmcfg

  opts = {
      :host => vmcfg['server'],
      :port => 443,
      :ssl => true,
      :user => vmcfg['username'],
      :password => vmcfg['password'],
      :insecure => true,
      :debug => vmcfg['debug']=="true", 
  }
 
 begin
   vim = VIM.connect opts
 rescue Exception => msg
   return false, msg
 end
 return true, vim
end

