# Add PPA for Ruby 2.x
apt_repository 'brightbox-ruby-ng' do
  uri          'http://ppa.launchpad.net/brightbox/ruby-ng/ubuntu'
  distribution 'precise'
  components   ['main']
  keyserver    'keyserver.ubuntu.com'
  key          'C3173AA6'
end

# Add PPA for recent CouchDB binary
apt_repository 'couchdb' do
  uri          'http://ppa.launchpad.net/couchdb/stable/ubuntu'
  distribution 'precise'
  components   ['main']
  keyserver    'keyserver.ubuntu.com'
  key          'C17EAB57'
end

# Upgrade openssl to latest version
package 'openssl' do
  action :upgrade
end

# Install required packages
%w{libxml2-dev libxslt-dev ruby2.1 ruby2.1-dev curl}.each do |pkg|
  package pkg do
    action :install
  end
end
gem_package "bundler" do
  gem_binary "/usr/bin/gem"
end

# Create shared folders and set permissions
%w{ alm alm/current alm/shared alm/releases }.each do |dir|
  directory "/var/www/#{dir}" do
    owner node[:alm][:user]
    group node[:alm][:group]
    mode 0755
    recursive true
  end
end

require 'securerandom'
# Create new settings.yml unless it exists already
# Set these passwords in config.json to keep them persistent
unless File.exists?("/var/www/alm/shared/config/settings.yml")
  node.set['alm']['key'] = SecureRandom.hex(30) unless node['alm']['key']
  node.set['alm']['secret'] = SecureRandom.hex(30) unless node['alm']['secret']
  node.set['alm']['api_key'] = SecureRandom.hex(30) unless node['alm']['api_key']
else
  settings = YAML::load(IO.read("/var/www/alm/shared/config/settings.yml"))
  rest_auth_site_key = settings["#{node[:alm][:environment]}"]["rest_auth_site_key"]
  secret_token = settings["#{node[:alm][:environment]}"]["secret_token"]
  api_key = settings["#{node[:alm][:environment]}"]["api_key"]

  node.set_unless['alm']['key'] = rest_auth_site_key
  node.set_unless['alm']['secret'] = secret_token
  node.set_unless['alm']['api_key'] = api_key
end

template "/var/www/alm/shared/config/settings.yml" do
  source 'settings.yml.erb'
  owner node[:alm][:user]
  group node[:alm][:group]
  mode 0644
end

# Create new database.yml unless it exists already
# Set these passwords in config.json to keep them persistent
unless File.exists?("/var/www/alm/shared/config/database.yml")
  node.set_unless['mysql']['server_root_password'] = SecureRandom.hex(8)
  node.set_unless['mysql']['server_repl_password'] = SecureRandom.hex(8)
  node.set_unless['mysql']['server_debian_password'] = SecureRandom.hex(8)
  database_exists = false
else
  database = YAML::load(IO.read("/var/www/alm/shared/config/database.yml"))
  server_root_password = database["#{node[:alm][:environment]}"]["password"]

  node.set_unless['mysql']['server_root_password'] = server_root_password
  node.set_unless['mysql']['server_repl_password'] = server_root_password
  node.set_unless['mysql']['server_debian_password'] = server_root_password
  database_exists = true
end

template "/var/www/alm/shared/config/database.yml" do
  source 'database.yml.erb'
  owner node[:alm][:user]
  group node[:alm][:group]
  mode 0644
end

include_recipe "mysql::server"
include_recipe "database::mysql"

# Add configuration settings to database seed files
template "/var/www/alm/shared/db/seeds/_custom_sources.rb" do
  source '_custom_sources.rb.erb'
  owner node[:alm][:user]
  group node[:alm][:group]
  mode 0644
end

# Create default MySQL database
mysql_database "#{node[:alm][:name]}_#{node[:alm][:environment]}" do
  connection(
    :host     => 'localhost',
    :username => 'root',
    :password => node['mysql']['server_root_password']
  )
  action :create
end

include_recipe "couchdb::default"

# Create default CouchDB database
script "create CouchDB database #{node[:alm][:name]}" do
  interpreter "bash"
  code "curl -X PUT http://#{node[:alm][:host]}:#{node[:couch_db][:config][:httpd][:port]}/#{node[:alm][:name]}/"
  ignore_failure true
end

include_recipe "passenger_apache2::mod_rails"

execute "disable-default-site" do
  command "sudo a2dissite default"
end

web_app "alm" do
  docroot "/var/www/alm/current/public"
  server_name node[:alm][:host]
  server_aliases [ node[:alm][:host] ]
  rails_env node[:alm][:environment]
end
