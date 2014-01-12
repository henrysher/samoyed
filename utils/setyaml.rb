require 'rubygems'
require 'psych'


def setyaml configFile, key, value
  begin
    content = Psych.load_file(configFile)
  rescue Exception => msg
    puts msg
    return false, msg
  end

  begin
    content[key] = value
    output = content.to_yaml
  rescue Exeption => msg
    puts msg
    return false, msg
  end

  begin
    o_file = File.open(configFile, "w")
    o_file.write(output)
    o_file.close()
  rescue Exception => msg
    puts msg
    return false, msg
  end

  msg = "Success"
  return true, msg

end
