#!/opt/local/bin/ruby1.9

puts "NOT FINISHED"
exit

require 'fileutils'
#
# Script to copy port from the standard directory to my ports directory.
#

if $*.size != 1
	puts "Usage: #{__FILE__} <port>"
end

port_path = `port dir #{port}`
if $?.exitstatus != 0
	puts "There was an error."
	puts port_dir
	exit
end


port_dir = File.basename(port_path)
category_dir = File.basename(File.absolute_path(port_path"/.."))
custom_ports = "#{ENV['HOME']}/ports"

if !Dir.exists?("#{custom_ports}/#{category}")
	FileUtils.mkdir("#{custom_ports}/#{category}")
end

if !Dir.exists?("#{custom_ports}/#{category}/#{port_path}"
	FileUtils.cp_r(port_path, "#{custom_ports}/#{category}"))
else
	# merge port
end
