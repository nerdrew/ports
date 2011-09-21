require 'fileutils'

def sync
  # Ensure the git repo is clean before starting
  git_status = `git status --porcelain`
  if /tracking/ =~ git_status || /custom/ =~ git_status
    puts git_status
    puts "Commit changes before running!"
    exit
  end

  tracking_ports = "tracking"
  macports_ports = "/opt/local/var/macports/sources/rsync.macports.org/release/tarballs/ports"
  #macports_ports = "/Users/andrew/CleanRoom/10.6opt/local/var/macports/sources/rsync.macports.org/release/ports"
  custom_ports = "custom"

  failed_diffs = []
  Dir.foreach('custom') do |category|
    next if category == "." || category == ".."

    tracking = File.join(tracking_ports, category)
    FileUtils.mkdir_p(tracking) if !File.exists?(tracking)
    Dir.foreach(File.join(custom_ports, category)) do |port|
      next if port == "." || port == ".."

      macport = File.join(macports_ports, category, port)
      next if !File.exists?(macport)

      FileUtils.cp_r(macport, tracking)

      puts port
      diff = IO.popen(['git', 'diff', File.join(tracking, port)]) do |diff_io|
        diff_io.read
      end

      if diff.size > 0 && $?.exitstatus == 0
        IO.popen(['git', 'apply', '-p2', "--directory=#{custom_ports}", '-'], 'w') do |apply_io|
          apply_io.write(diff)
        end
        if $?.exitstatus > 0
          File.open("#{category}_#{port}.diff", "w") {|f| f.write(diff)}
          failed_diffs << [category, port]
        end
      end

    end

  end

  puts "There were #{failed_diffs.size} failed patches."
  failed_diffs.each do |category, port|
    puts "(e)dit, (s)kip, (a)bort: "
    while input = gets
      case input
      when "e", "E"
        output = IO.popen(['mvim', '-O', File.join("custom", category, port, "Portfile"), "#{category}_#{port}.diff"]) {|io| io.read}
        puts output if output
      when "s", "s"
        next
      else
        break
      end #case
    end #while
  end #do

  # Copy the new updated custom ports to the macports sources folder
  #`sudo cp -r #{custom_ports}/* #{macports_ports}`

  #puts `git add #{tracking_ports} && git commit -m "Auto-commit changes to tracking ports"`
  #puts `git add #{custom_ports} && git commit -m "Auto-commit tracking patches applied to custom ports"`
  #exit if $?.exitstatus > 0
end #def

def review_errors
end

def copy_from_macports(category, port)
end

case ARGV[0]
when "sync"
  sync
else
  puts "Usage: #{__FILE__} <sync>"
end
