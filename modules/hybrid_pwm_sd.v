// Hybrid PWM / Sigma Delta converter
//
// Uses 5-bit PWM, wrapped within a 10-bit Sigma Delta, with the intention of
// increasing the pulse width, since narrower pulses seem to equate to more noise

module hybrid_pwm_sd
(
	input clk,
	input n_reset,
	input [15:0] din,
	output dout
);

reg [4:0] pwmcounter;
reg [4:0] pwmthreshold;
reg [33:0] scaledin;
reg [15:0] sigma;
reg out;

assign dout=out;

always @(posedge clk, negedge n_reset) // FIXME reset logic;
begin
	if(!n_reset)
	begin
		sigma<=16'b00000100_00000000;
		pwmthreshold<=5'b10000;
	end
	else
	begin
		pwmcounter<=pwmcounter+1'b1;

		if(pwmcounter==pwmthreshold)
			out<=1'b0;

		if(pwmcounter==5'b11111) // Update threshold when pwmcounter reaches zero
		begin
			// Pick a new PWM threshold using a Sigma Delta
			scaledin<=33'd134217728 // (1<<(16-5))<<16, offset to keep centre aligned.
				+({1'b0,din}*61440); // 30<<(16-5)-1;
			sigma<=scaledin[31:16]+{5'b000000,sigma[10:0]};	// Will use previous iteration's scaledin value
			pwmthreshold<=sigma[15:11]; // Will lag 2 cycles behind, but shouldn't matter.
			out<=1'b1;
		end

	end
end

endmodule
