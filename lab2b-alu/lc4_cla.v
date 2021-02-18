/* TODO: INSERT NAME AND PENNKEY HERE */

/**
 * @param a first 1-bit input
 * @param b second 1-bit input
 * @param g whether a and b generate a carry
 * @param p whether a and b would propagate an incoming carry
 */
module gp1(input wire a, b,
           output wire g, p);
   assign g = a & b;
   assign p = a | b;
endmodule

/**
 * Computes aggregate generate/propagate signals over a 4-bit window.
 * @param gin incoming generate signals 
 * @param pin incoming propagate signals
 * @param cin the incoming carry
 * @param gout whether these 4 bits collectively generate a carry (ignoring cin)
 * @param pout whether these 4 bits collectively would propagate an incoming carry (ignoring cin)
 * @param cout the carry outs for the low-order 3 bits
 */

module gp2 (input wire [1:0] gin, pin,
            input wire cin,
            output wire gout, pout, cout);
  assign cout = gin[0] | (pin[0] & cin);
  assign pout = (& pin[1:0]);
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
  
  gp2 bits3to0 (.gin(gmid[1:0]), .pin(gmid[1:0]),
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
  for (i = 0; i < 4; i = i+4) begin
    gp4 f(.gin(g[i:i+3]), .pin(p[i:i+3]), .cin(cout[i]),
          .gout(gfour[i]), .pout(pfour[i]) .cout(cout[i+1:i+3]));
  end
  /* aggregate each four-bit gp to get 16-bit gp (no need to use g16-0 or p16-0)
     because we are not computing carry out
  */
  gp4 reduce(.gin(gfour), .pin(pfour), .cin(cin),
             .gout(g16), .pout(p16), .cout({cout[12], cout[8], cout[4]}));

  for (i = 0; i < 16; i = i+1) begin
    sum[i] = a[i] ^ b[i] ^ cout[i];
  end

endmodule


/** Lab 2 Extra Credit, see details at
  https://github.com/upenn-acg/cis501/blob/master/lab2-alu/lab2-cla.md#extra-credit
 If you are not doing the extra credit, you should leave this module empty.
 */
module gpn
  #(parameter N = 4)
  (input wire [N-1:0] gin, pin,
   input wire  cin,
   output wire gout, pout,
   output wire [N-2:0] cout);
 
endmodule
