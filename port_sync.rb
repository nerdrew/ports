#!/opt/local/bin/ruby1.9

puts "Enter sudo password."
#puts `sudo port sync`

if $?.exitstatus != 0
	puts "port sync had an error"
	exit
end

# is a > b
def compare_version(a,b)
	a = a.is_a?(Array) ? a : a.split('.')
	b = b.is_a?(Array) ? b : b.split('.')
	a.zip(b).each do |x,y|
		return true if x > y
	end
	return false
end

File.open("#{ENV['HOME']}/ports/PortIndex.quick") do |pi|
	port_names = []
	while(pi.gets) do
		#puts $_
		port_names << $_.split(' ')[0]
	end
	ports = `port search --line --name --exact #{port_names.join(' ')}`
	ports = ports.split('--')
	duplicate_ports = []
	ports.each do |port|
		temp = port.scan(/^([\w\-_\.]+)\t([\w\.\-_]+)/)
		next if temp.size < 2
		duplicate_ports << temp
	end
	#puts duplicate_ports.inspect
	alt_port_versions = 
		`port info --line --version #{duplicate_ports.collect{|dp| dp[0][0]}.join(' ')}`.split("\n--\n")
	duplicate_ports.zip(alt_port_versions).each do |ports, ver|
		(std_ver, alt_ver) = (ver.strip == ports[0][1]) ? [1,0] : [0,1]
		if !compare_version(ports[alt_ver][1], ports[std_ver][1])
			puts "The custom #{ports[0][0]}@#{ports[alt_ver][1]} is an older version than the standard (@#{ports[std_ver][1]})."
		end
	end

end
