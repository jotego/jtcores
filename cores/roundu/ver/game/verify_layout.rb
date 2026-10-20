#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 18-10-2026

require 'digest'
require 'json'
require 'psych'
require 'rexml/document'

Dir.chdir(__dir__)
core = File.expand_path('../..')
repo = File.expand_path('../../../..')
contract_path = File.join(core, 'cfg/rom_layout.json')
mem_path = File.join(core, 'cfg/mem.yaml')
mra_path = File.join(repo, 'release/mra/Round Up 5 - Super Delta Force.mra')
contract = JSON.parse(File.read(contract_path))
mem = Psych.safe_load(File.read(mem_path))
mra = REXML::Document.new(File.read(mra_path))
raise 'wrong set' unless mra.elements['misterromdescription/setname'].text == 'roundup5'
raise 'wrong button count' unless mra.elements['misterromdescription/buttons'].attributes['count'] == '4'

shape = [
  ['master_rom', 0x000000, 0, 16],
  ['slave_rom', 0x080000, 0, 16],
  ['sprites:sprites_l', 0x100000, 1, 32],
  ['sprites:sprites_h', 0x1c0000, 2, 32],
  ['audiocpu', 0x280000, 3, 8],
  ['oki', 0x290000, 3, 8]
]
files = {}
regions = shape.map do |name, start, bank, width|
  region = contract.fetch('regions').find { |r| r.fetch('name') == name }
  raise "missing region #{name}" unless region
  region.fetch('operations').each { |op| files[op.fetch('file')] = [op, start] }
  { name: name, stream_start: start, size: region.fetch('size'),
    sdram_bank: bank, interface_width: width }
end

position = 0
checked = []
fills = []
mra.elements["misterromdescription/rom[@index='0']"].elements.each do |node|
  case node.name
  when 'interleave'
    width = Integer(node.attributes.fetch('output').to_s) / 8
    lengths = []
    node.elements.each('part') do |part|
      name = part.attributes.fetch('name').to_s
      op, start = files.fetch(name)
      mapping = part.attributes.fetch('map').to_s.reverse
      lanes = mapping.chars.each_index.select { |i| mapping[i] != '0' }
      raise "unsupported map #{name}" unless lanes.size == 1 && mapping[lanes.first] == '1'
      raise "wrong lane #{name}" unless position + lanes.first == start + op.fetch('offset')
      raise "wrong stride #{name}" unless width == op.fetch('stride') && op.fetch('group') == 1
      raise "unexpected source offset #{name}" unless part.attributes['offset'].to_i == op.fetch('source_offset')
      raise "wrong CRC #{name}" unless part.attributes.fetch('crc').to_s == op.fetch('crc32')
      lengths << Integer(part.attributes['length'] || op.fetch('length'))
      checked << name
    end
    raise 'unequal interleave lengths' unless lengths.uniq.size == 1 && lengths.size == width
    position += lengths.first * width
  when 'part'
    if node.attributes['name']
      name = node.attributes.fetch('name').to_s
      op, start = files.fetch(name)
      raise "wrong byte region #{name}" unless op.fetch('stride') == 1 && position == start + op.fetch('offset')
      raise "wrong CRC #{name}" unless node.attributes.fetch('crc').to_s == op.fetch('crc32')
      position += Integer(node.attributes['length'] || op.fetch('length'))
      checked << name
    else
      length = Integer(node.attributes.fetch('repeat').to_s)
      raise 'unexpected padding' unless position == 0x2c0000 && length == 0x10000 && node.text.strip == 'FF'
      fills << { stream_start: position, size: length, stream_byte: 255, downloaded_byte: 0 }
      position += length
    end
  else
    raise "unexpected ROM node #{node.name}"
  end
end
raise 'wrong file coverage' unless checked.sort == files.keys.sort && checked.size == 27
raise 'wrong stream length' unless position == 0x2d0000
raise 'missing padding conversion' unless fills.size == 1 && mem.fetch('download').fetch('post_data')
raise 'RAM in SDRAM' if mem.fetch('sdram').fetch('banks').any? { |b| b.fetch('buses').any? { |x| x['rw'] } }
raise 'ROM in BRAM' if mem.fetch('bram').any? { |b| b['rom'] || b['prom'] || !b.fetch('rw') }
bram_bytes = mem.fetch('bram').sum do |b|
  size = b.fetch('size')
  size.is_a?(Integer) ? size : Integer(size.delete_suffix('kB')) * 1024
end

result = {
  game: 'roundup5', stage: 'declaration-and-loader-layout',
  author: 'Andrea Bogazzi', creation_date: '18-10-2026',
  rom_stream_size: position, regions: regions, padding: fills,
  sdram_download: { swab: 1, even_address_lane: 'low', odd_address_lane: 'high' },
  slave_rom_read_adapter: 'swap bytes of each SDRAM word for both 68000 and V30 consumers',
  palette_cpu_adapter: 'V30 low byte maps successive bytes to a big-endian 16-bit palette word',
  palette_rom: 'none declared; any later separate palette ROM belongs in BRAM',
  bram_capacity_bytes: bram_bytes, bram_physical_fit_verified: false,
  matched_physical_file_layouts: checked.size, actual_rom_bytes_verified: false,
  source_contract_sha256: Digest::SHA256.file(contract_path).hexdigest,
  mem_config_sha256: Digest::SHA256.file(mem_path).hexdigest,
  mra_sha256: Digest::SHA256.file(mra_path).hexdigest,
  loader_hdl_sha256: Digest::SHA256.file(File.join(core, 'hdl/jtroundu_download.v')).hexdigest
}
File.write(File.join(core, 'cfg/rom_layout_fpga.json'), JSON.pretty_generate(result) + "\n")
puts "PASS: #{checked.size} ROM file layouts, #{position} stream bytes, #{bram_bytes} BRAM bytes"
