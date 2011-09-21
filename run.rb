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
    puts "Commit changes before running!"
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

def update_tracking_from_macports
  exit if !repo_clean?(TRACKING_PORTS)

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

  if !repo_clean?(TRACKING_PORTS)
    print "Commit tracking changes to git? You need to do this before continuing. (Y/n): "
    if get_input(%w(y n), 'y') == 'y'
      puts "Committing changes."
      puts IO.popen(['git', 'add', TRACKING_PORTS]) {|io| io.read}
      puts IO.popen(['git', 'commit', '-m', 'Auto-commit changes to tracking ports']) {|io| io.read} if $?.exitstatus == 0
    end
  end
end

def update_custom_ports
  exit if !repo_clean?

  failed_diffs = []
  Dir.foreach(CUSTOM_PORTS) do |category|
    next if category == "." || category == ".."

    tracking = File.join(TRACKING_PORTS, category)
    Dir.foreach(File.join(CUSTOM_PORTS, category)) do |port|
      next if port == "." || port == ".."

      if !File.exists?(File.join(tracking, port))
        puts "Skipping #{port}. No tracking port."
        next
      end

      puts port
      diff = IO.popen(['git', 'diff', File.join(tracking, port)]) {|io| io.read}
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
  #`sudo cp -r #{custom_ports}/* #{macports_ports}`

  #puts `git add #{custom_ports} && git commit -m "Auto-commit tracking patches applied to custom ports"`
  #exit if $?.exitstatus > 0
end #def

def review_errors
end

def copy_new_from_macports(category, port)
end

case ARGV[0]
when "sync"
  update_tracking_from_macports
  update_custom_ports
when "test"
  puts get_input(%w(a b c), "c")
else
  puts "Usage: #{__FILE__} <sync>"
end
