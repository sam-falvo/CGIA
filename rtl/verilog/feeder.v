`timescale 1ns / 1ps

module feeder(
	input		dotclk_i,	// Dot clock
	input		scanline_en_i,	// 1 if refreshing a scanline.
	input	[3:0]	hctr_i,		// Horizontal pixel counter (low 4 bits)
	output	[8:0]	f_adr_o,	// Line buffer fetch address.
	output		load_o		// 1 to reload the shifter.
);
	reg load_o;
	reg [8:0] f_adr_o;

	wire [8:0] next_adr = (~scanline_en_i)? 0
			    : (load_o)? f_adr_o + 1
			    : f_adr_o;

	wire pix15 = hctr_i[3] & hctr_i[2] & hctr_i[1] & hctr_i[0];

	wire next_load = (~scanline_en_i)? 1 : pix15;

	always @(posedge dotclk_i) begin
		load_o <= next_load;
		f_adr_o <= next_adr;
	end
endmodule

