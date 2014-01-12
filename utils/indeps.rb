require 'service/sshcmd'
require 'utils/sshparser'

def indeps role, rolecfg, machinecfg

  machineId = rolecfg[role]['machine']
  host, user, options = sshparser(machineId, machinecfg)

  ingresx = rolecfg[role]['ingress']
  p ingresx
  if ingresx != nil
    ingresx = ingresx.split(",")
    indeps = []
    ports = []
    for ingress in ingresx
      tmp = ingress.split(":")
      if tmp.size >= 1
        deprole = ingress.split(':')[0]
        port = ingress.split(':')[1]
        p deprole, port
        if deprole.size == 0 and port.size != 0
          machineId = rolecfg[role]['machine']
          depgroup = machinecfg[machineId]['securitygroup']
          ## FIXME: ["tcp","22", "0.0.0.0/0"] already added into security group
          if depgroup != nil and port != "22"
            indeps << ["tcp", port, "0.0.0.0/0"]
          end
          ports << port
         end
              
         if deprole.size != 0 and port.size != 0
           machineId = rolecfg[deprole]['machine']
           ipaddr = machinecfg[machineId]['publicip']
           depgroup = machinecfg[machineId]['securitygroup']
           if depgroup != nil
             if ipaddr != host
               indeps << ["tcp", port, {:group_id => depgroup}]
             end
           end
           ports << port
         end
      end
    end
  end
  p indeps, ports
  return host, user, options, indeps, ports
end
