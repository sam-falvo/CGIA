`timescale 1ns / 1ps

//
// This test script exercises the CGIA's configurable shift register for
// pushing pixels out to the color pen bus.  The shift register should be
// able to move pixels 1, 2, 4, or 8 bits at a time.
//

module test_shift_register();
	reg [15:0] story_o;	// Holds grep tag for failing test cases.
	reg clk_o;		// Dot clock
	reg load_o;		// 1 if we need to reload register.
	reg shift1_o;		// 1 if we are in 1bpp mode.
	reg shift2_o;		// 1 if we are in 2bpp mode.
	reg shift4_o;		// 1 if we are in 4bpp mode.
	reg shift8_o;		// 1 if we are in 8bpp mode.
	reg [15:0] dat_o;	// Data to load register with.

	wire [15:0] dat_i;	// Current shift register value.

	// Core Under Test
	shift_register sr(
		.dotclk_i(clk_o),
		.dat_o(dat_i),
		.dat_i(dat_o),
		.load_i(load_o),
		.shift1_i(shift1_o),
		.shift2_i(shift2_o),
		.shift4_i(shift4_o),
		.shift8_i(shift8_o)
	);

	// 25MHz clock (1/25MHz = 40ns)
	always begin
		#40 clk_o <= ~clk_o;
	end

	// Test script starts here.
	initial begin
		clk_o <= 0;

		// The shift register should be loadable at any time.
		story_o <= 16'h0000;
		load_o <= 1;
		shift1_o <= 0;
		shift2_o <= 0;
		shift4_o <= 0;
		shift8_o <= 0;
		dat_o <= 16'h1234;
		wait(clk_o); wait(~clk_o);
		if(dat_i !== 16'b0001001000110100) begin
			$display("@E %04X Expected $1234; got $%04X", story_o, dat_i);
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
		if(dat_i !== 16'b0010010001101000) begin
			$display("@E %04X Expected $2468; got $%04X", story_o, dat_i);
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
		if(dat_i !== 16'b1001000110100000) begin
			$display("@E %04X Expected $91A0; got $%04X", story_o, dat_i);
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
		if(dat_i !== 16'b0001101000000000) begin
			$display("@E %04X Expected $1A00; got $%04X", story_o, dat_i);
			$stop;
		end

		// The shift register should support 8bpp shifts.
		story_o <= 16'h0400;
		load_o <= 1;
		shift1_o <= 0;
		shift2_o <= 0;
		shift4_o <= 0;
		shift8_o <= 0;
		dat_o <= 16'h1234;
		wait(clk_o); wait(~clk_o);
		load_o <= 0;
		shift1_o <= 0;
		shift2_o <= 0;
		shift4_o <= 0;
		shift8_o <= 1;
		wait(clk_o); wait(~clk_o);
		if(dat_i !== 16'b0011010000000000) begin
			$display("@E %04X Expected $3400; got $%04X", story_o, dat_i);
			$stop;
		end

		#100 $display("@I OK");
		$stop;
	end
endmodule
