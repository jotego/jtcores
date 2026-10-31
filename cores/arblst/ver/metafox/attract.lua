-- No cabinet inputs: capture the second attract loop at frames 2700-2900.
local flip = tonumber(os.getenv('METAFOX_FLIP') or '2')
assert(flip == 0 or flip == 2, 'METAFOX_FLIP must be 0 or 2')
local field = manager.machine.ioport.ports[':DSW'].fields['Flip Screen']
field.user_value = flip
