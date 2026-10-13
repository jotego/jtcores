import math
import os
import unittest

rs_data = [ 4700, 2200, 1000, 470 ]
rs_volume = [ 100000, 47000, 22000, 10000 ]
input_voltage = 5
r_gnd = 10000

def data_resistances( bits ):
	rs_data_1s = []
	rs_data_0s = []

	for rs in rs_data:
		if bits % 2 == 0:
			rs_data_0s.append( rs )
		else:
			rs_data_1s.append( rs )
		bits >>= 1

	return ( rs_data_0s, rs_data_1s )

def volume_resistances( volume ):
	rs_volumes_1s = []

	for rs in rs_volume:
		 if volume % 2 == 1:
			  rs_volumes_1s.append( rs )
		 volume >>= 1

	return rs_volumes_1s

def parallel( resistances ):
	if len( resistances ) == 0:
		 return float('inf')
	elif len( resistances ) == 1:
		 return resistances[0]
	else:
		inverses = [ float('inf') if r == 0 else 1.0 / r for r in resistances ]
		sum_inverses = sum( inverses )
		if sum_inverses == 0:
			 return float('inf')
		else:
			 return 1.0 / sum_inverses

def series( resistances ):
	if len( resistances ) == 0:
		 return float('inf')
	else:
		 return sum( resistances )

def divider( r_top, r_bottom ):
	if math.isinf( r_top ) and math.isinf( r_bottom ):
		 return float('nan')
	elif math.isinf( r_top ):
		 return 0
	elif math.isinf( r_bottom ):
		 return 1
	else:
		 return float(r_bottom) / ( float(r_top) + float(r_bottom) )

# Approach A
# 
# Resistors on PROM (470R, 1k, 2.2k, 4.7k) are either connected to Vcc when the bit is 1, or
# **connected to GND** when the bit is 0. This creates a voltage divider where the top
# resistor R_data_top is the resistors connected to a “1” bit of the PROM data put in parallel,
# and the bottom resistor R_data_bottom is the resistors connected to a “0” bit of the PROM data
# put in parallel. We thus calculate
# 
# V_int = Vcc * R_data_bottom / ( R_data_top + R_data_bottom ),
#
# which is the voltage where the PROM resistors are joined together.
# 
# V_int is then the input voltage of another voltage divider where the top resistor R_vol_top is the resistors
# connected to a “1” bit of the volume put in parallel, and the bottom resistor R_vol_bottom is the 10K
# resistor R42 or R53. Thus
# 
# V_out = V_int * R_vol_bottom / ( R_vol_top + R_vol_bottom )

def output_voltage_A( voltage, data, volume, r_gnd ):
	rs_data_0s, rs_data_1s = data_resistances( data )
	rs_volumes_1s = volume_resistances( volume )

	r_one_bits = parallel( rs_data_1s )
	r_zero_bits = parallel( rs_data_0s )
	v_int = voltage * divider( r_one_bits, r_zero_bits )

	r_volume = parallel( rs_volumes_1s )
	v_out = v_int * divider( r_volume, r_gnd )

	# Adjustment based on analysis of recordings from original hardware
	# 
	# adj_db = volume * 2 / 15 - 1.7 # manual linear regression
	# adj_db = volume * 0.1618214286 - 1.939904762 # automatic linear regression
	# automatic linear regression with half the slope (and we don’t care about the offset because
	# we subtract it out when we divide by v_out_adj_max to scale the table to a max of FF)
	adj_db = volume * 0.0809107143 - 1.939904762
	v_out_adj = v_out * 10 ** ( adj_db / 10 )

	return v_out_adj, v_out

# Approach B
# 
# Resistors on PROM (470R, 1k, 2.2k, 4.7k) are either connected to Vcc when the bit is 1, or
# **floating** when the bit is 0. This creates a voltage divider where the top resistor R_top
# is composed of two resistors in series, R_data and R_vol, where R_data is the resistors
# connected to a “1” bit of the PROM data put in parallel, and R_vol is the resistors connected
# to a “1” bit of the volume put in parallel. The bottom resistor of the divider, R_bottom is
# the 10K resistor R42 or R53. We thus calculate
# 
# V_out = Vcc * R_bottom / ( R_data + R_vol + R_bottom ).

def output_voltage_B( voltage, data, volume, r_gnd ):
	_rs_data_0s, rs_data_1s = data_resistances( data )
	rs_volumes_1s = volume_resistances( volume )

	r_one_bits = parallel( rs_data_1s )
	r_volume = parallel( rs_volumes_1s )

	v_out = voltage * divider( r_one_bits + r_volume, r_gnd )

	return v_out

class TestData( unittest.TestCase ):
	def test_no_bits( self ):
		self.assertEqual( data_resistances( 0 ), ( [ 4700, 2200, 1000, 470 ], [] ) )

	def test_bit0( self ):
		self.assertEqual( data_resistances( 1 ), ( [ 2200, 1000, 470 ], [ 4700 ] ) )

	def test_bit1( self ):
		self.assertEqual( data_resistances( 2 ), ( [ 4700, 1000, 470 ], [ 2200 ] ) )

	def test_bits12( self ):
		self.assertEqual( data_resistances( 6 ), ( [ 4700, 470 ], [ 2200, 1000 ] ) )

	def test_bits013( self ):
		self.assertEqual( data_resistances( 11 ), ( [ 1000 ], [ 4700, 2200, 470 ] ) )

	def test_all_bits( self ):
		self.assertEqual( data_resistances( 15 ), ( [], [ 4700, 2200, 1000, 470 ] ) )

class TestVolume( unittest.TestCase ):
	def test_vol0( self ):
		self.assertEqual( volume_resistances( 1 ), [ 100000 ] )

	def test_vol3( self ):
		self.assertEqual( volume_resistances( 8 ), [ 10000 ] )

	def test_vol02( self ):
		self.assertEqual( volume_resistances( 5 ), [ 100000, 22000 ] )

	def test_vol123( self ):
		self.assertEqual( volume_resistances( 14 ), [ 47000, 22000, 10000 ] )

	def test_all_vol( self ):
		self.assertEqual( volume_resistances( 15 ), [ 100000, 47000, 22000, 10000 ] )

class TestParallel( unittest.TestCase ):
	def test_parallel0( self ):
		self.assertEqual( parallel( [] ), float('inf') )

	def test_parallel1( self ):
		self.assertAlmostEqual( parallel( [ 220 ] ), 220, places=1 )

	def test_parallel2_eq( self ):
		self.assertAlmostEqual( parallel( [ 4700, 4700 ] ), 2350, places=1 )

	def test_parallel2( self ):
		self.assertAlmostEqual( parallel( [ 1500, 2200 ] ), 891.89, places=1 )

	def test_parallel3_eq( self ):
		self.assertAlmostEqual( parallel( [ 1500, 1500, 1500 ] ), 500, places=1 )

	def test_parallel3( self ):
		self.assertAlmostEqual( parallel( [ 1500, 470, 2200 ] ), 307.80, places=1 )

	def test_parallel4( self ):
		self.assertAlmostEqual( parallel( [ 82, 220, 470, 1200 ] ), 50.76, places=1 )

	def test_parallel_inf1( self ):
		self.assertAlmostEqual( parallel( [ 220, float('inf') ] ), 220, places=1 )

	def test_parallel_inf_all( self ):
		self.assertAlmostEqual( parallel( [ float('inf'), float('inf'), float('inf') ] ), float('inf'), places=1 )

	def test_parallel_zero1( self ):
		self.assertAlmostEqual( parallel( [ 0, 470, 0 ] ), 0, places=1 )

	def test_parallel_zero_all( self ):
		self.assertAlmostEqual( parallel( [ 0, 0, 0, 0 ] ), 0, places=1 )

class TestSeries( unittest.TestCase ):
	def test_series0( self ):
		self.assertEqual( series( [] ), float('inf') )

	def test_series1( self ):
		self.assertAlmostEqual( series( [ 220 ] ), 220, places=1 )

	def test_series2_eq( self ):
		self.assertAlmostEqual( series( [ 4700, 4700 ] ), 9400, places=1 )

	def test_series2( self ):
		self.assertAlmostEqual( series( [ 1500, 2200 ] ), 3700, places=1 )

	def test_series3_eq( self ):
		self.assertAlmostEqual( series( [ 1500, 1500, 1500 ] ), 4500, places=1 )

	def test_series3( self ):
		self.assertAlmostEqual( series( [ 1500, 470, 2200 ] ), 4170, places=1 )

	def test_series4( self ):
		self.assertAlmostEqual( series( [ 82, 220, 470, 1200 ] ), 1972, places=1 )

	def test_series_inf1( self ):
		self.assertAlmostEqual( series( [ 220, float('inf') ] ), float('inf'), places=1 )

	def test_series_inf_all( self ):
		self.assertAlmostEqual( series( [ float('inf'), float('inf'), float('inf') ] ), float('inf'), places=1 )

	def test_series_zero1( self ):
		self.assertAlmostEqual( series( [ 0, 470, 0 ] ), 470, places=1 )

	def test_series_zero_all( self ):
		self.assertAlmostEqual( series( [ 0, 0, 0, 0 ] ), 0, places=1 )

class TestDivider( unittest.TestCase ):
	def test_divider_top( self ):
		self.assertAlmostEqual( divider( 0, 4700 ), 1, places=5 )

	def test_divider_bottom( self ):
		self.assertAlmostEqual( divider( 220, 0 ), 0, places=5 )

	def test_divider_middle( self ):
		self.assertAlmostEqual( divider( 33000, 33000 ), 0.5, places=5 )

	def test_divider_150_470( self ):
		self.assertAlmostEqual( divider( 150, 470 ), 0.7580645161, places=5 )

	def test_divider_82_3300( self ):
		self.assertAlmostEqual( divider( 82, 3300 ), 0.9757539917, places=5 )

	def test_divider_8200_470( self ):
		self.assertAlmostEqual( divider( 8200, 470 ), 0.0542099193, places=5 )

	def test_divider_112000_54000( self ):
		self.assertAlmostEqual( divider( 112000, 54000 ), 0.3253012048, places=5 )

	def test_divider_inf_top( self ):
		self.assertAlmostEqual( divider( float('inf'), 470 ), 0, places=5 )

	def test_divider_inf_bottom( self ):
		self.assertAlmostEqual( divider( 112000, float('inf') ), 1, places=5 )

	def test_divider_inf_all( self ):
		self.assertEqual( math.isnan( divider( float('inf'), float('inf') ) ), True )

if __name__ == '__main__':
	if os.environ.get( "TEST", False ):
		unittest.main()

	i = 0
	v_out_adj_max, _ = output_voltage_A( input_voltage, 15, 15, r_gnd )
	for volume in range( 16 ):
		for bits in range( 16 ):
			v_out_adj, v_out = output_voltage_A( input_voltage, bits, volume, r_gnd )
			dig = round( 255 * v_out_adj / v_out_adj_max )
			print( f"{dig:02X}", end=" " )
			i += 1
		print()

	print()
