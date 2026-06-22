# Usage: ruby add_file.rb <project-relative-file-path> <target-name>
require 'xcodeproj'
path, target_name = ARGV[0], ARGV[1]
proj = Xcodeproj::Project.open('KAIZENN.xcodeproj')
target = proj.targets.find { |t| t.name == target_name } or abort("no target #{target_name}")
# Skip if already referenced
if proj.files.any? { |f| f.real_path.to_s.end_with?(path) }
  puts "already referenced: #{path}"; exit 0
end
group = proj.main_group.find_subpath(File.dirname(path), true)
group.set_source_tree('SOURCE_ROOT')
ref = group.new_reference(path)
ref.source_tree = 'SOURCE_ROOT'
target.source_build_phase.add_file_reference(ref)
proj.save
puts "added #{path} to #{target_name}"
