#
# Cookbook Name:: varnish
# Recipe:: default
#

require 'etc'

# This needs to be in keywords: www-servers/varnish ~x86
package "varnish" do
  action :install
end


#####
#
# These are generic tuning parameters for each instance size. You may want to
# tune them if they prove inadequate.
#
#####

CACHE_DIR = '/var/lib/varnish'
size = `curl -s http://instance-data.ec2.internal/latest/meta-data/instance-type`
case size
when /m1.small/ # 1.7G RAM, 1 ECU, 32-bit, 1 core
  THREAD_POOLS=1
  THREAD_POOL_MAX=1000
  OVERFLOW_MAX=2000
  CACHE="file,#{CACHE_DIR},100GB"
when /m1.large/ # 7.5G RAM, 4 ECU, 64-bit, 2 cores
  THREAD_POOLS=2
  THREAD_POOL_MAX=2000
  OVERFLOW_MAX=4000
  CACHE="file,#{CACHE_DIR},100GB"
when /m1.xlarge/ # 15G RAM, 8 ECU, 64-bit, 4 cores
  THREAD_POOLS=4
  THREAD_POOL_MAX=4000
  OVERFLOW_MAX=8000
  CACHE="file,#{CACHE_DIR},100GB"
when /c1.medium/ # 1.7G RAM, 5 ECU, 32-bit, 2 cores
  THREAD_POOLS=2
  THREAD_POOL_MAX=2000
  OVERFLOW_MAX=4000
  CACHE="file,#{CACHE_DIR},100GB"
when /c1.xlarge/ # 7G RAM, 20 ECU, 64-bit, 8 cores
  THREAD_POOLS=8
  THREAD_POOL_MAX=8000 # This might be too much.
  OVERFLOW_MAX=16000
  CACHE="file,#{CACHE_DIR},100GB"
when /m2.xlarge/ # 17.1G RAM, 6.5 ECU, 64-bit, 2 cores
  THREAD_POOLS=2
  THREAD_POOL_MAX=2000
  OVERFLOW_MAX=4000
  CACHE="file,#{CACHE_DIR},100GB"
when /m2.2xlarge/ # 34.2G RAM, 13 ECU, 64-bit, 4 cores
  THREAD_POOLS=4
  THREAD_POOL_MAX=4000
  OVERFLOW_MAX=8000
  CACHE="file,#{CACHE_DIR},100GB"
when /m2.4xlarge/ # 68.4G RAM, 26 ECU, 64-bit, 8 cores
  THREAD_POOLS=8
  THREAD_POOL_MAX=8000 # This might be too much.
  OVERFLOW_MAX=16000
  CACHE="file,#{CACHE_DIR},100GB"
else # This shouldn't happen, but do something rational if it does.
  THREAD_POOLS=1
  THREAD_POOL_MAX=2000
  OVERFLOW_MAX=2000
  CACHE="file,#{CACHE_DIR},100GB"
end


# Install the varnish monit file.
template '/etc/monit.d/varnishd.monitrc' do
  owner node[:owner_name]
  group node[:owner_name]
  source 'varnishd.monitrc.erb'
  variables({
    :thread_pools => THREAD_POOLS,
    :thread_pool_max => THREAD_POOL_MAX,
    :overflow_max => OVERFLOW_MAX,
    :cache => CACHE
  })
end


# Make sure the cache directory exists.
unless FileTest.exist? CACHE_DIR
  user = Etc::getpwnam(node[:owner_name])
  File.mkdir(CACHE_DIR)
  File.chown(user.uid,user.gid,CACHE_DIR)
end


# Edit nginx config to change it off of port 80; we may or may not want the recipe to do this?
# The idea is that for the typical simple deployment, nginx will be listening in some config to port 80.
# We want to change that to port 81, so that the default varnish config can listen on port 80 and forward to 81.

execute "Edit the config files inline to change nginx from listening on port 80 to listening on port 81" do
  command %Q{
    perl -p -i -e's{listen 81;}{listen 80;}' /etc/nginx/servers/*.conf
  }
end

# Restart nginx

execute "Restart nginx" do
  command %Q{
    /etc/init.d/nginx restart
  }
end

# Start/restart varnish

execute "Start varnish" do
  command %Q{
    monit restart varnish_80
  }
end
