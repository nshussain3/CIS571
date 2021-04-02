/* TODO: name and PennKeys of all group members here
 *
 * lc4_single.v
 * Implements a single-cycle data path
 *
 */

`timescale 1ns / 1ps

// disable implicit wire declaration
`default_nettype none

module lc4_processor
   (input  wire        clk,                // Main clock
    input  wire        rst,                // Global reset
    input  wire        gwe,                // Global we for single-step clock
   
    input  wire [15:0] i_cur_insn,         // Output of instruction memory
    input  wire [15:0] i_cur_dmem_data,    // Output of data memory
    output wire [15:0] o_cur_pc,           // Address to read from instruction memory
    output wire [15:0] o_dmem_addr,        // Address to read/write from/to data memory; SET TO 0x0000 FOR NON LOAD/STORE INSNS
    output wire        o_dmem_we,          // Data memory write enable
    output wire [15:0] o_dmem_towrite,     // Value to write to data memory
    
    output wire [1:0]  test_stall,         // Testbench: is this a stall cycle? (don't compare the test values)
    output wire [15:0] test_cur_pc,        // Testbench: program counter
    output wire [15:0] test_cur_insn,      // Testbench: instruction bits
    output wire        test_regfile_we,    // Testbench: register file write enable
    output wire [2:0]  test_regfile_wsel,  // Testbench: which register to write in the register file 
    output wire [15:0] test_regfile_data,  // Testbench: value to write into the register file
    output wire        test_nzp_we,        // Testbench: NZP condition codes write enable
    output wire [2:0]  test_nzp_new_bits,  // Testbench: value to write to NZP bits
    output wire        test_dmem_we,       // Testbench: data memory write enable
    output wire [15:0] test_dmem_addr,     // Testbench: address to read/write memory
    output wire [15:0] test_dmem_data,     // Testbench: value read/writen from/to memory
   
    input  wire [7:0]  switch_data,        // Current settings of the Zedboard switches
    output wire [7:0]  led_data            // Which Zedboard LEDs should be turned on?
    );

   // By default, assign LEDs to display switch inputs to avoid warnings about
   // disconnected ports. Feel free to use this for debugging input/output if
   // you desire.
   assign led_data = switch_data;

  
  

   /* END DO NOT MODIFY THIS CODE */



   /* STUDENT CODE BEGINS */

   lc4_decoder processor_decoder (.r1sel(DX_decode_bus[33:31]), 
                                  .r2sel(DX_decode_bus[30:28]),
                                  .wsel(DX_decode_bus[27:25]),
                                  .r1re(DX_decode_bus[24]),
                                  .r2re(DX_decode_bus[23]),
                                  .regfile_we(DX_decode_bus[22]),
                                  .nzp_we(DX_decode_bus[21]), 
                                  .select_pc_plus_one(DX_decode_bus[20]),
                                  .is_load(DX_decode_bus[19]), 
                                  .is_store(DX_decode_bus[18]),
                                  .is_branch(DX_decode_bus[17]), 
                                  .is_control_insn(DX_decode_bus[16]),
                                  .insn(DX_decode_bus[15:0]));

   wire [15:0] rsrc1_val, rsrc2_val;
   wire [15:0] select_result;
   lc4_regfile main_regfile (.clk(clk),
                        .gwe(gwe),
                        .rst(rst),
                        .i_rs(DX_decode_bus[33:31]), 
                        .o_rs_data(rsrc1_val),
                        .i_rt(DX_decode_bus[30:28]), 
                        .o_rt_data(rsrc2_val),
                        .i_rd(Wout_decode_bus[27:25]), 
                        .i_wdata(W_result), 
                        .i_rd_we(Wout_decode_bus[22]));
   
   wire [15:0] alu_output;
   lc4_alu alu (.i_insn(XM_decode_bus[15:0]),
                .i_pc(X_pc_out),
                .i_r1data(AluABypassResult),
                .i_r2data(AluBBypassResult),
                .o_result(alu_output));
   
   wire [15:0] Fout_pc_plus_one;
   cla16 pc_incr(.a(Fout_pc), .b(16'b0), .cin(1'b1), .sum(Fout_pc_plus_one));

   

   // lc4_branch_unit branch_unit(.clk(clk), .rst(rst), .gwe(gwe),
   //                            .bu_pc_plus_one(pc_plus_one), 
   //                            .bu_select_result(select_result),
   //                            .nzp_we(nzp_we),
   //                            .is_branch(is_branch),
   //                            .is_control(is_control_insn),
   //                            .insn(i_cur_insn),
   //                            .bu_alu_output(alu_output),
   //                            .bu_next_pc(next_pc),
   //                            .test_nzp_new_bits(test_nzp_new_bits));


   // Wires needed to pipeline bypass
   wire [15:0] AluABypassResult, AluBBypassResult, WMBypassResult;
   wire loadToUse;
   wire [1:0] stageD_reg_stall_input, stageD_reg_stall_out, DX_stallCode, XM_stallCode, MW_stallCode;
   wire [15:0] stageD_IR_input, stageD_IR_reg_out;
   wire [15:0] stageX_reg_A_input, stageX_reg_B_input;
   wire [33:0] stageX_IR_input, DX_decode_bus, XM_decode_bus, MW_decode_bus, Wout_decode_bus;
   wire [15:0] next_pc, Fout_pc, DX_pc, X_pc_out, MW_pc, W_pc_out;
   wire [15:0] stageX_reg_A_out, stageX_reg_B_out;
   wire [15:0] stageM_reg_O_out, stageM_reg_B_out, stageM_reg_O_input;
   wire [15:0] stageW_reg_O_out, stageW_reg_D_out;
   wire [15:0] W_result;
   wire [2:0] MW_nzp_bits;
   
   // intermediate stage registers
   Nbit_reg #(16, 16'h8200) stageF_regPC (.in(next_pc), .out(Fout_pc), .clk(clk), .we(~loadToUse), .gwe(gwe), .rst(rst));

   Nbit_reg #(16, 16'b0) stageD_regPC (.in(Fout_pc), .out(DX_pc), .clk(clk), .we(~loadToUse), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) stageD_regIR (.in(stageD_IR_input), .out(stageD_IR_reg_out), .clk(clk), .we(~loadToUse), .gwe(gwe), .rst(rst));
   Nbit_reg #(2, 2'b10) stageD_regStall (.in(stageD_reg_stall_input), .out(stageD_reg_stall_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(16, 16'b0) stageX_regPC (.in(DX_pc), .out(X_pc_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) stageX_regA (.in(stageX_reg_A_input), .out(stageX_reg_A_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) stageX_regB (.in(stageX_reg_B_input), .out(stageX_reg_B_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(34, 34'b0) stageX_regIR (.in(stageX_IR_input), .out(XM_decode_bus), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(2, 2'b10) stageX_regStall (.in(DX_stallCode), .out(XM_stallCode), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
 
   Nbit_reg #(16, 16'b0) stageM_regPC (.in(X_pc_out), .out(MW_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) stageM_regO (.in(stageM_reg_O_input), .out(stageM_reg_O_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) stageM_regB (.in(AluBBypassResult), .out(stageM_reg_B_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(34, 34'b0) stageM_regIR (.in(XM_decode_bus), .out(MW_decode_bus), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b0)   stageM_regNZP (.in(nzp_new_bits), .out(MW_nzp_bits), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(2, 2'b10) stageM_regStall (.in(XM_stallCode), .out(MW_stallCode), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(16, 16'b0) stageW_regPC (.in(MW_pc), .out(W_pc_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) stageW_regO (.in(stageM_reg_O_out), .out(stageW_reg_O_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) stageW_regD (.in(i_cur_dmem_data), .out(stageW_reg_D_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(34, 34'b0) stageW_regIR (.in(MW_decode_bus), .out(Wout_decode_bus), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b0)   stageW_regNZP (.in(MW_nzp_bits), .out(test_nzp_new_bits), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(2, 2'b10) stageW_regStall (.in(MW_stallCode), .out(test_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   assign stageX_reg_A_input = ((Wout_decode_bus[27:25] == DX_decode_bus[33:31]) && Wout_decode_bus[22])
                                       ? W_result : rsrc1_val;              
   assign stageX_reg_B_input = ((Wout_decode_bus[27:25] == DX_decode_bus[30:28]) && Wout_decode_bus[22])
                                       ? W_result : rsrc2_val;
   
   assign AluABypassResult =  ((XM_decode_bus[33:31] == MW_decode_bus[27:25]) && (MW_decode_bus[22] == 1)) ? stageM_reg_O_out:  // should not be return two bit, should return real result of mux
                              ((XM_decode_bus[33:31] == Wout_decode_bus[27:25]) && Wout_decode_bus[22] == 1) ? W_result:
                              stageX_reg_A_out;
                              
   assign AluBBypassResult =  ((XM_decode_bus[30:28] == MW_decode_bus[27:25]) && MW_decode_bus[22] == 1) ? stageM_reg_O_out:  // should not be return two bit, should return real result of mux
                              ((XM_decode_bus[30:28] == Wout_decode_bus[27:25]) && Wout_decode_bus[22] == 1) ? W_result:
                              stageX_reg_B_out;

   assign WMBypassResult = ((MW_decode_bus[18]) && (Wout_decode_bus[27:25] == MW_decode_bus[30:28])) ? W_result:
                           stageM_reg_B_out;
   

   assign loadToUse =  (XM_decode_bus[19]) && 
                           ( (DX_decode_bus[33:31] == XM_decode_bus[27:25]) || 
                              ((DX_decode_bus[30:28] == XM_decode_bus[27:25]) && (~DX_decode_bus[18])) );
   
   assign DX_decode_bus[15:0] = stageD_IR_reg_out;


   assign stageD_reg_stall_input = (X_branch_taken_or_control == 1) ? 2'd2 : 
                                       (loadToUse == 1) ? 2'd3 :
                                       2'd0;

   assign DX_stallCode = (X_branch_taken_or_control == 1) ? 2'd2 : stageD_reg_stall_out;

   // XM_decode_bus, MW_decode_bus, are used implicitly in register declarations
   // Wout_decode_bus gets connect to main_regfile
   // DX_pc are used implicitly in register declarations
   
   assign W_result = (Wout_decode_bus[19] == 1) ? stageW_reg_D_out :  //Wout_decode_bus[19] = is_load
                     stageW_reg_O_out;
   
   
   assign stageX_IR_input = ((loadToUse | X_branch_taken_or_control) == 1) ? {34{1'b0}}:
                             DX_decode_bus;
   assign stageD_IR_input = (X_branch_taken_or_control == 1) ? {16{1'b0}} : i_cur_insn;

   assign stageM_reg_O_input = (XM_decode_bus[16] == 1) ? DX_pc : alu_output; // need to do this because trap returns pc+1 for R7. Don't know why, but this makes things work
   //SPENCER YOU GOATED
   
   // handle branching and control signals
   assign nzp_new_bits = ($signed(alu_output) > 0) ? 3'b001:
                                  (alu_output == 0) ? 3'b010: 3'b100;

   Nbit_reg nzp_reg (
      .in(nzp_new_bits), 
      .out(bu_nzp_bus),
      .clk(clk),
      .we(XM_decode_bus[21]), //XM_decode_bus[21] = nzp_we
      .gwe(gwe),
      .rst(rst)
      );
   defparam nzp_reg.n = 3;

   wire bu_nzp_reduced, X_branch_taken_or_control;
   wire [2:0] nzp_new_bits, bu_nzp_bus, bu_nzp_and;

   assign bu_nzp_and = bu_nzp_bus & XM_decode_bus[11:9]; //get sub-op from XM_decode_bus insn
   assign bu_nzp_reduced = |bu_nzp_and;
   assign X_branch_taken_or_control = (bu_nzp_reduced & XM_decode_bus[17]) || XM_decode_bus[16]; //XM_decode_bus[17] = is_branch. XM_decode_bus[16] = is_control
   assign next_pc = (X_branch_taken_or_control == 1) ? alu_output : Fout_pc_plus_one;
   // end of branch handling



   assign o_cur_pc = Fout_pc;
   assign o_dmem_addr = ((Wout_decode_bus[19] == 1) || (Wout_decode_bus[18] == 1)) ? stageM_reg_O_out : 16'b0;                   
   assign o_dmem_we = Wout_decode_bus[18];
   assign o_dmem_towrite = WMBypassResult;
   //assign test_stall = 2'b0;        //assigned in stageW_reg_Stall       
   assign test_cur_pc = W_pc_out;              
   assign test_cur_insn = Wout_decode_bus[15:0];
   assign test_regfile_we = Wout_decode_bus[22];
   assign test_regfile_wsel = Wout_decode_bus[27:25];
   assign test_regfile_data = W_result;
   assign test_nzp_we = Wout_decode_bus[21];
   //assign test_nzp_new_bits  //assigned in stage_W_regNZP
   assign test_dmem_we = o_dmem_we;
   assign test_dmem_addr = o_dmem_addr;
   assign test_dmem_data = (Wout_decode_bus[19] == 1) ? i_cur_dmem_data :
                           (Wout_decode_bus[18] == 1) ? o_dmem_towrite : 16'b0; //MUST FIX ISSUE WITH LINE ABOVE
   
   /* STUDENT CODE ENDS */










   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    *
    * You may also use if statements inside the always block
    * to conditionally print out information.
    *
    * You do not need to resynthesize and re-implement if this is all you change;
    * just restart the simulation.
    * 
    * To disable the entire block add the statement
    * `define NDEBUG
    * to the top of your file.  We also define this symbol
    * when we run the grading scripts.
    */
`ifndef NDEBUG
   always @(posedge gwe) begin
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
      // run it for that many nano-seconds, then set
      // the breakpoint.

      // In the objects view, you can change the values to
      // hexadecimal by selecting all signals (Ctrl-A),
      // then right-click, and select Radix->Hexadecial.

      // To see the values of wires within a module, select
      // the module in the hierarchy in the "Scopes" pane.
      // The Objects pane will update to display the wires
      // in that module.

      // $display();
   end
`endif
endmodule

