require 'rubygems'
require 'utils/parser'
require 'utils/setini'
require 'service/run'

def awskey
  ## FIXME
  key_path = "/etc/boto.cfg"
  result, msg = parser(key_path, 'Credentials')
  if not result
    return false, msg
  end
  aws_key = msg
  # p aws_key

  # config/ics/config-autotest.ini
  icscfg = "config/ics/config-autotest.ini"
  ## FIXME
  setini(icscfg, "AdminPortal", '__DEPLOY_AWS_ACCESS_KEY_ICS__', aws_key['aws_access_key_id'])
  setini(icscfg, "AdminPortal", '__DEPLOY_AWS_SECRET_KEY_ICS__', aws_key['aws_secret_access_key'])

  ## FIXME
  cmd = "sed -i \"s/ //g\" #{icscfg}"
  result, msg = run(cmd)
  cmd = "grep -ir \" \" #{icscfg}"
  result, msg = run(cmd)

  # config/ics/s3cfg
  s3cfg = "config/ics/s3cfg"
  ## FIXME
  setini(s3cfg, 'global', 'access_key', aws_key['aws_access_key_id'])
  setini(s3cfg, 'global', 'secret_key', aws_key['aws_secret_access_key'])
 
end
