`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/17/2026 11:41:26 PM
// Design Name: 
// Module Name: tiny4
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tiny4(
    input clk,
    input reset,
    input cpu_enable,
    output [3:0] output_val,
    output halted
    );
    //internal datapath wires
    wire[3:0] pc_value;
    wire[7:0] rom_word;
    wire[7:0] ir_word;
    wire[3:0] operand;
    wire[3:0] opcode;
    wire[3:0] acc_value;
    wire[3:0] alu_b;
    wire[2:0] alu_op;
    wire[3:0] alu_result;
    wire[3:0] output_value;
    wire[3:0] ram_data;
    
    wire pc_enable, pc_load, pc_increment, ir_load, ram_we, acc_load, alu_zero, alu_carry, flags_load, zero_flag, carry_flag, alu_src_imm, out_load;
    
    assign opcode = ir_word[7:4];
    assign operand = ir_word[3:0];
    
    //PROGRAM COUNTER INSTANTIATION:
    program_counter PC(.clk(clk),
                        .load_addr(operand),
                        .enable(pc_enable),
                        .load(pc_load),
                        .increment(pc_increment),
                        .reset(reset),
                        .pc(pc_value));
    //ROM INSTANTIATION:             
    program_rom ROM(.addr(pc_value), .instruction(rom_word));
    
    //INSTRUCTION REGISTER INSTANTIATION:
    instruction_register IR(.in(rom_word),
                            .load(ir_load),
                            .clk(clk),
                            .reset(reset),
                            .out(ir_word));
                            
   //RAM INSTANTIATION:
   dram RAM(.clk(clk),
            .WE(ram_we),
            .addr(operand),
            .WD(acc_value),
            .RD(ram_data));
    
    //ALU INSTANTIATION:
    alu ALU(.a(acc_value),
            .b(alu_b),
            .op(alu_op),
            .result(alu_result),
            .zero(alu_zero),
            .carry(alu_carry));
            
    //ACCUMULATOR REGISTER INSTANTIATION:
    accumulator_register ACC(.clk(clk),
                            .reset(reset),
                            .load(acc_load),
                            .in(alu_result),
                            .out(acc_value));
    
    //FLAGS REGISTER INSTANTIATION:
    flags_register FLAGS(.clk(clk),
                          .reset(reset),
                          .load(flags_load),
                          .zero_in(alu_zero),
                          .carry_in(alu_carry),
                          .zero_out(zero_flag),
                          .carry_out(carry_flag));
                          
     //OUTPUT REGISTER INSTANTIATION:
     output_register OUT(.clk(clk),
                        .reset(reset),
                        .load(out_load),
                        .in(acc_value),
                        .out(output_value));
     
     //CONTROL UNIT INSTANTIATION:

     control_unit CTRL(.clk(clk),
                       .reset(reset),
                       .cpu_enable(cpu_enable),
                       .opcode(opcode),
                       .zero_flag(zero_flag),
                       .pc_enable(pc_enable),
                       .pc_load(pc_load),
                       .pc_increment(pc_increment),
                       .ir_load(ir_load),
                       .acc_load(acc_load),
                       .ram_we(ram_we),
                       .out_load(out_load),
                       .flags_load(flags_load),
                       .alu_op(alu_op),
                       .alu_src_imm(alu_src_imm),
                       .halted(halted));
    //MUX_B:
    assign alu_b = alu_src_imm ? operand : ram_data;
    assign output_val = output_value;
endmodule
