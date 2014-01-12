require 'rubygems'
require 'open4'
require 'service/run'

def nfsd nfscfg
  folder = nfscfg['folder']
  export = nfscfg['export']
  service = nfscfg['service']
  network = nfscfg['network']

  begin
    o_file = open(export, 'rb')
    o_text = o_file.read()
    o_file.close()
  rescue Exception => msg
    return false, msg
  end


  if not o_text.include?(folder)
    o_text += "\n" + folder + "\t" + network + "(ro)"
  end

  begin
    o_file = open(export, 'w')
    o_file.write(o_text)
    o_file.close()
  rescue Exeption => msg
    return false, msg
  end
  
  cmd = "#{service} restart"
  result, msg = run(cmd)
  if not result
    return false, msg
  end

  return true, msg

end

