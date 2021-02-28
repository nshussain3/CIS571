/* TODO: Names of all group members
 * TODO: PennKeys of all group members
 *
 * lc4_regfile.v
 * Implements an 8-register register file parameterized on word size.
 *
 */

`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

module lc4_regfile #(parameter n = 16)
   (input  wire         clk,
    input  wire         gwe,
    input  wire         rst,
    input  wire [  2:0] i_rs,      // rs selector
    output wire [n-1:0] o_rs_data, // rs contents
    input  wire [  2:0] i_rt,      // rt selector
    output wire [n-1:0] o_rt_data, // rt contents
    input  wire [  2:0] i_rd,      // rd selector
    input  wire [n-1:0] i_wdata,   // data to write
    input  wire         i_rd_we    // write enable
    );

   /***********************
    * TODO YOUR CODE HERE *
    ***********************/
    wire [7:0] reg_one_hot, reg_we_bus;
    wire [n-1:0] reg_out_bus [7:0];
    genvar i;
    for (i = 0; i < 8; i = i + 1) begin
        assign reg_one_hot[i] = (i_rd == i) ? 1'b1 : 1'b0;
        assign reg_we_bus[i] = reg_one_hot[i] & i_rd_we;
        Nbit_reg reg_i (
            .in(i_wdata), 
            .out(reg_out_bus[i]),
            .clk(clk),
            .we(reg_we_bus[i]),
            .gwe(gwe),
            .rst(rst)
        );
        defparam reg_i.n = 16;
    end

    assign o_rs_data = (i_rs == 3'd0) ? reg_out_bus[0] :
                (i_rs == 3'd1) ? reg_out_bus[1] :
                (i_rs == 3'd2) ? reg_out_bus[2] :
                (i_rs == 3'd3) ? reg_out_bus[3] :
                (i_rs == 3'd4) ? reg_out_bus[4] :
                (i_rs == 3'd5) ? reg_out_bus[5] :
                (i_rs == 3'd6) ? reg_out_bus[6] :
                reg_out_bus[7];
    
    assign o_rt_data = (i_rt == 3'd0) ? reg_out_bus[0] : 
                (i_rt == 3'd1) ? reg_out_bus[1] : 
                (i_rt == 3'd2) ? reg_out_bus[2] : 
                (i_rt == 3'd3) ? reg_out_bus[3] : 
                (i_rt == 3'd4) ? reg_out_bus[4] : 
                (i_rt == 3'd5) ? reg_out_bus[5] : 
                (i_rt == 3'd6) ? reg_out_bus[6] : 
                reg_out_bus[7];
endmodule
