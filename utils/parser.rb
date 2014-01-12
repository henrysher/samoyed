require 'rubygems'
require 'inifile'


def parser configFile, section=nil
  begin
    content = IniFile.load(configFile)
  rescue Exception => msg
    puts msg
    return false, msg
  end

  if section == nil
    return true, content
  end

  begin
    return true, content[section]
  rescue Exception => msg
    puts msg
    return false, msg
  end
end
