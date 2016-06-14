`timescale 1ns / 1ps

//
// This test script exercises the CGIA's line buffers.
//

module test_line_buffers();
	reg [15:0] story_o;	// Holds grep tag for failing test cases.

	reg clk_o;		// Wishbone SYSCON clock
	reg odd_o;
	reg [8:0] f_adr_o;
	reg [8:0] s_adr_o;
	reg [15:0] s_dat_o;
	reg s_we_o;

	wire [15:0] f_dat_i;

	// Core Under Test
	line_buffers lb(
		.CLK_I(clk_o),
		.ODD_I(odd_o),

		.F_ADR_I(f_adr_o),
		.F_DAT_O(f_dat_i),

		.S_ADR_I(s_adr_o),
		.S_DAT_I(s_dat_o),
		.S_WE_I(s_we_o)
	);

	// 25MHz clock (1/25MHz = 40ns)
	always begin
		#40 clk_o <= ~clk_o;
	end

	// Test script starts here.
	initial begin
		clk_o <= 0;

		// Data writes to even and odd buffers.
		story_o <= 16'h0000;
		odd_o <= 0;
		s_adr_o <= 0;
		f_adr_o <= 0;
		s_dat_o <= 16'hAAAA;
		s_we_o <= 1;
		wait(clk_o); wait(~clk_o);
		odd_o <= 1;
		s_dat_o <= 16'h5555;
		wait(clk_o); wait(~clk_o);
		odd_o <= 0;
		wait(clk_o);
		if(f_dat_i !== 16'hAAAA) begin
			$display("@E %04X Expected to read $AAAA; got $%04X", story_o, f_dat_i);
			$stop;
		end
		wait(~clk_o);
		odd_o <= 1;
		wait(clk_o);
		if(f_dat_i !== 16'h5555) begin
			$display("@E %04X Expected to read $5555; got $%04X", story_o, f_dat_i);
			$stop;
		end
		wait(~clk_o);

		#100 $display("@I OK");
		$stop;
	end
endmodule
