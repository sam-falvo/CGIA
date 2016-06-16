`timescale 1ns / 1ps

module feeder(
	input		dotclk_i,	// Dot clock
	input		scanline_en_i,	// 1 if refreshing a scanline.
	output		load_o,		// 1 to reload the shifter.
	output	[8:0]	f_adr_o		// Line buffer fetch address.
);

	wire next_load = (~scanline_en_i)? 1 : 0;
	wire next_adr = (~scanline_en_i)? 0 : (f_adr_o + 1);

	reg load_o;
	reg [8:0] f_adr_o;

	always @(posedge dotclk_i) begin
		load_o <= next_load;
		f_adr_o <= next_adr;
	end
endmodule

