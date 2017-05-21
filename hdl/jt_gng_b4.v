`timescale 1ns/1ps

/*

	Schematic sheet: 85606-B-2-4/9 Object ROM

*/

module jt_gng_b4(
	input		V1,
	input		V2,
	input		V4,
	input		V8,
	input		V16,
	input		V32,
	input		V64,
	input		V128,
	input		OH,
	input		VINZONE,
	input		FLIP,

	output		BLTIMING,
	output		LV1,
	output		LV1_bq,
	output		OBFLIP1,
	output		OBFLIP2
);

reg [2:0] gal_14k[0:255];
wire [7:0] VV = {V128,V64,V32,V16,V8,V4,V2,V1};
reg [2:0] vgal;

initial begin
		$readmemh("../../rom/14k.hex",gal_14k);
end

always @(VV)
	vgal = gal_14k[VV];

assign BLTIMING = vgal[2];

assign LV1 = ~V1; // 8K

reg [3:0] timings;
always @(posedge OH) // 11K
	timings <= { V1, vgal[0], vgal[1], VINZONE };

assign DISPIM_bq = timings[1]; // vgal[1]
assign LV1_bq = ~timings[3]; // 8K
assign OBFLIP2 = timings[3] & FLIP; // 7K
assign OBFLIP1 = LV1_bq & FLIP; // 7K

endmodule // jt_gng_b4