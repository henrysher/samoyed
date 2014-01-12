require 'net/ftp'

def isdigit? s
  result = s.match(/[^0-9]/) == nil ? true: false
  return result
end

def isnumber? s
  s.each_char {|letter|
    if not isdigit?(letter)
      return false
    end
  }
  return true
end



def listdir dirs
  ldir = [] 
  dirs.each do |dir|
    if dir.include?("DIR")
      ldir << dir.match(/DIR>[\s]*(.*)/)[1]
    else
      ldir << dir.match(/.*\s\d*(.*)/)[1]
    end
  end
  return ldir
end


def rdetector build, project, logger
  logtitle = "Detector::"
  logger.info "========== Entering Detector =========="
  if build[:protocol] == 'ftp'
      msg = "Incorrect protocol for build detector"
      puts msg
      logger.fatal logtitle + "#{msg}"
      return false, msg
  end
  begin
    # build
    server = build["server"]
    username = build["username"]
    password = build["password"]
    buildnum = build["buildnum"]
    formats = build["format"].split(',')
    checksum = build["checksum"]
    localpath = build["localpath"]
    remotepaths = build["remotepath"].split(',')

  rescue Exception => msg
    puts msg
    logger.fatal logtitle + "#{msg}"
    return false, msg
  end

  begin
    ftp = Net::FTP.new(server, username, password)
    ftp.passive = true
  rescue Exception => msg
    puts msg
    logger.fatal logtitle + "#{msg}"
    return false, msg
  end

  begin
    ## FIXME: Hardcoded here.
    if not project.include?("prefix")
      buildurl = 'build'
    else
      buildurl = project["prefix"]
    end
    buildurl = File.join(
      buildurl, 
      project["name"],
      project["version"],
      project["platform"] + project["arch"],
      project["language"],
      project["status"]
    )
  rescue Exception => msg
    puts msg
    logger.fatal logtitle + "#{msg}"
    ftp.close()
    return false, msg
  end
  logger.info logtitle + "#{buildurl}"

  begin
    ftp.chdir(buildurl)
    elements = listdir(ftp.list())
  rescue Exception => msg
    puts msg
    logger.fatal logtitle + "#{msg}"
    ftp.close()
    return false, msg
  end
  logger.info logtitle + "#{elements}"



  ## FIXME: Hardcoded
  builddef = "latest"
  build_url = url_suffix = []

  if not build.include?("mode") or (build.include?("mode") and build["mode"] != "pd")

  remotepaths.each {|remotepath| url_suffix << File.join("Release","Output", remotepath) }

  if isnumber?(buildnum)
    if elements.include?(buildnum)
      #url_suffix.each {|url| build_url << File.join(buildurl, buildnum, url) }
    else
      msg = "no such build now"
      logger.fatal logtitle + "#{msg}"
      return false, msg
    end
  elsif buildnum.downcase.include?(builddef)
    build_num = []
    for element in elements
    #  if element.downcase.include?(builddef)
    #    buildnum = element
    #    buildurl = File.join(buildurl, element, url_suffix)
    #    break
      if isnumber?(element)
        build_num << element
      end
    end
    #if buildurl.include?(url_suffix)

    if build_num
      buildnum = build_num.max
      #url_suffix.each {|url| build_url << File.join(buildurl, buildnum, url)} 
    else
      msg = "no latest build now"
      logger.fatal logtitle + "#{msg}"
      return false, msg
    end
    #end
  else
      msg = "no such build now"
      logger.fatal logtitle + "#{msg}"
      return false, msg
  end

  else
    remotepaths.each {|remotepath| url_suffix << File.join("output", remotepath) }
  end

  msg = "Build Number is found as #{buildnum}"
  logger.info logtitle + "#{msg}"

  ##FIXME: ugly code...
  build_url = ''
  check_url = ''
  download_url = []
  download_file = []

  for url in url_suffix
    buildpath = File.join(buildurl, buildnum, url)
    buildfolder = File.join("", buildpath)

    begin
      ftp.chdir(buildfolder)
      elements = listdir(ftp.list())
    rescue Exception => msg
      puts msg
      logger.fatal logtitle + "#{msg}"
      return false, msg
    end

    locks = build['locks'].split(',')

    vers = project["version"]
    pat1 = "-" + vers + "."
    pat2 = "-"

    for element in elements
      for format in formats
        if element.downcase.include?(format.downcase)
          flag = 0
          for lock in locks
            rpmname = lock.split(pat1)[0]
            rpmver =  lock.split(pat1)[1].split(pat2)[0]

            if element.include?(rpmname)
              rver = element.split(pat1)[1].split(pat2)[0]
              if rpmver < rver
                msg =  "RPM verison locks worked" + element
                logger.info logtitle + "#{msg}"
                puts msg
                flag = 1
                break
              end
            end
          end
          if flag  == 0
            build_url = File.join(buildpath, element)
            download_url << build_url
            download_file << element
          end
        end
      end
    end
  end

  ftp.close()

  if build_url.size > 0
    download = {}
    download[:num] = buildnum
    download[:url] = download_url
    download[:file] = download_file
    msg = "prepare to download..."
    logger.info logtitle + "#{msg}"
    logger.info download
    return true, download
  else
    msg = "no enough build files"
    logger.fatal logtitle + "#{msg}"
    return false, msg
  end
end


