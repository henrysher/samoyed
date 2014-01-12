require 'service/sshcmd'
require 'utils/sshparser'

def outdeps role, rolecfg, machinecfg, machineId

  host, user, options = sshparser(machineId, machinecfg)

  egresx = rolecfg[role]['egress']
  if egresx != nil
    egresx = egresx.split(",")
    outdeps = {}
    for egress in egresx
      tmp = egress.split(":")
      if tmp.size >= 1
        deprole = egress.split(':')[0]
        port = egress.split(':')[1]
        if deprole.size != 0 and port.size != 0
          machineId = rolecfg[deprole]['machine']
          depaddr = machinecfg[machineId]['publicip']
          realaddr = machinecfg[machineId]['privateip']
          if depaddr == host
            depaddr = "127.0.0.1"
          end
	  outdeps[deprole] = realaddr.to_s + ":" + port.to_s
        end
      end
    end
  end
  return host, user, options, outdeps
end
