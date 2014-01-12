require 'rubygems'
require 'open4'

def run cmd, verbose=true
  prefix = "#{Time.now.to_s} [Execute Command]"
  puts "\n"
  if verbose
    puts "#{prefix} #{cmd}"
  else
    puts "#{prefix}  ...encrypted..."
  end
  #status = Open4::popen4(cmd) do | pid, stdin, stdout, stderr | end
  pid, stdin, stdout, stderr = Open4::popen4(cmd)
  output = stdout.read.strip
  msg = stderr.read.strip
  igored, status = Process::waitpid2 pid
  if output.size != 0
    if verbose
      puts output
    end
  end
  if status.exitstatus != 0
    if msg.size != 0
      puts msg
      return false, msg
    elsif output.size != 0
      puts output
      return false, output
    else
      puts "...ERROR\n"
      return false, "ERROR"
    end
  else
    puts "...OK\n"
    return true, output
  end
end
