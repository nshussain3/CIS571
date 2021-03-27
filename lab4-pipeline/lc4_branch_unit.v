module lc4_branch_unit(input  wire clk,
                   input  wire rst,                
                   input  wire gwe,    

                   input wire [15:0] bu_pc_plus_one,
                   input wire [15:0] bu_select_result,
                   input wire nzp_we,
                   input wire is_branch,
                   input wire is_control,
                   input wire [15:0] insn,
                   output wire [15:0] bu_next_pc,
                   output wire [2:0] test_nzp_new_bits,
                   input wire [15:0] bu_alu_output);
   wire bu_nzp_passed, bu_nzp_reduced, bu_branch_output_sel;
   wire [2:0] bu_select_result_sign, bu_nzp_bus, bu_nzp_and;
   
   assign bu_select_result_sign = ($signed(bu_select_result) > 0) ? 3'b001:
                                  (bu_select_result == 0) ? 3'b010: 3'b100;


   Nbit_reg nzp_reg (
      .in(bu_select_result_sign), 
      .out(bu_nzp_bus),
      .clk(clk),
      .we(nzp_we),
      .gwe(gwe),
      .rst(rst)
      );
   defparam nzp_reg.n = 3;


   wire [15:0] temp_bu_next_pc ;

   assign bu_nzp_and = bu_nzp_bus & insn[11:9];
   assign bu_nzp_reduced = |bu_nzp_and;
   assign bu_nzp_passed = bu_nzp_reduced & is_branch;
   assign temp_bu_next_pc = (bu_nzp_passed == 1) ? bu_select_result : bu_pc_plus_one;
   assign bu_next_pc = (is_control == 1) ? bu_alu_output : temp_bu_next_pc;
   
   assign test_nzp_new_bits = bu_select_result_sign;
endmodule