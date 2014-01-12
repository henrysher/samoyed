def vmdeploy vpath, vconfig, machineIds, logger

  begin
    require "#{vpath}/vmdeploy"
  rescue Exception => msg
    return false, msg
  end

  vpfg = File.join("config", vpath)
  vcfg = File.join(vpfg, vconfig)
  result, msg = rundeploy(vcfg, machineIds, logger)
  # p result
  return result, msg

end


def vmdestroy vpath, vconfig, machineIds, logger

  begin
    require "#{vpath}/vmdeploy"
  rescue Exception => msg
    return false, msg
  end

  vpfg = File.join("config", vpath)
  vcfg = File.join(vpfg, vconfig)
  result, msg = rundestroy(vcfg, machineIds, logger)
  # p result
  return result, msg

end


def imageinst vpath, vconfig, machineIds, buildnum, logger

  begin
    require "#{vpath}/vmdeploy"
  rescue Exception => msg
    return false, msg
  end

  vpfg = File.join("config", vpath)
  vcfg = File.join(vpfg, vconfig)
  result, msg = runimageinst(vcfg, machineIds, buildnum, logger)
  # p result
  return result, msg

end
