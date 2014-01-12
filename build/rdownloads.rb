#!/usr/bin/env ruby
require 'net/ftp'

def rdownloads  build, download, logger
  logtitle = "Download::"
  logger.info "========== Entering Download =========="
  if build[:protocol] == 'ftp'
      msg = "Incorrect protocol for build detector"
      logger.fatal logtitle + "#{msg}"
      return false, msg
  end

  begin
    server = build["server"]
    username = build["username"]
    password = build["password"]
    localpath = build["localpath"]
  rescue Exception => msg
    puts msg
    logger.fatal logtitle + "#{msg}"
    return false, msg
  end

  begin 
    if not File.directory?(localpath)
        if not Dir.mkdir(localpath)
          msg = 'Unexpected error in mkdir...'
          puts msg
          logger.fatal logtitle + "#{msg}"
          return false, msg
        end
    end
  end

  begin
    ftp = Net::FTP.new(server, username, password)
    ftp.passive = true
  rescue Exception => msg
    puts msg
    logger.fatal logtitle + "#{msg}"
    return false, msg
  end

  local = []
  for item in download[:file]
    begin
      local << File.join(localpath, item)
    rescue Exception => msg
      puts msg
      logger.fatal logtitle + "#{msg}"
      ftp.close()
      return false, msg
    end
  end

  for url in download[:url]
    begin
      ftp.getbinaryfile(url, local[download[:url].index(url)], 1024)
    rescue Exception => msg
      puts msg
      logger.fatal logtitle + "#{msg}"
      ftp.close()
      return false, msg
    end
  end

  lockspath = build['lockspath']
  locks = build['locks'].split(',')
  for lock in locks
    local << File.join(lockspath, lock)
  end

  logger.info logtitle + "#{local}"
  return true, local

end

