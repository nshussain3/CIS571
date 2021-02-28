/* INSERT NAME AND PENNKEY HERE */
// Spencer Solit - ssolit
// Neehal Hussain - 

`timescale 1ns / 1ps

`default_nettype none

module lc4_decoder(     input wire [15:0] i_insn,
                        output wire [5:0] alu_ctl);
      assign alu_ctl[5:3] = ((i_insn[15:12] == 4'd1)
                  ||  (i_insn[15:12] == 4'd6)
                  ||  (i_insn[15:12] == 4'd0)
                  ||  (i_insn[15:12] == 4'd7)
                  ||  (i_insn[15:11] == 5'd25)
                  ||  ((i_insn[15:12] == 4'd10) && (i_insn[5:4] == 2'd3))) ? 3'd0: // arith ops
                  (i_insn[15:12] == 4'd5) ? 3'd1: // logic ops
                  (i_insn[15:12] == 4'd2) ? 3'd2: // comp ops
                  ((i_insn[15:12] == 4'd10) && (i_insn[5:4] < 2'd3)) ? 3'd3: // shifter ops
                  ((i_insn[15:12] == 4'd9) 
                  ||   (i_insn[15:12] == 4'd13)) ? 3'd4: // const ops
                  ((i_insn[15:12] == 4'd4)
                  ||   (i_insn[15:11] == 5'd24) || (i_insn[15:12] == 4'd15)
                  ||   (i_insn[15:12] == 4'd8)) ? 3'd5: // jsrr, jsr, jmpr, trap, rti ops
                   3'd6; // trap, rti ops

            // jsrr, jmpr, rti subopcode 0
            // jsr subopcode 1, trap 2
      assign alu_ctl[2:0] =
            (((i_insn[15:12] == 4'd1) && (i_insn[5] == 0)) ||
                  ((i_insn[15:12] == 4'd5) && (i_insn[5] == 0))) ? i_insn[5:3] :
            ((i_insn[15:12] == 4'd1) && (i_insn[5] == 1)) ? 3'b101 :
            (((i_insn[15:12] == 4'd10) && (i_insn[5:4] == 2'd3)) ||
                  ((i_insn[15:12] == 4'd5) && (i_insn[5] == 1))) ? 3'b100 :
            (i_insn[15:13] == 3'd3) ? 3'b110 :
            (i_insn[15:12] == 4'd2) ? {1'b0, i_insn[8:7]} :
            ((i_insn[15:12] == 4'd10) && (i_insn[5:4] < 2'd3)) ? {1'b0, i_insn[5:4]} :
            ((i_insn[15:12] == 4'd9) || (i_insn[15:12] == 4'd8) || 
                 (i_insn[15:11] == 5'd8) || (i_insn[15:11] == 5'd24)) ? 3'b000 :
            ((i_insn[15:12] == 4'd13) || (i_insn[15:11] == 5'd9)) ? 3'b001 :
            ((i_insn[15:11] == 5'd25) || (i_insn[15:12] == 4'd0)) ? 3'b111 :
            (i_insn[15:12] == 4'd15) ? 3'b010:
            3'b000;
endmodule

module lc4_alu_arith(   input wire [15:0] A,
                        input wire [15:0] B,
                        input wire [2:0] alu_ctl,
                        input wire [15:0] insn,
                        input wire [15:0] pc,
                        output wire [15:0] out);
      wire cla_cin;
      wire [15:0] cla_A_input, cla_B_input;
      assign cla_cin = (alu_ctl[2:0] == 3'd2 || alu_ctl[2:0] == 3'd7) ? 1'b1 : 1'b0;
      assign cla_A_input = (alu_ctl[2:0] == 3'd7) ? pc : A;
      assign cla_B_input = (alu_ctl[2:0] == 3'd2) ? ~B:
                           (alu_ctl[2:0] == 3'd5) ? { {11{insn[4]}}, insn[4:0] }:
                           (alu_ctl[2:0] == 3'd6) ? { {10{insn[5]}}, insn[5:0] }:
                           (alu_ctl[2:0] == 3'd7) ? { {5{insn[10]}}, insn[10:0] }:
                           B;
      wire [15:0] branch_or_b;
      assign branch_or_b = (insn[15:12] == 4'd0) ? {{7{insn[8]}}, insn[8:0]} : cla_B_input;

      wire [15:0] quotient, remainder, cla_output;
      lc4_divider div (
            .i_dividend(A),
            .i_divisor(B),
            .o_remainder(remainder),
            .o_quotient(quotient)
      );
      cla16 cla (
            .a(cla_A_input),
            .b(branch_or_b),
            .cin(cla_cin),
            .sum(cla_output)
      );
      assign out = (alu_ctl[2:0] == 3'd1) ? A * B:
                   (alu_ctl[2:0] == 3'd3) ? quotient:
                   (alu_ctl[2:0] == 3'd4) ? remainder:
                   cla_output;
endmodule


module lc4_alu_logic(   input wire [15:0] A,
                        input wire [15:0] B,
                        input wire [15:0] insn,
                        input wire [2:0] alu_ctl,
                        output wire [15:0] out);
      assign out = (alu_ctl[2:0] == 3'd0) ? A & B:
                   (alu_ctl[2:0] == 3'd1) ? ~ A:
                   (alu_ctl[2:0] == 3'd2) ? A | B:
                   (alu_ctl[2:0] == 3'd3) ? A ^ B:
                   A & { {11{insn[4]}}, insn[4:0] };
endmodule

module lc4_alu_compare( input wire [15:0] A,
                        input wire [15:0] B,
                        input wire [2:0] alu_ctl,
                        input wire [15:0] insn,
                        output wire [15:0] out);
      wire [15:0] sext_B6, uext_B6, res0, res1, res2, res3;
      assign sext_B6 = { {9{insn[6]}}, insn[6:0]};
      assign uext_B6 = { {9{1'b0}}, insn[6:0]};
      

      assign res0 = ($signed(A) < $signed(B)) ? {16{1'b1}}:
                    ($signed(A) == $signed(B)) ? 16'd0 : 16'd1;

      assign res1 = (A < B) ? {16{1'b1}}:
                    (A == B) ? 16'd0 : 16'd1;

      assign res2 = ($signed(A) < $signed(sext_B6)) ? {16{1'b1}}:
                    ($signed(A) == $signed(sext_B6)) ? 16'd0 : 16'd1;

      assign res3 = (A < uext_B6) ? {16{1'b1}}:
                    (A == uext_B6) ? 16'd0 : 16'd1;
      
      assign out = (alu_ctl[2:0] == 3'd0) ? res0:              //signed all
                   (alu_ctl[2:0] == 3'd1) ? res1:              //unsigned all
                   (alu_ctl[2:0] == 3'd2) ? res2:              //signed sext_B6
                   res3;                                  // unsigned sext_B6
endmodule


module lc4_alu_shifter( input wire signed [15:0] A,
                        input wire [15:0] B,
                        input wire [2:0] alu_ctl,
                        output wire signed [15:0] out);
      assign out = (alu_ctl[2:0] == 3'd0) ? A << B[3:0]:
                   (alu_ctl[2:0] == 3'd1) ? A >>> B[3:0]:
                   A >> B[3:0];
endmodule


module lc4_alu_const(   input wire [15:0] A,
                        input wire [15:0] B,
                        input wire [2:0] alu_ctl,
                        output wire [15:0] out);
      wire [15:0] const, hiconst;
      assign const = { {7{B[8]}}, B[8:0] };
      assign hiconst = (A & 16'hFF) | (B << 8);
      assign out = (alu_ctl[2:0] == 3'd0) ? const : hiconst;
endmodule

module lc4_alu_jump(    input wire [15:0] i_r1data,
                        input wire [15:0] i_pc, i_insn,
                        input wire [2:0] alu_ctl,
                        output wire [15:0] out);
      wire [15:0] jsrr, jsr, trap;                    
      assign jsrr = i_r1data;                                           // also for jmpr, rti
      assign jsr = (i_pc & 16'h8000) | {1'b0, i_insn[10:0], {4{1'b0}}};  
      assign trap = 16'h8000 | {{8{1'b0}}, i_insn[7:0]};
      assign out = (alu_ctl == 3'd0) ? jsrr:
                   (alu_ctl == 3'd1) ? jsr:
                   trap;
endmodule



module lc4_alu(input  wire [15:0] i_insn,
               input wire [15:0]  i_pc,
               input wire [15:0]  i_r1data,
               input wire [15:0]  i_r2data,
               output wire [15:0] o_result);
      
      wire [15:0] arith_out, logic_out, compare_out, shifter_out, const_out, jump_out;
      wire [5:0] alu_ctl; // need to make a decoder to get this
      

      lc4_decoder decoder(
            .i_insn(i_insn),
            .alu_ctl(alu_ctl[5:0])
      );

      
      lc4_alu_arith arith(
            .A(i_r1data),
            .B(i_r2data),
            .pc(i_pc),
            .insn(i_insn),
            .alu_ctl(alu_ctl[2:0]),
            .out(arith_out)
      );
      lc4_alu_logic logic(
            .A(i_r1data),
            .B(i_r2data),
            .insn(i_insn),
            .alu_ctl(alu_ctl[2:0]),
            .out(logic_out)
      );
      lc4_alu_compare compare(
            .A(i_r1data),
            .B(i_r2data),
            .insn(i_insn),
            .alu_ctl(alu_ctl[2:0]),
            .out(compare_out)
      );
      lc4_alu_shifter shift(
            .A(i_r1data),
            .B(i_insn),
            .alu_ctl(alu_ctl[2:0]),
            .out(shifter_out)
      );
      lc4_alu_const const(
            .A(i_r1data),
            .B(i_insn),
            .alu_ctl(alu_ctl[2:0]),
            .out(const_out)
      );
      lc4_alu_jump jump(
            .i_r1data(i_r1data),
            .i_pc(i_pc),
            .i_insn(i_insn),
            .alu_ctl(alu_ctl[2:0]),
            .out(jump_out)
      );
      assign o_result = (alu_ctl[5:3] == 3'd0) ? arith_out:
                        (alu_ctl[5:3] == 3'd1) ? logic_out:
                        (alu_ctl[5:3] == 3'd2) ? compare_out:
                        (alu_ctl[5:3] == 3'd3) ? shifter_out:
                        (alu_ctl[5:3] == 3'd4) ? const_out:
                        jump_out;
      

      /*** YOUR CODE HERE ***/

endmodule

module gp2 (input wire [1:0] gin, pin,
            input wire cin,
            output wire gout, pout, cout);
  assign cout = gin[0] | (pin[0] & cin);
  assign pout = (pin[0] & pin[1]);
  assign gout = (gin[0] & pin[1]) | gin[1];
endmodule


module gp4(input wire [3:0] gin, pin,
           input wire cin,
           output wire gout, pout,
           output wire [2:0] cout);
  wire[1:0] gmid;
  wire[1:0] pmid;
  gp2 bits1to0 (.gin(gin[1:0]), .pin(pin[1:0]),
                .cin(cin),
                .gout(gmid[0]), .pout(pmid[0]),
                .cout(cout[0]));

  gp2 bits3to2 (.gin(gin[3:2]), .pin(pin[3:2]),
                .cin(cout[1]),
                .gout(gmid[1]), .pout(pmid[1]),
                .cout(cout[2]));
  
  gp2 bits3to0 (.gin(gmid[1:0]), .pin(pmid[1:0]),
                .cin(cin),
                .gout(gout), .pout(pout),
                .cout(cout[1]));

endmodule

/**
 * 16-bit Carry-Lookahead Adder
 * @param a first input
 * @param b second input
 * @param cin carry in
 * @param sum sum of a + b + carry-in
 */
module cla16
  (input wire [15:0]  a, b,
   input wire         cin,
   output wire [15:0] sum);
  // determine bitwise gp pairs
  wire [15:0] g, p, cout;
  wire [3:0] gfour, pfour;
  wire g16, p16;
  assign cout[0] = cin;
  genvar i;
  for (i = 0; i < 16; i = i+1) begin
    gp1 s(.a(a[i]), .b(b[i]), .g(g[i]), .p(p[i]));
  end
  // four-bit gp aggregates
  for (i = 0; i < 4; i = i+1) begin
    gp4 f(.gin(g[4*i+3:4*i]), .pin(p[4*i+3:4*i]), .cin(cout[4*i]),
          .gout(gfour[i]), .pout(pfour[i]), .cout(cout[4*i+3:4*i+1]));
  end
  /* aggregate each four-bit gp to get 16-bit gp (no need to use g16-0 or p16-0)
     because we are not computing carry out
  */
  gp4 reduce(.gin(gfour), .pin(pfour), .cin(cin),
             .gout(g16), .pout(p16), .cout({cout[12], cout[8], cout[4]}));

  for (i = 0; i < 16; i = i+1) begin
    assign sum[i] = a[i] ^ b[i] ^ cout[i];
  end

endmodule