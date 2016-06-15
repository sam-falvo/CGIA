`timescale 1ns / 1ps

module shifter(
	input		dotclk_i,
	input	[15:0]	dat_i,
	input		load_i,
	input		shift1_i,
	input		shift2_i,
	input		shift4_i,
	input		shift8_i,
	input	[7:0]	index_xor_i,

	output	[7:0]	color_o
);

	wire [15:0] q;

	shift_register sr(
		.dotclk_i(dotclk_i),
		.dat_i(dat_i),
		.load_i(load_i),
		.shift1_i(shift1_i),
		.shift2_i(shift2_i),
		.shift4_i(shift4_i),
		.shift8_i(shift8_i),
		.dat_o(q)
	);

	wire [7:0] bpp1 = {7'b0000000, q[15]} & {8{shift1_i}};
	wire [7:0] bpp2 = {6'b000000, q[15:14]} & {8{shift2_i}};
	wire [7:0] bpp4 = {4'b0000, q[15:12]} & {8{shift4_i}};
	wire [7:0] bpp8 = q[15:8] & {8{shift8_i}};

	assign color_o = (bpp1 | bpp2 | bpp4 | bpp8) ^ index_xor_i;
endmodule

