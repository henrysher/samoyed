require 'rubygems'
require 'utils/parser'
require 'utils/setini'

def yumkey yumcfg
  ## FIXME
  key_path = "/etc/icsyum.cfg"
  result, msg = parser(key_path, 'Credentials')
  if not result
    return false, msg
  end
  aws_key = msg

  setini(yumcfg, 'YumRepo', 'username', aws_key['username'])
  setini(yumcfg, 'YumRepo', 'password', aws_key['password'])
 
end
