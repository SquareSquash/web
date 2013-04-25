conditionally('authentication.strategy', 'ldap') do
  gem 'net-ldap', github: 'RoryO/ruby-net-ldap', require: 'net/ldap'
end
