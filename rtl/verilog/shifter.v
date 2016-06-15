`timescale 1ns / 1ps

//
// The Shifter is responsible for accepting data from the line buffers
// at the dot-clock rate, and feeding individual pixels through to the
// color index bus.  The index bus is then translated via a set of
// palette registers into RGB triples.
//
// dotclk_i		25MHz for 640-pixel wide horizontal scanlines.
//
// dat_i		This bus carries the raw data from the line
//			buffers.  This is typically fed by the
//			Feeder module[1].
//
// load_i		1 to load the shift register with the data on
//			the dat_i bus; 0 to resume normal shifting
//			behavior.  NOTE: when the shift register loads,
//			the color index bus value WILL change to the
//			left-most pixel in the word.
//
// shift1_i		1 to shift the word left by one bit, AND to
//			present the most significant bit onto bit 0
//			of the color index bus.  Shifting takes effect
//			on each rising edge of the dotclk_i signal.
//
// shift2_i		As with shift1_i, except it causes the shift
//			register to shift left by two bits, AND to
//			present the topmost two bits onto the color
//			index bus (bits 1..0).
//
// shift4_i		As with shift1_i, except it causes the shift
//			register to shift left by four bits, AND to
//			present the topmost four bits onto the color
//			index bus (bits 3..0).
//
// shift8_i		As with shift1_i, except it causes the shift
//			register to shift left by eight bits, AND to
//			present the topmost eight bits onto the color
//			index bus (bits 7..0).
//
// index_xor_i		This 8-bit field asynchronously XORs the value
//			of the color index bus.  This allows lower
//			color depths to exploit higher color palette
//			registers by causing buts 7..N (where N is
//			4, 2, or 1 depending on whether or not
//			shift4_i, shift2_i, or shift1_i are set) to
//			take on programmable values.  This register
//			is not hardware-masked; therefore, setting
//			the lower bits causes the corresponding color
//			index bits to toggle, allowing for easier
//			inverse video effects.
//
// color_o		This 8-bit bus contains the current pixel's
//			color index.  This is typically fed to a
//			Color Look Up Table (CLUT) to translate this
//			value into a RGB triple.
//
// NOTES:
// 1.  The MGIA's shifter took it upon itself to read directly from the
//     line buffers.  However, this impedes unit-level testing efforts.
//     Thus, this behavior is factored out into a separate module, which
//     I've named "feeder."  Feeder is new to CGIA.
//

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

