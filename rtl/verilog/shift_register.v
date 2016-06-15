`timescale 1ns / 1ps

module shift_register(
	input		dotclk_i,
	input	[15:0]	dat_i,
	input		load_i,
	input		shift1_i,
	input		shift2_i,
	input		shift4_i,
	input		shift8_i,

	output	[15:0]	dat_o
);

	reg [15:0] dat_o;
	wire [15:0] load_value = {16{load_i}} & dat_i;
	wire [15:0] shift1_value = {16{shift1_i & ~load_i}} & (dat_o << 1);
	wire [15:0] shift2_value = {16{shift2_i & ~load_i}} & (dat_o << 2);
	wire [15:0] shift4_value = {16{shift4_i & ~load_i}} & (dat_o << 4);
	wire [15:0] shift8_value = {16{shift8_i & ~load_i}} & (dat_o << 8);

	always @(posedge dotclk_i) begin
		dat_o <= load_value | shift1_value | shift2_value | shift4_value | shift8_value;
	end
endmodule

