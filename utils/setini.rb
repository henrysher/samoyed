require 'rubygems'
require 'inifile'


def setini configFile, section, key, value, reset=false
  begin
    content = IniFile.load(configFile)
  rescue Exception => msg
    puts msg
    return false, msg
  end

  if reset
    content.each_section { |section|
      content[section][key] = value
    }
  else
    content[section][key] = value
  end

  begin
    result = content.write(configFile)
  rescue Exception => msg
    puts msg
    return false, msg
  end

  if not result
    msg = "Failed to save your ini file..."
    return false, msg
  else
    msg = "Success"
    return true, msg
  end

end
