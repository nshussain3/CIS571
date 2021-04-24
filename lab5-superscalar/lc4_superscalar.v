`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

module lc4_processor(input wire         clk,             // main clock
                     input wire         rst,             // global reset
                     input wire         gwe,             // global we for single-step clock

                     output wire [15:0] o_cur_pc,        // address to read from instruction memory
                     input wire [15:0]  i_cur_insn_A,    // output of instruction memory (pipe A)
                     input wire [15:0]  i_cur_insn_B,    // output of instruction memory (pipe B)

                     output wire [15:0] o_dmem_addr,     // address to read/write from/to data memory
                     input wire [15:0]  i_cur_dmem_data, // contents of o_dmem_addr
                     output wire        o_dmem_we,       // data memory write enable
                     output wire [15:0] o_dmem_towrite,  // data to write to o_dmem_addr if we is set

                     // testbench signals (always emitted from the WB stage)
                     output wire [ 1:0] test_stall_A,        // is this a stall cycle?  (0: no stall,
                     output wire [ 1:0] test_stall_B,        // 1: pipeline stall, 2: branch stall, 3: load stall)

                     output wire [15:0] test_cur_pc_A,       // program counter
                     output wire [15:0] test_cur_pc_B,
                     output wire [15:0] test_cur_insn_A,     // instruction bits
                     output wire [15:0] test_cur_insn_B,
                     output wire        test_regfile_we_A,   // register file write-enable
                     output wire        test_regfile_we_B,
                     output wire [ 2:0] test_regfile_wsel_A, // which register to write
                     output wire [ 2:0] test_regfile_wsel_B,
                     output wire [15:0] test_regfile_data_A, // data to write to register file
                     output wire [15:0] test_regfile_data_B,
                     output wire        test_nzp_we_A,       // nzp register write enable
                     output wire        test_nzp_we_B,
                     output wire [ 2:0] test_nzp_new_bits_A, // new nzp bits
                     output wire [ 2:0] test_nzp_new_bits_B,
                     output wire        test_dmem_we_A,      // data memory write enable
                     output wire        test_dmem_we_B,
                     output wire [15:0] test_dmem_addr_A,    // address to read/write from/to memory
                     output wire [15:0] test_dmem_addr_B,
                     output wire [15:0] test_dmem_data_A,    // data to read/write from/to memory
                     output wire [15:0] test_dmem_data_B,

                     // zedboard switches/display/leds (ignore if you don't want to control these)
                     input  wire [ 7:0] switch_data,         // read on/off status of zedboard's 8 switches
                     output wire [ 7:0] led_data             // set on/off status of zedboard's 8 leds
                     );

   assign led_data = switch_data;
   /* END DO NOT MODIFY THIS CODE */


   /* 
   TO-DO:
   - single memory insn can be in either A or B double check
   - MM BYPASS
   - BRANCHING (SQUASH LOGIC)
   - Load-to-Use must be updated
   - Reread LTU stalling (important note) section
   */




  
   /* STUDENT CODE BEGINS */

   lc4_decoder pipeA_decoder (.r1sel(pipeA_DX_decode_bus[33:31]), 
                                  .r2sel(pipeA_DX_decode_bus[30:28]),
                                  .wsel(pipeA_DX_decode_bus[27:25]),
                                  .r1re(pipeA_DX_decode_bus[24]),
                                  .r2re(pipeA_DX_decode_bus[23]),
                                  .regfile_we(pipeA_DX_decode_bus[22]),
                                  .nzp_we(pipeA_DX_decode_bus[21]), 
                                  .select_pc_plus_one(pipeA_DX_decode_bus[20]),
                                  .is_load(pipeA_DX_decode_bus[19]), 
                                  .is_store(pipeA_DX_decode_bus[18]),
                                  .is_branch(pipeA_DX_decode_bus[17]), 
                                  .is_control_insn(pipeA_DX_decode_bus[16]),
                                  .insn(pipeA_DX_decode_bus[15:0]));

   wire [15:0] pipeA_rsrc1_val, pipeA_rsrc2_val;
   wire [15:0] pipeA_alu_output;
   lc4_alu pipeA_alu (.i_insn(pipeA_XM_decode_bus[15:0]),
                .i_pc(pipeA_X_pc_out),
                .i_r1data(pipeA_AluABypassResult),
                .i_r2data(pipeA_AluBBypassResult),
                .o_result(pipeA_alu_output));

   
   // Pipe_A Pipeswitching logic
   wire[15:0] pipeA_stageD_regPC_in, pipeA_stageD_regIR_in;
   wire[1:0] pipeA_stageD_regStall_in;
   assign pipeA_stageD_regPC_in = (pipeSwitch == 1 && branch_taken == 0) ? pipeB_DX_pc : pipeA_D_pc_in;
   assign pipeA_stageD_regIR_in = (pipeSwitch == 1 && branch_taken == 0) ? pipeB_stageD_IR_reg_out : pipeA_stageD_IR_input;
   assign pipeA_stageD_regStall_in = (pipeSwitch == 1 && branch_taken == 0) ? pipeB_stageD_reg_stall_out : pipeA_stageD_reg_stall_input;
   
   

   // Pipe_A Stage Registers
   Nbit_reg #(16, 16'b0) pipeA_stageD_regPC (.in(pipeA_stageD_regPC_in), .out(pipeA_DX_pc), .clk(clk), .we(~pipeA_loadToUse), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) pipeA_stageD_regIR (.in(pipeA_stageD_regIR_in), .out(pipeA_stageD_IR_reg_out), .clk(clk), .we(~pipeA_loadToUse), .gwe(gwe), .rst(rst));
   Nbit_reg #(2, 2'b10)  pipeA_stageD_regStall (.in(pipeA_stageD_regStall_in), .out(pipeA_stageD_reg_stall_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(16, 16'b0) pipeA_stageX_regPC (.in(pipeA_DX_pc), .out(pipeA_X_pc_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) pipeA_stageX_regA (.in(pipeA_rsrc1_val), .out(pipeA_stageX_reg_A_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) pipeA_stageX_regB (.in(pipeA_rsrc2_val), .out(pipeA_stageX_reg_B_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(34, 34'b0) pipeA_stageX_regIR (.in(pipeA_stageX_IR_input), .out(pipeA_XM_decode_bus), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(2, 2'b10)  pipeA_stageX_regStall (.in(pipeA_DX_stallCode), .out(pipeA_XM_stallCode), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
 
   Nbit_reg #(16, 16'b0) pipeA_stageM_regPC (.in(pipeA_X_pc_out), .out(pipeA_MW_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) pipeA_stageM_regO (.in(pipeA_stageM_reg_O_input), .out(pipeA_stageM_reg_O_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) pipeA_stageM_regB (.in(pipeA_AluBBypassResult), .out(pipeA_stageM_reg_B_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(34, 34'b0) pipeA_stageM_regIR (.in(pipeA_XM_decode_bus), .out(pipeA_MW_decode_bus), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b0)   pipeA_stageM_regNZP (.in(pipeA_final_nzp_bits), .out(pipeA_MW_nzp_bits), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(2, 2'b10)  pipeA_stageM_regStall (.in(pipeA_XM_stallCode), .out(pipeA_MW_stallCode), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(16, 16'b0) pipeA_stageW_regPC (.in(pipeA_MW_pc), .out(pipeA_W_pc_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) pipeA_stageW_regO (.in(pipeA_stageM_reg_O_out), .out(pipeA_stageW_reg_O_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) pipeA_stageW_regD (.in(i_cur_dmem_data), .out(pipeA_stageW_reg_D_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(34, 34'b0) pipeA_stageW_regIR (.in(pipeA_MW_decode_bus), .out(pipeA_Wout_decode_bus), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b0)   pipeA_stageW_regNZP (.in(pipeA_stageW_regNZP_input), .out(test_nzp_new_bits_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(2, 2'b10)  pipeA_stageW_regStall (.in(pipeA_MW_stallCode), .out(test_stall_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0)   pipeA_stageW_regDmemWe (.in(pipeA_MW_decode_bus[18]), .out(test_dmem_we_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) pipeA_stageW_regDmemAddr (.in(pipeA_dmem_addr), .out(test_dmem_addr_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) pipeA_stageW_regDmemData (.in(pipeA_stageW_regDmemData_input), .out(test_dmem_data_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  

   // Wires needed to pipeline bypass pipe A
   wire [15:0] pipeA_AluABypassResult, pipeA_AluBBypassResult, pipeA_WMBypassResult;
   wire [1:0] pipeA_stageD_reg_stall_input, pipeA_stageD_reg_stall_out, pipeA_DX_stallCode, pipeA_XM_stallCode, pipeA_MW_stallCode;
   wire [15:0] pipeA_stageD_IR_input, pipeA_stageD_IR_reg_out;
   wire [15:0] pipeA_stageX_reg_A_out, pipeA_stageX_reg_B_out;
   wire [15:0] pipeA_stageM_reg_O_input, pipeA_stageM_reg_O_out, pipeA_stageM_reg_B_out;
   wire [15:0] pipeA_stageW_regDmemData_input;
   wire [15:0] pipeA_stageW_reg_O_out, pipeA_stageW_reg_D_out;
   wire [15:0] pipeA_W_result;
   wire [15:0] pipeA_DX_pc, pipeA_X_pc_out, pipeA_MW_pc, pipeA_W_pc_out;
   wire [33:0] pipeA_stageX_IR_input, pipeA_DX_decode_bus, pipeA_XM_decode_bus, pipeA_MW_decode_bus, pipeA_Wout_decode_bus;
   wire [2:0] pipeA_MW_nzp_bits, pipeA_stageW_regNZP_input;
   wire [15:0] pipeA_dmem_addr;
   
   // intermediate stage registers
   
   assign pipeA_DX_decode_bus[15:0] = pipeA_stageD_IR_reg_out; // putting pure instruction in decode bus

   

   

   // bypassing
   assign pipeA_AluABypassResult =  
      ((pipeA_XM_decode_bus[33:31] == pipeB_MW_decode_bus[27:25]) && (pipeB_MW_decode_bus[22] == 1)) ? pipeB_stageM_reg_O_out: 
      ((pipeA_XM_decode_bus[33:31] == pipeA_MW_decode_bus[27:25]) && (pipeA_MW_decode_bus[22] == 1)) ? pipeA_stageM_reg_O_out:  
      ((pipeA_XM_decode_bus[33:31] == pipeB_Wout_decode_bus[27:25]) && pipeB_Wout_decode_bus[22] == 1) ? pipeB_W_result: 
      ((pipeA_XM_decode_bus[33:31] == pipeA_Wout_decode_bus[27:25]) && pipeA_Wout_decode_bus[22] == 1) ? pipeA_W_result:              
      pipeA_stageX_reg_A_out;
                              
   assign pipeA_AluBBypassResult =
      ((pipeA_XM_decode_bus[30:28] == pipeB_MW_decode_bus[27:25]) && (pipeB_MW_decode_bus[22] == 1)) ? pipeB_stageM_reg_O_out:  
      ((pipeA_XM_decode_bus[30:28] == pipeA_MW_decode_bus[27:25]) && (pipeA_MW_decode_bus[22] == 1)) ? pipeA_stageM_reg_O_out:  
      ((pipeA_XM_decode_bus[30:28] == pipeB_Wout_decode_bus[27:25]) && pipeB_Wout_decode_bus[22] == 1) ? pipeB_W_result:  
      ((pipeA_XM_decode_bus[30:28] == pipeA_Wout_decode_bus[27:25]) && pipeA_Wout_decode_bus[22] == 1) ? pipeA_W_result:                     
      pipeA_stageX_reg_B_out;

   assign pipeA_WMBypassResult = 
      ((pipeA_MW_decode_bus[18]) && (pipeB_Wout_decode_bus[22]) && (pipeA_MW_decode_bus[30:28] == pipeB_Wout_decode_bus[27:25])) ? pipeB_W_result:  //MW_decode_bus[18] = is_store
      ((pipeA_MW_decode_bus[18]) && (pipeA_Wout_decode_bus[22]) && (pipeA_MW_decode_bus[30:28] == pipeA_Wout_decode_bus[27:25])) ? pipeA_W_result:  //MW_decode_bus[18] = is_store
      pipeA_stageM_reg_B_out;

   // XM_decode_bus, MW_decode_bus, are used implicitly in register declarations
   // Wout_decode_bus gets connect to main_regfile
   // DX_pc are used implicitly in register declarations
   
   
   // need to do this because trap returns pc+1 for R7. 
   assign pipeA_stageM_reg_O_input = (pipeA_XM_decode_bus[16] == 1) ? pipeB_X_pc_out : pipeA_alu_output; 
   
   // we don't know what the nzp bits for what we loaded are until stage M, so can't fully trust MW_nzp_bits
   assign pipeA_stageW_regNZP_input = (pipeA_MW_decode_bus[19] == 1) ? pipeA_nzp_new_bits_ld : pipeA_MW_nzp_bits; 
  
   //FINAL OUTPUT TO GO INTO REGISTERS
   assign pipeA_W_result = (pipeA_Wout_decode_bus[19] == 1) ? pipeA_stageW_reg_D_out :  //Wout_decode_bus[19] = is_load
                     pipeA_stageW_reg_O_out;
   
   assign pipeA_stageW_regDmemData_input = (pipeA_MW_decode_bus[19] == 1) ? i_cur_dmem_data :   //MW_decode_bus[19] == is_load
                           (pipeA_MW_decode_bus[18] == 1) ? pipeA_WMBypassResult : 16'b0;    
   
   assign pipeA_dmem_addr = ((pipeA_MW_decode_bus[19] == 1) || (pipeA_MW_decode_bus[18] == 1)) ? pipeA_stageM_reg_O_out : 16'b0;
   




  


   //MM BYPASS!!!

   // Pipe B starts
   lc4_decoder pipeB_decoder (.r1sel(pipeB_DX_decode_bus[33:31]), 
                                  .r2sel(pipeB_DX_decode_bus[30:28]),
                                  .wsel(pipeB_DX_decode_bus[27:25]),
                                  .r1re(pipeB_DX_decode_bus[24]),
                                  .r2re(pipeB_DX_decode_bus[23]),
                                  .regfile_we(pipeB_DX_decode_bus[22]),
                                  .nzp_we(pipeB_DX_decode_bus[21]), 
                                  .select_pc_plus_one(pipeB_DX_decode_bus[20]),
                                  .is_load(pipeB_DX_decode_bus[19]), 
                                  .is_store(pipeB_DX_decode_bus[18]),
                                  .is_branch(pipeB_DX_decode_bus[17]), 
                                  .is_control_insn(pipeB_DX_decode_bus[16]),
                                  .insn(pipeB_DX_decode_bus[15:0]));

   wire [15:0] pipeB_rsrc1_val, pipeB_rsrc2_val;
   wire [15:0] pipeB_alu_output;
   lc4_alu pipeB_alu (.i_insn(pipeB_XM_decode_bus[15:0]),
                .i_pc(pipeB_X_pc_out),
                .i_r1data(pipeB_AluABypassResult),
                .i_r2data(pipeB_AluBBypassResult),
                .o_result(pipeB_alu_output));

   // Pipe_B Pipeswitching logic
   wire [15:0] pipeB_stageD_regPC_in, pipeB_stageD_regIR_in;
   wire [1:0] pipeB_stageD_regStall_in;
   assign pipeB_stageD_regPC_in = (pipeSwitch == 1 && branch_taken == 0) ? pipeA_D_pc_in : pipeB_D_pc_in;
   assign pipeB_stageD_regIR_in = (pipeSwitch == 1 && branch_taken == 0) ? pipeA_stageD_IR_input : pipeB_stageD_IR_input;
   assign pipeB_stageD_regStall_in = (pipeSwitch == 1 && branch_taken == 0) ? pipeA_stageD_reg_stall_input : pipeB_stageD_reg_stall_input;

   // Pipe_B Stage Registers
   // Nbit_reg #(2, 2'b10)  pipeB_stageF_regStall (.in(pipeB_stageF_regStall_in), .out(pipeB_stageF_reg_stall_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(16, 16'b0) pipeB_stageD_regPC (.in(pipeB_stageD_regPC_in), .out(pipeB_DX_pc), .clk(clk), .we(~(pipeA_loadToUse)), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) pipeB_stageD_regIR (.in(pipeB_stageD_regIR_in), .out(pipeB_stageD_IR_reg_out), .clk(clk), .we(~(pipeA_loadToUse)), .gwe(gwe), .rst(rst));
   Nbit_reg #(2, 2'b10)  pipeB_stageD_regStall (.in(pipeB_stageD_regStall_in), .out(pipeB_stageD_reg_stall_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(16, 16'b0) pipeB_stageX_regPC (.in(pipeB_DX_pc), .out(pipeB_X_pc_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) pipeB_stageX_regA (.in(pipeB_rsrc1_val), .out(pipeB_stageX_reg_A_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) pipeB_stageX_regB (.in(pipeB_rsrc2_val), .out(pipeB_stageX_reg_B_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(34, 34'b0) pipeB_stageX_regIR (.in(pipeB_stageX_IR_input), .out(pipeB_XM_decode_bus), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(2, 2'b10)  pipeB_stageX_regStall (.in(pipeB_DX_stallCode), .out(pipeB_X_stallCode_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
 
   Nbit_reg #(16, 16'b0) pipeB_stageM_regPC (.in(pipeB_X_pc_out), .out(pipeB_MW_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) pipeB_stageM_regO (.in(pipeB_stageM_reg_O_input), .out(pipeB_stageM_reg_O_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) pipeB_stageM_regB (.in(pipeB_AluBBypassResult), .out(pipeB_stageM_reg_B_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(34, 34'b0) pipeB_stageM_regIR (.in(pipeB_stageM_IR_input), .out(pipeB_MW_decode_bus), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b0)   pipeB_stageM_regNZP (.in(pipeB_final_nzp_bits), .out(pipeB_MW_nzp_bits), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(2, 2'b10)  pipeB_stageM_regStall (.in(pipeB_XM_stallCode), .out(pipeB_MW_stallCode), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(16, 16'b0) pipeB_stageW_regPC (.in(pipeB_MW_pc), .out(pipeB_W_pc_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) pipeB_stageW_regO (.in(pipeB_stageM_reg_O_out), .out(pipeB_stageW_reg_O_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) pipeB_stageW_regD (.in(i_cur_dmem_data), .out(pipeB_stageW_reg_D_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(34, 34'b0) pipeB_stageW_regIR (.in(pipeB_MW_decode_bus), .out(pipeB_Wout_decode_bus), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b0)   pipeB_stageW_regNZP (.in(pipeB_stageW_regNZP_input), .out(test_nzp_new_bits_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(2, 2'b10)  pipeB_stageW_regStall (.in(pipeB_MW_stallCode), .out(test_stall_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0)   pipeB_stageW_regDmemWe (.in(pipeB_MW_decode_bus[18]), .out(test_dmem_we_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) pipeB_stageW_regDmemAddr (.in(pipeB_dmem_addr), .out(test_dmem_addr_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) pipeB_stageW_regDmemData (.in(pipeB_stageW_regDmemData_input), .out(test_dmem_data_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  

   // Wires needed to pipeline bypass
   wire [15:0] pipeB_AluABypassResult, pipeB_AluBBypassResult, pipeB_MMBypassResult, pipeB_WMBypassResult;
   wire [1:0] pipeB_stageD_reg_stall_input, pipeB_stageD_reg_stall_out, pipeB_DX_stallCode, pipeB_X_stallCode_out, pipeB_XM_stallCode, pipeB_MW_stallCode;
   wire [15:0] pipeB_stageD_IR_input, pipeB_stageD_IR_reg_out;
   wire [15:0] pipeB_stageX_reg_A_input, pipeB_stageX_reg_B_input;
   wire [15:0] pipeB_stageX_reg_A_out, pipeB_stageX_reg_B_out;
   wire [15:0] pipeB_stageM_reg_O_input, pipeB_stageM_reg_O_out, pipeB_stageM_reg_B_out;
   wire [15:0] pipeB_stageW_regDmemData_input;
   wire [15:0] pipeB_stageW_reg_O_out, pipeB_stageW_reg_D_out;
   wire [15:0] pipeB_W_result;
   wire [15:0] pipeB_DX_pc, pipeB_X_pc_out, pipeB_MW_pc, pipeB_W_pc_out;
   wire [33:0] pipeB_DX_decode_bus, pipeB_stageX_IR_input, pipeB_XM_decode_bus, pipeB_stageM_IR_input, pipeB_MW_decode_bus, pipeB_Wout_decode_bus;
   wire [2:0] pipeB_MW_nzp_bits, pipeB_stageW_regNZP_input;
   wire [15:0] pipeB_dmem_addr;
   
   // intermediate stage registers
   
   assign pipeB_DX_decode_bus[15:0] = pipeB_stageD_IR_reg_out; // putting pure instruction in decode bus










//STALLING
   wire pipeA_loadToUse_XbDa, pipeA_loadToUse_XaDa, decode_dependence, pipeB_loadToUse_XbDb, pipeB_loadToUse_XaDb;
   wire DaDb_dependence, XbDa_dependence, XaDa_dependence, XbDb_dependence, XaDb_dependence;
   wire pipeA_loadToUse, pipeB_loadToUse;
   wire pipeSwitch, pipeB_superscalar_stall;

   assign XbDa_dependence = 
         (  ((pipeA_DX_decode_bus[24]) && (pipeB_XM_decode_bus[22]) && (pipeA_DX_decode_bus[33:31] == pipeB_XM_decode_bus[27:25])) // (Da.r1.re == 1) && (Xb.we == 1) && (Da.r1 == Xb.wsel)
            ||
            ((pipeA_DX_decode_bus[23]) && (pipeB_XM_decode_bus[22]) && (pipeA_DX_decode_bus[30:28] == pipeB_XM_decode_bus[27:25]) && (~pipeA_DX_decode_bus[18])) // (Da.r2.re == 1) && (Xb.we == 1) && (Da.r2 == Xb.wsel) && (Da isn't a store)
            || 
            ((pipeA_DX_decode_bus[15:12]==4'b0) && (pipeA_DX_decode_bus[15:0] != 16'b0) && (pipeB_XM_decode_bus[21] == 1))
         );
   assign pipeA_loadToUse_XbDa = ( 
         (pipeB_XM_decode_bus[19]) 
         &&   
         XbDa_dependence
      );

   
   assign XaDa_dependence = 
         (  ((pipeA_DX_decode_bus[24]) && (pipeA_XM_decode_bus[22]) && (pipeA_DX_decode_bus[33:31] == pipeA_XM_decode_bus[27:25]))  //  (Da.r1.re == 1) && (Xa.we == 1) && (Da.r1 == Xa.wsel)
            ||
            ((pipeA_DX_decode_bus[23]) && (pipeA_XM_decode_bus[22]) &&(pipeA_DX_decode_bus[30:28] == pipeA_XM_decode_bus[27:25]) && (~pipeA_DX_decode_bus[18])) // (Da.r2.re == 1) && (Xa.we == 1) && (Da.r2 == Xa.wsel) && (Da isn't a store)
            || 
            ((pipeA_DX_decode_bus[15:12]==4'b0) && (pipeA_DX_decode_bus[15:0] != 16'b0) && (pipeA_XM_decode_bus[21] == 1))    // All branches are dependent on loads b/c of nzp bits
         );
   assign pipeA_loadToUse_XaDa = (
         ~XbDa_dependence
         &&
         pipeA_XM_decode_bus[19] //XM_decode_bus[19] = is_load
         && 
         XaDa_dependence  
      );

   assign DaDb_dependence = 
      (  
         ((pipeA_DX_decode_bus[27:25] == pipeB_DX_decode_bus[33:31]) && pipeA_DX_decode_bus[22] == 1 && pipeB_DX_decode_bus[24] == 1) // (DA.W == DB.R1) && (DA.WE == 1) && (DB.r1.re == 1)
         ||
         ( (pipeA_DX_decode_bus[27:25] == pipeB_DX_decode_bus[30:28]) && pipeA_DX_decode_bus[22] == 1 && pipeB_DX_decode_bus[23] == 1 && pipeB_DX_decode_bus[18] == 0) // (DA.W == DB.R2) && (DA.WE == 1) && (DB.r2.re == 1) && (B is not store because then we MM bypass)
         ||
         ( (pipeA_DX_decode_bus[18] | pipeA_DX_decode_bus[19]) && (pipeB_DX_decode_bus[18] | pipeB_DX_decode_bus[19]) ) // (DA is load or store) && (DB is load or store)
         ||
         ((pipeB_DX_decode_bus[15:12] == 4'b0) && (pipeB_DX_decode_bus[15:0] != 16'b0) && (pipeA_DX_decode_bus[21] == 1) ) // branches are dependent on nzp bits if they are written
      );
   
   assign decode_dependence = (
         (~pipeA_loadToUse_XbDa && ~pipeA_loadToUse_XaDa)
         &&
         DaDb_dependence
      );


   assign XbDb_dependence = 
         (  ((pipeB_DX_decode_bus[24]) && (pipeB_XM_decode_bus[22]) && (pipeB_DX_decode_bus[33:31] == pipeB_XM_decode_bus[27:25])) 
            ||
            ((pipeB_DX_decode_bus[23]) && (pipeB_XM_decode_bus[22]) && (pipeB_DX_decode_bus[30:28] == pipeB_XM_decode_bus[27:25]) && (~pipeB_DX_decode_bus[18])) 
            || 
            (pipeB_DX_decode_bus[15:12]==4'b0 && (pipeB_DX_decode_bus[15:0] != 16'b0) && (pipeB_XM_decode_bus[21] == 1))   // All branches are dependent on loads b/c of nzp bits
         );
   assign pipeB_loadToUse_XbDb = (
         (~pipeA_loadToUse_XbDa && ~pipeA_loadToUse_XaDa && ~decode_dependence && ~DaDb_dependence)
         &&
         (pipeB_XM_decode_bus[19])  //XM_decode_bus[19] = is_load
         &&   
         XbDb_dependence
      );
      
      
   assign XaDb_dependence = (
         ((pipeB_DX_decode_bus[24]) && (pipeA_XM_decode_bus[22]) && (pipeB_DX_decode_bus[33:31] == pipeA_XM_decode_bus[27:25])) 
         ||
         ((pipeB_DX_decode_bus[23]) && (pipeA_XM_decode_bus[22]) && (pipeB_DX_decode_bus[30:28] == pipeA_XM_decode_bus[27:25]) && (~pipeB_DX_decode_bus[18])) 
         || 
         ((pipeB_DX_decode_bus[15:12]==4'b0) && (pipeB_DX_decode_bus[15:0] != 16'b0) && (pipeA_XM_decode_bus[21] == 1))
   ); 
   assign pipeB_loadToUse_XaDb = (
         (~pipeA_loadToUse_XbDa && ~pipeA_loadToUse_XaDa && ~decode_dependence && ~XbDb_dependence && ~DaDb_dependence)
         &&
         (pipeA_XM_decode_bus[19])  //XM_decode_bus[19] = is_load
         &&  
         XaDb_dependence
      );



// handling stall codes and flushes
   assign pipeA_loadToUse = pipeA_loadToUse_XaDa | pipeA_loadToUse_XbDa;

   assign pipeA_stageD_reg_stall_input = (branch_taken) ? 2'd2 : 
                                       2'd0;

   assign pipeA_DX_stallCode = 
                        (branch_taken) ? 2'd2 : 
                        (pipeA_loadToUse == 1) ? 2'd3 :
                        pipeA_stageD_reg_stall_out;
                  
         //insert NOP if necessary
   wire branch_taken;
   assign branch_taken = pipeA_X_branch_taken_or_control | pipeB_X_branch_taken_or_control;
         
   assign pipeA_stageD_IR_input = ((branch_taken) == 1) ? {16{1'b0}} : i_cur_insn_A;
   assign pipeA_stageX_IR_input = ((branch_taken | pipeA_loadToUse) == 1) ? 
                                       {34{1'b0}} : pipeA_DX_decode_bus;

   //start pipe B
   assign pipeB_loadToUse = pipeB_loadToUse_XaDb | pipeB_loadToUse_XbDb;
   assign pipeB_superscalar_stall = pipeA_loadToUse | decode_dependence;
   assign pipeSwitch = decode_dependence | pipeB_loadToUse;
   

   assign pipeB_stageD_reg_stall_input = (branch_taken) ? 2'd2 : 
                                       2'd0;

   assign pipeB_DX_stallCode = 
                        (branch_taken) ? 2'd2 :
                        (pipeB_superscalar_stall == 1) ? 2'd1 :
                        (pipeB_loadToUse == 1) ? 2'd3 :
                        pipeB_stageD_reg_stall_out;
   assign pipeB_XM_stallCode = (pipeA_X_branch_taken_or_control == 1) ? 2'd2 : pipeB_X_stallCode_out;

         //insert NOP if necessary
   assign pipeB_stageD_IR_input = ((branch_taken) == 1) ? {16{1'b0}} : i_cur_insn_B;
   assign pipeB_stageX_IR_input = ((branch_taken | pipeB_loadToUse | pipeB_superscalar_stall) == 1) 
                                          ? {34{1'b0}} : pipeB_DX_decode_bus;
                                          
   assign pipeB_stageM_IR_input = (pipeA_X_branch_taken_or_control == 1)  ? {34{1'b0}} : pipeB_XM_decode_bus;
   
   
   // bypassing
   assign pipeB_AluABypassResult = 
      ((pipeB_XM_decode_bus[33:31] == pipeB_MW_decode_bus[27:25]) && (pipeB_MW_decode_bus[22] == 1)) ? pipeB_stageM_reg_O_out:   // 
      ((pipeB_XM_decode_bus[33:31] == pipeA_MW_decode_bus[27:25]) && (pipeA_MW_decode_bus[22] == 1)) ? pipeA_stageM_reg_O_out:    
      ((pipeB_XM_decode_bus[33:31] == pipeB_Wout_decode_bus[27:25]) && pipeB_Wout_decode_bus[22] == 1) ? pipeB_W_result:          
      ((pipeB_XM_decode_bus[33:31] == pipeA_Wout_decode_bus[27:25]) && pipeA_Wout_decode_bus[22] == 1) ? pipeA_W_result:              
      pipeB_stageX_reg_A_out;
                              
   assign pipeB_AluBBypassResult =
      ((pipeB_XM_decode_bus[30:28] == pipeB_MW_decode_bus[27:25]) && (pipeB_MW_decode_bus[22] == 1)) ? pipeB_stageM_reg_O_out:  
      ((pipeB_XM_decode_bus[30:28] == pipeA_MW_decode_bus[27:25]) && (pipeA_MW_decode_bus[22] == 1)) ? pipeA_stageM_reg_O_out:  
      ((pipeB_XM_decode_bus[30:28] == pipeB_Wout_decode_bus[27:25]) && pipeB_Wout_decode_bus[22] == 1) ? pipeB_W_result:
      ((pipeB_XM_decode_bus[30:28] == pipeA_Wout_decode_bus[27:25]) && pipeA_Wout_decode_bus[22] == 1) ? pipeA_W_result:                    
      pipeB_stageX_reg_B_out;

   assign pipeB_WMBypassResult = 

      ((pipeA_MW_decode_bus[27:25] == pipeB_MW_decode_bus[30:28]) &&                             // (Ma.wsel == Mb.r2)
                                    (pipeA_MW_decode_bus[22] == 1) &&                                                         // (Ma.we)
                                    (pipeB_MW_decode_bus[18] == 1)) ? pipeA_stageM_reg_O_out :     // MM bypass

      ((pipeB_MW_decode_bus[18]) && (pipeB_Wout_decode_bus[22]) && (pipeB_MW_decode_bus[30:28] == pipeB_Wout_decode_bus[27:25])) ? pipeB_W_result:  // Mb.is_store && Wb.we && (Mb.r2 == Wb.wsel)
      ((pipeB_MW_decode_bus[18]) && (pipeA_Wout_decode_bus[22]) && (pipeB_MW_decode_bus[30:28] == pipeA_Wout_decode_bus[27:25])) ? pipeA_W_result:  // Mb.is_store && Wa.we && (Mb.r2 == Wa.wsel)
      pipeB_stageM_reg_B_out;


    


   // XM_decode_bus, MW_decode_bus, are used implicitly in register declarations
   // Wout_decode_bus gets connect to main_regfile
   // DX_pc are used implicitly in register declarations
   
   
   // need to do this because trap returns pc+1 for R7 (MAY NOT BE CORRECT)
   assign pipeB_stageM_reg_O_input = (pipeB_XM_decode_bus[16] == 1) ? pipeA_DX_pc : pipeB_alu_output; 
   
   // we don't know what the nzp bits for what we loaded are until stage M, so can't fully trust MW_nzp_bits
   assign pipeB_stageW_regNZP_input = (pipeB_MW_decode_bus[19] == 1) ? pipeB_nzp_new_bits_ld : pipeB_MW_nzp_bits; 
  
   //FINAL OUTPUT TO GO INTO REGISTERS
   assign pipeB_W_result = (pipeB_Wout_decode_bus[19] == 1) ? pipeB_stageW_reg_D_out :  //Wout_decode_bus[19] = is_load
                     pipeB_stageW_reg_O_out;
   
   assign pipeB_stageW_regDmemData_input = (pipeB_MW_decode_bus[19] == 1) ? i_cur_dmem_data :   //MW_decode_bus[19] == is_load
                                           (pipeB_MW_decode_bus[18] == 1) ? pipeB_WMBypassResult : 
                                           16'b0;
   assign pipeB_dmem_addr = ((pipeB_MW_decode_bus[19] == 1) || (pipeB_MW_decode_bus[18] == 1)) ? pipeB_stageM_reg_O_out : 16'b0;




   // calculating nzp and branching in execute stage
   wire [2:0] pipeA_final_nzp_bits, pipeB_final_nzp_bits, nzp_reg_out;

   wire pipeA_bu_nzp_reduced, pipeA_X_branch_taken_or_control;
   wire [2:0] pipeA_nzp_new_bits_alu, pipeA_nzp_new_bits_ld, pipeA_nzp_new_bits_trap;
   wire [2:0] pipeA_nzp_new_bits, pipeA_bu_nzp_bus, pipeA_bu_nzp_and;

   assign pipeA_nzp_new_bits_alu = ($signed(pipeA_alu_output) > 0) ? 3'b001:
                                  (pipeA_alu_output == 0) ? 3'b010: 3'b100;
   assign pipeA_nzp_new_bits_ld = ($signed(i_cur_dmem_data) > 0) ? 3'b001:
                                  (i_cur_dmem_data == 0) ? 3'b010: 3'b100;  
   assign pipeA_nzp_new_bits_trap = ($signed(pipeA_X_pc_out) > 0) ? 3'b001:
                                  (pipeA_X_pc_out == 0) ? 3'b010: 3'b100;  
   assign pipeA_nzp_new_bits = (pipeA_XM_decode_bus[15:12] == 4'b1111) ? pipeA_nzp_new_bits_trap :  
                        ((pipeA_MW_decode_bus[19]==1) && (pipeA_XM_stallCode==2'd3) ) ? pipeA_nzp_new_bits_ld : 
                        pipeA_nzp_new_bits_alu;


   wire pipeB_bu_nzp_reduced, pipeB_X_branch_taken_or_control;
   wire [2:0] pipeB_nzp_new_bits_alu, pipeB_nzp_new_bits_ld, pipeB_nzp_new_bits_trap;
   wire [2:0] pipeB_nzp_new_bits, pipeB_bu_nzp_and;

   assign pipeB_nzp_new_bits_alu = ($signed(pipeB_alu_output) > 0) ? 3'b001:
                                  (pipeB_alu_output == 0) ? 3'b010: 3'b100;
   assign pipeB_nzp_new_bits_ld = ($signed(i_cur_dmem_data) > 0) ? 3'b001:
                                  (i_cur_dmem_data == 0) ? 3'b010: 3'b100;  
   assign pipeB_nzp_new_bits_trap = ($signed(pipeB_X_pc_out) > 0) ? 3'b001:
                                  (pipeB_X_pc_out == 0) ? 3'b010: 3'b100;  

   assign pipeB_nzp_new_bits = (pipeB_XM_decode_bus[15:12] == 4'b1111) ? pipeB_nzp_new_bits_trap :  
                        ((pipeB_MW_decode_bus[19]==1) && (pipeB_XM_stallCode==2'd3) ) ? pipeB_nzp_new_bits_ld : 
                        pipeB_nzp_new_bits_alu;


   assign pipeA_final_nzp_bits = (pipeA_XM_decode_bus[21] == 1) ? pipeA_nzp_new_bits : nzp_reg_out;
   assign pipeA_bu_nzp_and = pipeA_final_nzp_bits & pipeA_XM_decode_bus[11:9]; //get sub-op from XM_decode_bus insn
   assign pipeA_bu_nzp_reduced = |pipeA_bu_nzp_and;
   assign pipeA_X_branch_taken_or_control = (pipeA_bu_nzp_reduced & pipeA_XM_decode_bus[17]) || pipeA_XM_decode_bus[16]; //XM_decode_bus[17] = is_branch. XM_decode_bus[16] = is_control

   assign pipeB_final_nzp_bits = (pipeA_X_branch_taken_or_control == 1) ? pipeA_final_nzp_bits: 
                                 (pipeB_XM_decode_bus[21] == 1) ? pipeB_nzp_new_bits : 
                                 (pipeA_XM_decode_bus[21] == 1) ? pipeA_nzp_new_bits : 
                                 nzp_reg_out;

   assign pipeB_bu_nzp_and = pipeB_final_nzp_bits & pipeB_XM_decode_bus[11:9]; //get sub-op from XM_decode_bus insn
   assign pipeB_bu_nzp_reduced = |pipeB_bu_nzp_and;
   assign pipeB_X_branch_taken_or_control = (~pipeA_X_branch_taken_or_control) && ((pipeB_bu_nzp_reduced & pipeB_XM_decode_bus[17]) || pipeB_XM_decode_bus[16]); //XM_decode_bus[17] = is_branch. XM_decode_bus[16] = is_control


   Nbit_reg pipeB_nzp_reg (
      .in(pipeB_final_nzp_bits), 
      .out(nzp_reg_out),
      .clk(clk),
      .we(1'b1), 
      .gwe(gwe),
      .rst(rst)
      );
   defparam pipeB_nzp_reg.n = 3;
   // end of branch handling


   // SHARED THINGS

   lc4_regfile_ss main_regfile (.clk(clk),
                        .gwe(gwe),
                        .rst(rst),
                        .i_rs_A(pipeA_DX_decode_bus[33:31]), 
                        .o_rs_data_A(pipeA_rsrc1_val),
                        .i_rt_A(pipeA_DX_decode_bus[30:28]), 
                        .o_rt_data_A(pipeA_rsrc2_val),

                        .i_rs_B(pipeB_DX_decode_bus[33:31]), 
                        .o_rs_data_B(pipeB_rsrc1_val),
                        .i_rt_B(pipeB_DX_decode_bus[30:28]), 
                        .o_rt_data_B(pipeB_rsrc2_val),

                        .i_rd_A(pipeA_Wout_decode_bus[27:25]), 
                        .i_wdata_A(pipeA_W_result), 
                        .i_rd_we_A(pipeA_Wout_decode_bus[22]),

                        .i_rd_B(pipeB_Wout_decode_bus[27:25]), 
                        .i_wdata_B(pipeB_W_result), 
                        .i_rd_we_B(pipeB_Wout_decode_bus[22]) );
    

   Nbit_reg #(16, 16'h8200) stageF_regPC (.in(next_pc), .out(Fout_pc), .clk(clk), .we(~pipeA_loadToUse), .gwe(gwe), .rst(rst));
   wire[15:0] Fout_pc, Fout_pc_plus_one, Fout_pc_plus_two;
   cla16 pc_incr1(.a(Fout_pc), .b(16'b0), .cin(1'b1), .sum(Fout_pc_plus_one));
   cla16 pc_incr2(.a(Fout_pc_plus_one), .b(16'b0), .cin(1'b1), .sum(Fout_pc_plus_two));

   wire [15:0] next_pc, pipeA_D_pc_in, pipeB_D_pc_in, next_pc_incr_option;

   assign pipeA_D_pc_in = Fout_pc;
   assign pipeB_D_pc_in = Fout_pc_plus_one;
   assign next_pc_incr_option =  (pipeA_loadToUse) ? Fout_pc : 
                                 (pipeSwitch == 1) ? Fout_pc_plus_one : 
                                 Fout_pc_plus_two;

   assign next_pc =  (pipeA_X_branch_taken_or_control == 1) ? pipeA_alu_output :
                     (pipeB_X_branch_taken_or_control == 1) ? pipeB_alu_output :
                      next_pc_incr_option;






   //TEST VALUES
   assign o_cur_pc = Fout_pc;
   
  

   assign o_dmem_addr = ((pipeA_MW_decode_bus[19] == 1) || (pipeA_MW_decode_bus[18] == 1)) ? pipeA_stageM_reg_O_out :  // shouldn't matter whether A or B is first since only 1 load/store at a time
                        ((pipeB_MW_decode_bus[19] == 1) || (pipeB_MW_decode_bus[18] == 1)) ? pipeB_stageM_reg_O_out :
                        16'b0;         
   assign o_dmem_we = pipeA_MW_decode_bus[18] | pipeB_MW_decode_bus[18];
   assign o_dmem_towrite = (pipeA_MW_decode_bus[18] == 1) ? pipeA_WMBypassResult : pipeB_WMBypassResult;
   //assign test_stall = 2'b0;        //assigned in stageW_reg_Stall       
   assign test_cur_pc_A = pipeA_W_pc_out; 
   assign test_cur_pc_B = pipeB_W_pc_out; 
                  
   assign test_cur_insn_A = pipeA_Wout_decode_bus[15:0];
   assign test_cur_insn_B = pipeB_Wout_decode_bus[15:0];
   
   assign test_regfile_we_A = pipeA_Wout_decode_bus[22];
   assign test_regfile_we_B = pipeB_Wout_decode_bus[22];
   
   assign test_regfile_wsel_A = pipeA_Wout_decode_bus[27:25];
   assign test_regfile_wsel_B = pipeB_Wout_decode_bus[27:25];

   assign test_regfile_data_A = pipeA_W_result;
   assign test_regfile_data_B = pipeB_W_result;
   
   assign test_nzp_we_A = pipeA_Wout_decode_bus[21];
   assign test_nzp_we_B = pipeB_Wout_decode_bus[21];
   //assign test_nzp_new_bits  //assigned in stage_W_regNZP
   // assign test_dmem_we = o_dmem_we;          // assigned in stageW_regDmemWe
   // assign test_dmem_addr = o_dmem_addr;      // assigned in stageW_regDmemAddr



   /* STUDENT CODE ENDS */






   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    *
    * You may also use if statements inside the always block
    * to conditionally print out information.
    */

  
   
   always @(posedge gwe) begin
      if (next_pc > 16'h8320 && next_pc < 16'h8330) begin
         //$display("DX_IR = %h %h. decode_dependence = %d. pipeA_loadToUse_XaDa = %d. test1 = %d. test2 = %d. A_SC = %d. B_SC = %d", pipeA_DX_decode_bus[15:0], pipeB_DX_decode_bus[15:0], decode_dependence, pipeA_loadToUse_XaDa, test1, test2, pipeA_DX_stallCode, pipeB_DX_stallCode);
         $display("DX_IR = %h %h. XM_IR = %h %h. MW_IR = %h %h. Wout_IR = %h %h. A_SC = %d. B_SC = %d.", pipeA_DX_decode_bus[15:0], pipeB_DX_decode_bus[15:0], pipeA_XM_decode_bus[15:0], pipeB_XM_decode_bus[15:0], pipeA_MW_decode_bus[15:0], pipeB_MW_decode_bus[15:0], pipeA_Wout_decode_bus[15:0], pipeB_Wout_decode_bus[15:0], pipeA_DX_stallCode, pipeB_DX_stallCode);
      end
      

      
      
     
     

      // $display("%d %h %h %h %h %h", $time, f_pc, d_pc, e_pc, m_pc, test_cur_pc);
      // if (o_dmem_we)
      //   $display("%d STORE %h <= %h", $time, o_dmem_addr, o_dmem_towrite);

      // Start each $display() format string with a %d argument for time
      // it will make the output easier to read.  Use %b, %h, and %d
      // for binary, hex, and decimal output of additional variables.
      // You do not need to add a \n at the end of your format string.
      // $display("%d ...", $time);

      // Try adding a $display() call that prints out the PCs of
      // each pipeline stage in hex.  Then you can easily look up the
      // instructions in the .asm files in test_data.

      // basic if syntax:
      // if (cond) begin
      //    ...;
      //    ...;
      // end

      // Set a breakpoint on the empty $display() below
      // to step through your pipeline cycle-by-cycle.
      // You'll need to rewind the simulation to start
      // stepping from the beginning.

      // You can also simulate for XXX ns, then set the
      // breakpoint to start stepping midway through the
      // testbench.  Use the $time printouts you added above (!)
      // to figure out when your problem instruction first
      // enters the fetch stage.  Rewind your simulation,
      // run it for that many nanoseconds, then set
      // the breakpoint.

      // In the objects view, you can change the values to
      // hexadecimal by selecting all signals (Ctrl-A),
      // then right-click, and select Radix->Hexadecimal.

      // To see the values of wires within a module, select
      // the module in the hierarchy in the "Scopes" pane.
      // The Objects pane will update to display the wires
      // in that module.

      //$display();
   end
endmodule
