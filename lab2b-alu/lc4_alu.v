/* INSERT NAME AND PENNKEY HERE */

`timescale 1ns / 1ps

`default_nettype none


module lc4_alu_arith(   input wire [15:0] A,
                        input wire [15:0] B,
                        input wire [2:0] alu_ctl,
                        output wire [15:0] out);
      wire cla_cin;
      wire [15:0] cla_B_input;
      assign cla_cin = (alu_ctl == 3'd2) ? 1'b1 : 1'b0;
      assign cla_B_input = (alu_ctl == 3'd2) ? ~B:
                           (alu_ctl == 3'd5) ? { {11{B[4]}}, B[4:0] }:
                           (alu_ctl == 3'd6) ? { {10{B[5]}}, B[5:0] }:
                           B;
      
      wire [15:0] quotient, remainder, cla_output;
      lc4_divider div (
            .i_dividend(A),
            .i_divisor(B),
            .o_remainder(remainder),
            .o_quotient(quotient)
      );
      cla16 cla (
            .a(A),
            .b(B),
            .cin(cla_cin),
            .sum(cla_output)
      );
      assign out = (alu_ctl == 3'd1) ? A * B:
                   (alu_ctl == 3'd3) ? quotient:
                   (alu_ctl == 3'd4) ? remainder:
                   cla_output;
endmodule


module lc4_alu_logic(   input wire [15:0] A,
                        input wire [15:0] B,
                        input wire [2:0] alu_ctl,
                        output wire [15:0] out);
      assign out = (alu_ctl == 3'd0) ? A & B:
                   (alu_ctl == 3'd1) ? ~ A:
                   (alu_ctl == 3'd2) ? A | B:
                   (alu_ctl == 3'd3) ? A ^ B:
                   A & { {11{B[4]}}, B[4:0] };
endmodule

module lc4_alu_compare( input wire [15:0] A,
                        input wire [15:0] B,
                        input wire [2:0] alu_ctl,
                        output wire [15:0] out);
      wire [15:0] sext_B6, res0, res1, res2, res3;
      assign sext_B6 = { {9{B[6]}}, B[6:0]};

      assign res0 = ($signed(A) < $signed(B)) ? {16{1'b1}}:
                    ($signed(A) == $signed(B)) ? 16'd0 : 16'd1;

      assign res1 = (A < B) ? {16{1'b1}}:
                    (A == B) ? 16'd0 : 16'd1;

      assign res2 = ($signed(A) < $signed(sext_B6)) ? {16{1'b1}}:
                    ($signed(A) == $signed(sext_B6)) ? 16'd0 : 16'd1;

      assign res3 = (A < sext_B6) ? {16{1'b1}}:
                    (A == sext_B6) ? 16'd0 : 16'd1;
      
      assign out = (alu_ctl == 3'd0) ? res0:              //signed all
                   (alu_ctl == 3'd1) ? res1:              //unsigned all
                   (alu_ctl == 3'd2) ? res2:              //signed sext_B6
                   res3;                                  // unsigned sext_B6
endmodule


module lc4_alu_shifter( input wire [15:0] A,
                        input wire [15:0] B,
                        input wire [2:0] alu_ctl,
                        output wire [15:0] out);
      assign out = (alu_ctl == 3'd0) ? A << B:
                   (alu_ctl == 3'd1) ? A >>> B:
                   A >> B;
endmodule


module lc4_alu_const(   input wire [15:0] A,
                        input wire [15:0] B,
                        input wire [2:0] alu_ctl,
                        output wire [15:0] out);
      wire [15:0] const, hiconst;
      assign const = { {7{B[8]}}, B[8:0] };
      assign hiconst = (A & 16'hFF) | (B << 8);
      assign out = (alu_ctl == 3'd0) ? const : hiconst;
endmodule



module lc4_alu(input  wire [15:0] i_insn,
               input wire [15:0]  i_pc,
               input wire [15:0]  i_r1data,
               input wire [15:0]  i_r2data,
               output wire [15:0] o_result);
      
      wire [15:0] arith_out, logic_out, compare_out, shifter_out, const_out;
      wire [5:0] alu_ctl; // need to make a decoder to get this

      lc4_alu_arith arith(
            .A(i_r1data),
            .B(i_r2data),
            .alu_ctl(alu_ctl[2:0]),
            .out(arith_out)
      );
      lc4_alu_logic logic(
            .A(i_r1data),
            .B(i_r2data),
            .alu_ctl(alu_ctl[2:0]),
            .out(arith_out)
      );
      lc4_alu_compare compare(
            .A(i_r1data),
            .B(i_r2data),
            .alu_ctl(alu_ctl[2:0]),
            .out(arith_out)
      );
      lc4_alu_shifter shift(
            .A(i_r1data),
            .B(i_r2data),
            .alu_ctl(alu_ctl[2:0]),
            .out(arith_out)
      );
      lc4_alu_const const(
            .A(i_r1data),
            .B(i_r2data),
            .alu_ctl(alu_ctl[2:0]),
            .out(arith_out)
      );
      //assign o_result = (alu_ctl[5:3] == )

      

      /*** YOUR CODE HERE ***/

endmodule