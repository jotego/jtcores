#!/bin/bash
# Verify the actual captured byte layout, including both palette halves.
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../../../.." && pwd)
TASK_TMP=$(mktemp -d)
trap 'rm -rf "$TASK_TMP"' EXIT
ruby - "$REPO/cores/osman/ver/game/rest2bin.sh" "$TASK_TMP" <<'RUBY'
loader, work = ARGV
Dir.chdir(work)
def run(loader, *args)
  raise 'loader failed' unless system('bash', loader, *args)
end
def assert_file(name, expected)
  raise "Incorrect bytes: #{name}" unless File.binread(name) == expected
end
# Include every possible byte, nonzero high halves, and different region patterns.
ctrl = (0...16).map { |i| i*7 }.pack('C*')
palette = (0...4096).map { |i| (i*29 + i/4) & 255 }.pack('C*')
regions = %w[pf1 pf2 rs1 rs2 oram].each_with_index.to_h do |name, j|
  [name, (0...4096).map { |i| (i*13+j*41) & 255 }.pack('C*')]
end
full = ctrl + palette + regions.values.join
File.binwrite('rest.bin', full)
File.binwrite('nvram.bin', 'stale')
run(loader)
assert_file('rest.bin', full)
assert_file('pal.bin', palette.bytes.each_slice(4).flat_map { |b| b[0,2] }.pack('C*'))
assert_file('palh.bin', palette.bytes.each_slice(4).flat_map { |b| b[2,2] }.pack('C*'))
regions.each { |name, bytes| assert_file("#{name}.bin", bytes) }
raise 'scene retained NVRAM' if File.exist?('nvram.bin')
# Loading a legacy scene after a 32-bit scene must clear the high half.
legacy = ctrl + palette[0,2048] + regions.values.join
File.binwrite('rest.bin', legacy)
run(loader)
assert_file('pal.bin', palette[0,2048])
assert_file('palh.bin', "\0"*2048)
regions.each { |name, bytes| assert_file("#{name}.bin", bytes) }
seed = (0...128).map { |i| i^0xa5 }.pack('C*')
File.binwrite('rest.bin', seed)
run(loader)
assert_file('nvram.bin', seed)
File.binwrite('nvram.seed', seed)
run(loader, '--delete')
assert_file('nvram.bin', seed)
%w[pal palh pf1 pf2 rs1 rs2 oram].each do |name|
  raise "stale #{name}" if File.exist?("#{name}.bin")
end
File.delete('nvram.seed')
run(loader, '--delete')
raise 'NVRAM not deleted' if File.exist?('nvram.bin')
File.binwrite('rest.bin', 'bad')
raise 'invalid dump accepted' if system('bash', loader, out: File::NULL, err: File::NULL)
puts 'PASS: full palette, legacy scene, RAM placement, EEPROM and cleanup'
RUBY
