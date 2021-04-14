`timescale 1ns / 1ps
`default_nettype none

module lc4_divider(input  wire [15:0] i_dividend,
                   input  wire [15:0] i_divisor,
                   output wire [15:0] o_remainder,
                   output wire [15:0] o_quotient);

      /*** Student code starts ***/
      // first slice gives the specific bits, second slice gives which wire in the bus
      wire [15:0] remainder_outputs[15:0];
      wire [15:0] dividend_outputs[15:0];
      wire [15:0] quotient_outputs[15:0];


      lc4_divider_one_iter step_one(.i_dividend(i_dividend), 
                                    .i_divisor(i_divisor),
                                    .i_remainder(16'b0), 
                                    .i_quotient(16'b0),
                                    .o_dividend(dividend_outputs[0]),
                                    .o_remainder(remainder_outputs[0]),
                                    .o_quotient(quotient_outputs[0]));
      
      
      // creates linked div_iters
      genvar i;
      for (i = 1; i < 16; i = i+1) begin
            lc4_divider_one_iter temp (.i_dividend(dividend_outputs[i-1]), 
                                    .i_divisor(i_divisor),
                                    .i_remainder(remainder_outputs[i-1]),
                                    .i_quotient(quotient_outputs[i-1]),
                                    .o_dividend(dividend_outputs[i]), 
                                    .o_remainder(remainder_outputs[i]),
                                    .o_quotient(quotient_outputs[i]));
      end

      assign o_quotient = quotient_outputs[15];
      assign o_remainder = remainder_outputs[15];
      /*** Student code ends ***/
endmodule // lc4_divider


module lc4_divider_one_iter(input  wire [15:0] i_dividend,
                            input  wire [15:0] i_divisor,
                            input  wire [15:0] i_remainder,
                            input  wire [15:0] i_quotient,
                            output wire [15:0] o_dividend,
                            output wire [15:0] o_remainder,
                            output wire [15:0] o_quotient);

      /*** Student code starts ***/
      assign o_dividend = i_dividend << 1;

      wire [15:0] new_remainder, rem_minus_div;
      assign new_remainder = (i_remainder << 1) | ((i_dividend >> 15) & 16'b1);
      assign rem_minus_div = new_remainder - i_divisor;
      assign o_remainder = i_divisor ? 
           ((new_remainder < i_divisor) ? new_remainder : rem_minus_div) : 0;

      wire [15:0] q1, q2;
      assign q1 = i_quotient << 1;
      assign q2 = q1 | 16'b1;
      assign o_quotient = i_divisor ?
          ((new_remainder < i_divisor) ? q1 : q2) : 0;
      /*** Student code ends ***/
endmodule