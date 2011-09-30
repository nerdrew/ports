require 'fileutils' 

TRACKING_PORTS = "tracking"
MACPORTS_PORTS = "/opt/local/var/macports/sources/rsync.macports.org/release/tarballs/ports"
#MACPORTS_PORTS = "/Users/andrew/CleanRoom/10.6opt/local/var/macports/sources/rsync.macports.org/release/ports"
CUSTOM_PORTS = "custom"

def repo_clean?(dir = nil)
  args = ['git', 'status', '--porcelain']
  args << dir if dir
  git_status = IO.popen(args){|io| io.read}
  repo =  dir || "#{TRACKING_PORTS}|#{CUSTOM_PORTS}"
  if /#{repo}/ =~ git_status
    puts git_status
    return false
  else
    #puts "Repo clean: #{repo}"
    return true
  end
end

def get_input(allowed, default = nil)
  allowed << ''
  begin
    input = STDIN.gets
    if input.nil? || input =~ /^\s+$/
      input = default || ''
    end
    input = input.chomp.downcase
  end while !allowed.include?(input)
  return input
end

def get_category(port)
  return IO.popen(['port', '-q', 'info', '--category', port.strip]) {|io| io.read}.split(",")[0].strip
end

def update_tracking_from_macports
  if !repo_clean?(TRACKING_PORTS)
    puts "Commit changes before running!"
    exit
  end

  puts "Running `sudo port sync`"
  print `sudo port sync`

  Dir.foreach(CUSTOM_PORTS) do |category|
    next if category == "." || category == ".."

    tracking = File.join(TRACKING_PORTS, category)
    FileUtils.mkdir_p(tracking) if !File.exists?(tracking)
    Dir.foreach(File.join(CUSTOM_PORTS, category)) do |port|
      next if port == "." || port == ".."

      macport = File.join(MACPORTS_PORTS, category, port)
      next if !File.exists?(macport)

      FileUtils.cp_r(macport, tracking)
    end
  end
end

def update_custom_ports
  if !repo_clean?(CUSTOM_PORTS)
    puts "Commit changes before running!"
    exit
  end

  failed_diffs = []
  Dir.foreach(CUSTOM_PORTS) do |category|
    next if category == "." || category == ".."

    Dir.foreach(File.join(CUSTOM_PORTS, category)) do |port|
      next if port == "." || port == ".."

      tracking_port = File.join(TRACKING_PORTS, category, port)
      if !File.exists?(tracking_port)
        puts "Skipping #{port}. No tracking port."
        next
      end

      puts port
      #last_commit = IO.popen(['git', 'log', '-1', '--format=format:%H', ':/Auto-commit changes to tracking ports']) {|io| io.read}
      #diff = IO.popen(['git', 'diff', "#{last_commit}^", tracking_port]) {|io| io.read}
      diff = IO.popen(['git', 'diff', '-w', tracking_port]) {|io| io.read}
      if diff.size > 0 && $?.exitstatus == 0
        IO.popen(['git', 'apply', '-p2', "--directory=#{CUSTOM_PORTS}", '-'], 'w') {|io| io.write(diff)}
        if $?.exitstatus > 0
          File.open("#{category}_#{port}.diff", "w") {|f| f.write(diff)}
          failed_diffs << [category, port]
        end
      end
    end
  end

  puts "There were #{failed_diffs.size} failed patches."
  failed_diffs.each do |category, port|
    print "#{category}/#{port} patch failed. (E)dit, (s)kip, (a)bort: "
    case get_input(%w(e s a q), 'e')
    when "e"
      output = IO.popen(['mvim', '-O', File.join(CUSTOM_PORTS, category, port, "Portfile"), "#{category}_#{port}.diff"]) {|io| io.read}
      puts output if output
      print "Remove file '#{category}_#{port}.diff'? (Y/n): "
      if get_input(%w(y n), 'y') == 'y'
        FileUtils.rm("#{category}_#{port}.diff")
      end
    when "s"
      next
    #when "a", "q"
    else
      break
    end #case
  end #do

  # Copy the new updated custom ports to the macports sources folder
  print `sudo cp -r #{CUSTOM_PORTS}/* #{MACPORTS_PORTS}`

  # Refresh the portindex
  print `sudo portindex #{MACPORTS_PORTS}`
end #def

def commit_changes
  if !repo_clean?(TRACKING_PORTS)
    print "Commit tracking changes to git? (Y/n): "
    if get_input(%w(y n), 'y') == 'y'
      puts "Committing changes."
      print IO.popen(['git', 'add', TRACKING_PORTS]) {|io| io.read}
      print IO.popen(['git', 'commit', '-m', 'Auto-commit changes to tracking ports']) {|io| io.read} if $?.exitstatus == 0
    end
  end

  if !repo_clean?(CUSTOM_PORTS)
    print "Commit patches to custom ports to git? (Y/n): "
    if get_input(%w(y n), 'y') == 'y'
      puts "Committing changes."
      print IO.popen(['git', 'add', CUSTOM_PORTS]) {|io| io.read}
      print IO.popen(['git', 'commit', '-m', 'Auto-commit patches applied to custom ports']) {|io| io.read} if $?.exitstatus == 0
    end
  end
end

def copy_new_from_macports(port)
  category = get_category(port)
  exit if category.nil?

  tracking = File.join(TRACKING_PORTS, category)
  FileUtils.mkdir_p(tracking) if !File.exists?(tracking)
  macport = File.join(MACPORTS_PORTS, category, port)
  exit if !File.exists?(macport)

  FileUtils.cp_r(macport, tracking)
end

def overwrite_macport(*ports)
  ports.each do |port|
    category = get_category(port)
    if category.nil?
      puts "No category found for: #{port}"
      exit 
    end

    custom = File.join(CUSTOM_PORTS, category, port)
    if !File.exists?(custom)
      puts "No custom port: #{port}"
      exit 
    end
    macport = File.join(MACPORTS_PORTS, category)

    print IO.popen(['sudo', 'cp', '-r', custom, macport]){|io| io.read}
  end #ports.each do

  # Refresh the portindex
  print `sudo portindex #{MACPORTS_PORTS}`
end

case ARGV[0]
when "sync"
  update_tracking_from_macports
  update_custom_ports
  commit_changes
when "copy"
  copy_new_from_macports(ARGV[1])
when "overwrite"
  overwrite_macport(*ARGV[1..-1])
when "test"
  puts get_input(%w(a b c), "c")
else
  puts "Usage: #{__FILE__} sync"
  puts "Usage: #{__FILE__} copy <portname>"
end
