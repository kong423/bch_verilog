`timescale 1ns / 1ps

/* Bit-serial Berlekamp (dual basis) multiplier */
module dsdbm #(
	parameter M = 4
) (
	input [M-1:0] dual_in,
	input [M-1:0] standard_in,
	output out
);
	assign out = ^(standard_in & dual_in);
endmodule

/* Bit-serial Berlekamp dual-basis multiplier LFSR */
module dsdbmRing #(
	parameter M = 4
) (
	input clk,
	input pe,
	input [M-1:0] dual_in,
	output reg [M-1:0] dual_out = 0
);
	`include "bch.vh"

	localparam TCQ = 1;

	always @(posedge clk) begin
		if (pe)
			dual_out <= #TCQ dual_in;
		else
			dual_out <= #TCQ {^(dual_out & bch_polynomial(M)), dual_out[M-1:1]};
	end
endmodule

/* Bit-parallel dual-basis multiplier */
module dpdbm #(
	parameter M = 4
) (
	input [M-1:0] dual_in,
	input [M-1:0] standard_in,
	output [M-1:0] out
);
	`include "bch.vh"

	wire [M-2:0] aux;
	wire [M-1:0] aux_mask = (bch_polynomial(M) & {{M-1{1'b1}}, 1'b0});
	wire [M*2-2:0] all;
	genvar i;

	assign all = {aux, dual_in};

	for (i = 0; i < M - 1; i = i + 1)
		assign aux[i] = dual_in[i] ^ ^({aux, dual_in} & (aux_mask << i));

	generate
		for (i = 0; i < M; i = i + 1) begin : MN
			dsdbm #(M) u_dsdbm(all[i+:M], standard_in, out[i]);
		end
	endgenerate
endmodule

/* Bit-serial standard basis multiplier */
module dssbm #(
	parameter M = 4
) (
	input clk,
	input run,
	input start,
	input [M-1:0] in,
	output reg [M-1:0] out = 0
);
	`include "bch.vh"

	localparam TCQ = 1;

	always @(posedge clk) begin
		if (start)
			out <= #TCQ in;
		else if (run)
			out <= in ^ {out[M-2:0], 1'b0} ^ (bch_polynomial(M) & {M{out[M-1]}});
	end
endmodule

module dmli #(
	parameter M = 4
) (
	input [M-1:0] in,
	output [M-1:0] out
);
	`include "bch.vh"

	/*
	 * Only for trinomials, multiply by L^P, where P in the middle
	 * exponent, in x^5 + x^2 + 1, P == 2.
	 */
	function integer mli_terms;
		input [31:0] m;
		input [31:0] bit_pos;
		integer i;
		integer j;
		integer poly;
		integer pos;
		integer b;
	begin
		mli_terms = 0;
		poly = bch_rev(m, bch_polynomial(m));
		pos = polyi(m);
		for (i = 0; i < m; i = i + 1) begin
			b = 1 << (m - 1 - i);
			for (j = 0; j < pos; j = j + 1)
				b = (b << 1) | ((b & poly) ? 1'b1 : 1'b0);
			mli_terms = mli_terms | (((b >> (m - 1 - bit_pos)) & 1) << i);
		end

	end
	endfunction

	genvar i;
	for (i = 0; i < M; i = i + 1)
		assign out[i] = ^(in & mli_terms(M, i));
endmodule

module dsq #(
	parameter M = 4
) (
	input [M-1:0] in,
	output [M-1:0] out
);
	`include "bch.vh"

	function integer sq_terms;
		input [31:0] m;
		input [31:0] bit_pos;
		integer i;
	begin
		sq_terms = 0;
		for (i = 0; i < m; i = i + 1)
			sq_terms = sq_terms | (((lpow(m, i * 2) >> (m - 1 - bit_pos)) & 1) << i);
	end
	endfunction

	genvar i;
	for (i = 0; i < M; i = i + 1)
		assign out[i] = ^(in & sq_terms(M, i));
endmodule

/* Finite field inversion */
module dinv #(
	parameter M = 4
) (
	input clk,
	input cbBeg,
	input bsel,
	input caLast,
	input cce,
	input drnzero,
	input snce,
	input synpe,
	input [M-1:0] in,
	output reg [M-1:0] out
);
	`include "bch.vh"

	localparam TCQ = 1;

	wire [M-1:0] msin;
	reg [M-1:0] mdin = standard_to_dual(M, 1);
	wire [M-1:0] sq;
	reg [M-1:0] qsq = 0;

	wire ce1;
	wire ce2;
	wire reset;
	wire ce2a = drnzero && cbBeg;
	wire ce2b = bsel || ce2a;
	wire sel = caLast || synpe;

	assign ce1 = ce2 || caLast || synpe;
	assign ce2 = cce && !snce && (bsel || (drnzero && cbBeg));
	assign reset = (snce && bsel) || synpe;

	assign msin = (caLast || synpe) ? in : qsq;
	dsq #(M) u_dsq(msin, sq);
	dpdbm #(M) u_dpdbm(
		.dual_in(mdin),
		.standard_in(msin),
		.out(out)
	);

	always @(posedge clk) begin
		if (ce1)
			qsq <= #TCQ sq;

		if (reset)
			mdin <= #TCQ standard_to_dual(M, 1);
		else if (ce2)
			mdin <= #TCQ out;
	end

endmodule