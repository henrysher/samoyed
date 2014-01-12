require 'rubygems'
require 'net/ssh'
require 'net/sftp'
require 'net/ssh/proxy/http'



 VALID_SSH_OPTIONS = [
       :keys, :keys_only, :key_data,
       :user, 
       :password, 
       :port, 
       :timeout, :verbose,
       :cmd, :localpath, :remotepath,
       :proxy, 
 ]

 VALID_PROXY_OPTIONS = [
       :user, :password
 ]


def sshproxy host, port, options={}
   invalid_options = options.keys - VALID_PROXY_OPTIONS
   if invalid_options.any?
     msg = "invalid option(s):  {invalid_options.join(', ')}"
     return false, msg
   end

  begin
    proxy = Net::SSH::Proxy::HTTP.new(host, port, options)
  rescue Exception => msg
    puts msg
    return false, msg
  end
  return true, proxy
end

def sshexec host, user, options={}
   invalid_options = options.keys - VALID_SSH_OPTIONS
   if invalid_options.any?
     msg = "invalid option(s):  {invalid_options.join(', ')}"
     return false, msg
   end

  if not options[:timeout] 
    options[:timeout] = 10
  end

  if not options[:verbose]
    options[:verbose] = Logger::FATAL
  end
  
  cmd = options.delete(:cmd)

  begin
    ssh_channel = Net::SSH.start(host, user, options)
  rescue Exception => msg
    puts msg
    return false, msg
  end

  begin
    output = ssh_channel.exec!(cmd)
    puts "\n"
    puts "#{Time.now.to_s} [Execute Command] #{cmd}"
    puts output
    puts "...OK\n"
  rescue Exception => msg
    puts msg
    return false, msg
  end

  # begin
  #   common_cmd = "date"
  #   common_output = ssh_channel.exec!(common_cmd)
  #   puts common_output
  # rescue Exception => msg
  #   puts msg
  #   return false, msg
  # end

  ssh_channel.close()

  #if output.to_s.downcase.include?("fail") or output.to_s.downcase.include?("err")
  #  return false, output
  #end

  return true, output
end

def sshdownload host, user, options={}
   invalid_options = options.keys - VALID_SSH_OPTIONS
   if invalid_options.any?
     msg = "invalid option(s):  {invalid_options.join(', ')}"
     return false, msg
   end

  if not options[:timeout] 
    options[:timeout] = 10
  end

  if not options[:verbose]
    options[:verbose] = Logger::FATAL
  end

  localpath = options.delete(:localpath)
  remotepath = options.delete(:remotepath)
  begin 
    sftp_channel = Net::SFTP.start(host, user, options)
  rescue Exception => msg
    puts msg
    return false, msg
  end

  begin
    output = sftp_channel.download!(remotepath, localpath)
  rescue Exception => msg
    puts msg
    return false, msg
  end

  sftp_channel.close_channel()

  return true, output
end


def sshupload host, user, options={}
   # p host, user, options
   invalid_options = options.keys - VALID_SSH_OPTIONS
   if invalid_options.any?
     msg = "invalid option(s):  {invalid_options.join(', ')}"
     return false, msg
   end
 
  if not options[:timeout] 
    options[:timeout] = 10
  end
  
  if not options[:verbose]
    options[:verbose] = Logger::FATAL
  end

  localpath = options.delete(:localpath)
  remotepath = options.delete(:remotepath)

  begin 
    sftp_channel = Net::SFTP.start(host, user, options)
  rescue Exception => msg
    puts msg
    return false, msg
  end

  begin
    output = sftp_channel.upload!(localpath, remotepath)
  rescue Exception => msg
    puts msg
    return false, msg
  end

  sftp_channel.close_channel()

  return true, output
end

