`timescale 1ns / 1ps

//
// This test script exercises the CGIA's configurable shift register for
// pushing pixels out to the color pen bus.  Unlike the lower-level
// test_shift_register module, this module exercises the color bus output
// itself.
//

module test_shifter();
	reg [15:0] story_o;	// Holds grep tag for failing test cases.
	reg clk_o;		// Dot clock
	reg load_o;		// 1 if we need to reload register.
	reg shift1_o;		// 1 if we are in 1bpp mode.
	reg shift2_o;		// 1 if we are in 2bpp mode.
	reg shift4_o;		// 1 if we are in 4bpp mode.
	reg shift8_o;		// 1 if we are in 8bpp mode.
	reg [15:0] dat_o;	// Data to load register with.
	reg [7:0] index_xor_o;	// Data to XOR with final color index.

	wire [7:0] color_i;	// Current shift register value.

	// Core Under Test
	shifter s(
		.dotclk_i(clk_o),
		.dat_i(dat_o),
		.load_i(load_o),
		.shift1_i(shift1_o),
		.shift2_i(shift2_o),
		.shift4_i(shift4_o),
		.shift8_i(shift8_o),
		.index_xor_i(index_xor_o),
		.color_o(color_i)
	);

	// 25MHz clock (1/25MHz = 40ns)
	always begin
		#40 clk_o <= ~clk_o;
	end

	// Test script starts here.
	initial begin
		clk_o <= 0;
		index_xor_o <= 0;

		// The shift register should be loadable at any time.
		story_o <= 16'h0000;
		load_o <= 1;
		shift1_o <= 1;
		shift2_o <= 0;
		shift4_o <= 0;
		shift8_o <= 0;
		dat_o <= 16'hAAAA;
		wait(clk_o); wait(~clk_o);
		if(color_i !== 8'b00000001) begin
			$display("@E %04X Expected $01; got $%02X", story_o, color_i);
			$stop;
		end

		// The shift register should support 1bpp shifts.
		story_o <= 16'h0100;
		load_o <= 0;
		shift1_o <= 1;
		shift2_o <= 0;
		shift4_o <= 0;
		shift8_o <= 0;
		wait(clk_o); wait(~clk_o);
		if(color_i !== 8'b00000000) begin
			$display("@E %04X Expected $00; got $%02X", story_o, color_i);
			$stop;
		end

		// The shift register should support 2bpp shifts.
		story_o <= 16'h0200;
		load_o <= 0;
		shift1_o <= 0;
		shift2_o <= 1;
		shift4_o <= 0;
		shift8_o <= 0;
		wait(clk_o); wait(~clk_o);
		if(color_i !== 8'b00000001) begin
			$display("@E %04X Expected $01; got $%02X", story_o, color_i);
			$stop;
		end

		// The shift register should support 4bpp shifts.
		story_o <= 16'h0300;
		load_o <= 0;
		shift1_o <= 0;
		shift2_o <= 0;
		shift4_o <= 1;
		shift8_o <= 0;
		wait(clk_o); wait(~clk_o);
		if(color_i !== 8'b00000101) begin
			$display("@E %04X Expected $05; got $%02X", story_o, color_i);
			$stop;
		end

		// The shift register should support 8bpp shifts.
		story_o <= 16'h0400;
		load_o <= 1;
		shift1_o <= 0;
		shift2_o <= 0;
		shift4_o <= 0;
		shift8_o <= 1;
		dat_o <= 16'h1234;
		wait(clk_o); wait(~clk_o);
		load_o <= 0;
		shift1_o <= 0;
		shift2_o <= 0;
		shift4_o <= 0;
		shift8_o <= 1;
		wait(clk_o); wait(~clk_o);
		if(color_i !== 8'b00110100) begin
			$display("@E %04X Expected $34; got $%02X", story_o, color_i);
			$stop;
		end

		// The index XOR input should affect the resulting color index.
		story_o <= 16'h0500;
		index_xor_o <= 8'b11110000;
		load_o <= 1;
		shift1_o <= 0;
		shift2_o <= 0;
		shift4_o <= 0;
		shift8_o <= 1;
		dat_o <= 16'h1234;
		wait(clk_o); wait(~clk_o);
		if(color_i !== 8'b11100010) begin
			$display("@E %04X Expected $E2; got $%02X", story_o, color_i);
			$stop;
		end

		#100 $display("@I OK");
		$stop;
	end
endmodule
