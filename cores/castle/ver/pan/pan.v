module test;
	wire [2:0] pan;

	integer k;

	assign pan=k[2:0];

	initial begin
		$dumpfile("test.lxt");
		$dumpvars;
		$dumpon;
	end

	initial begin
		for( k=0; k<8; k=k+1 ) begin
			#10;
			//imprimir todas la puertas
			// mask 6L, 5L, 4L,... 0L, --- 6R, 5R, 4R... 0R
			$display("%d -> %d%d%d%d%d%d%d -- %d%d%d%d%d%d%d",
				pan,  pan_dec12345, pan_dec1236, pan_dec1246, pan_dec1345, pan_dec126, pan_dec14, pan_dec15,
				      pan_dec34567, pan_dec2567, pan_dec2467, pan_dec3457, pan_dec267, pan_dec47, pan_dec37 );
		end
		$finish;
	end

	nand ar48( ar48_y,  pan[0], ~pan[1], ~pan[2] );
	nand at58( at58_y, ~pan[0],  pan[1], ~pan[2] );
	nand at48( at48_y,  pan[0],  pan[1], ~pan[2] );
	nand ar58( ar58_y, ~pan[0], ~pan[1],  pan[2] );
	nand av52( av52_y,  pan[0], ~pan[1],  pan[2] );
	nand at50( at50_y, ~pan[0],  pan[1],  pan[2] );

	nand aw33( pan_dec15, ar48_y, av52_y );
	nand av32( pan_dec1236, at50_y, at48_y, at58_y, ar48_y );
	nand aw20( pan_dec1246, at50_y, ar58_y, at58_y, ar48_y );
	nand aw13( pan_dec1345, av52_y, ar58_y, at48_y, ar48_y );
	nand ar28( pan_dec126, ar48_y, at58_y, at50_y );
	nand  aw9(  pan_dec12345, ar48_y, at58_y, at48_y, ar58_y, av52_y );
	nand ap42( pan_dec14, ar48_y, ar58_y );

	nand  an95( an95_y,  ~pan[2],  pan[1], ~pan[0] );
	nand  am92( am92_y,  ~pan[2],  pan[1],  pan[0] );
	nand  an86( an86_y,   pan[2], ~pan[1], ~pan[0] );
	nand  am90( am90_y,   pan[2], ~pan[1],  pan[0] );
	nand an106( an106_y,  pan[2],  pan[1], ~pan[0] );
	nand am103( am103_y,  pan[2],  pan[1],  pan[0] );

	nand ak97( pan_dec37,  am92_y, am103_y );
	nand ak77( pan_dec47, am103_y,  an86_y );
	nand aj99( pan_dec2567, am103_y, an106_y,  am90_y, an95_y );
	nand aj81( pan_dec3457, am103_y,  am90_y,  an86_y, am92_y );
	nand ah91( pan_dec2467, am103_y, an106_y,  an86_y, an95_y );
	nand aj95( pan_dec34567,  am92_y,  an86_y,  am90_y, an106_y, am103_y );
	nand ah98( pan_dec267,  an95_y, an106_y, am103_y );


endmodule