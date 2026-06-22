# Usage: ruby add_file.rb <project-relative-file-path> <target-name>
# Adds the file as a SOURCE_ROOT-pathed reference under the main group. Never modifies an
# existing group's source tree (doing so corrupts that group's <group>-relative children).
require 'xcodeproj'
path, target_name = ARGV[0], ARGV[1]
proj = Xcodeproj::Project.open('KAIZENN.xcodeproj')
target = proj.targets.find { |t| t.name == target_name } or abort("no target #{target_name}")
if proj.files.any? { |f| f.path == path }
  puts "already referenced: #{path}"; exit 0
end
ref = proj.main_group.new_reference(path)
ref.set_source_tree('SOURCE_ROOT')
ref.name = File.basename(path)
ref.path = path
target.source_build_phase.add_file_reference(ref)
proj.save
puts "added #{path} to #{target_name}"
