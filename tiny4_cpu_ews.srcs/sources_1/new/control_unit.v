`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/24/2026 08:08:15 PM
// Design Name: 
// Module Name: control_unit
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


module control_unit(
    input clk,
    input reset,
    input cpu_enable,
    input [3:0]opcode,
    input zero_flag,
    output reg pc_enable,
    output reg pc_load,
    output reg pc_increment,
    output reg ir_load,
    output reg acc_load,
    output reg ram_we,
    output reg out_load,
    output reg flags_load,
    output reg [2:0] alu_op,
    output reg alu_src_imm,
    output reg halted
    );
    reg [1:0] state, next_state;
    //state transition logic
    parameter FETCH = 2'b00, DECODE = 2'b01, EXECUTE = 2'b10, HALT = 2'b11;

    always @(posedge clk) begin
    	if(reset) state <= FETCH;
    	else if(cpu_enable) state <= next_state;
	//otherwise it holds current state.
    end
    //Process 2:
    //safe defaults
    always @(*) begin
	    next_state = state;
	    pc_enable = 1'b0;
	    pc_load = 1'b0;
	    pc_increment = 1'b0;
	    ir_load = 1'b0;
	    acc_load = 1'b0;
	    ram_we = 1'b0;
	    out_load = 1'b0;
	    flags_load = 1'b0;
	    alu_op = 3'b111;
	    alu_src_imm = 1'b0;
	    halted = 1'b0;
	    
	    case(state)
	    	FETCH : begin
	    		next_state = DECODE;
	    		if(cpu_enable && !reset) begin
		    		ir_load = 1'b1;
		    		pc_enable = 1'b1;
		    		pc_increment = 1'b1;
		    		pc_load = 1'b0;
		    		
		    	end
	    	end
	    	
	    	DECODE : begin
	    		next_state = EXECUTE;
	    		
	    	end
	    	
	    	EXECUTE : begin
	    		next_state = FETCH;
	    		if(opcode == 4'b1111) next_state = HALT;
	    		
	    		if(cpu_enable && !reset) begin
	    		     case(opcode)
	    		         4'b0000 : begin //NOP
	    		             //no control overrides needed
	    		         end
	    		         
	    		         4'b0001 : begin //LDI
	    		             alu_src_imm = 1'b1; //ALU B source selection
	    		             alu_op = 3'b110; //ALU Operation = Pass B
	    		             acc_load = 1'b1; 
	    		             flags_load = 1'b1;	    		             
	    		         end
	    		         
	    		         4'b0010 : begin //LDA
	    		             alu_src_imm = 1'b0;
	    		             alu_op = 3'b110;
	    		             acc_load = 1'b1;
	    		             flags_load = 1'b1;
	    		         end
	    		         
	    		         4'b1011 : begin //OUT
	    		             out_load = 1'b1;
	    		         end
	    		         
	    		         4'b0100 : begin //ADD
	    		             //add RAM value to acc
	    		             acc_load = 1'b1;
	    		             alu_op = 3'b000;
	    		             alu_src_imm = 1'b0;
	    		             flags_load = 1'b1;
	    		         end
	    		         
	    		         4'b0101 : begin //SUB
	    		             acc_load = 1'b1;
	    		             alu_op = 3'b001;
	    		             alu_src_imm = 1'b0;
	    		             flags_load = 1'b1;
	    		         end
	    		         
	    		         4'b0110 : begin //AND
	    		             acc_load = 1'b1;
	    		             alu_op = 3'b010;
	    		             alu_src_imm = 1'b0;
	    		             flags_load = 1'b1;
	    		         end
	    		         
	    		         4'b0111 : begin //OR
	    		             acc_load = 1'b1;
	    		             alu_op = 3'b011;
	    		             alu_src_imm = 1'b0;
	    		             flags_load = 1'b1;
	    		         end
	    		         
	    		         4'b1000 : begin //XOR
	    		             acc_load = 1'b1;
	    		             alu_op = 3'b100;
	    		             alu_src_imm = 1'b0;
	    		             flags_load = 1'b1;
	    		         end
	    		         
	    		         4'b1100 : begin //ADDI
	    		             acc_load = 1'b1;
	    		             alu_op = 3'b000;
	    		             alu_src_imm = 1'b1;
	    		             flags_load = 1'b1;
	    		         end
	    		         
	    		         4'b1101 : begin //NOT
	    		             acc_load = 1'b1;
	    		             alu_op = 3'b101;
	    		             flags_load = 1'b1;
	    		         end
	    		         
	    		         4'b0011 : begin //STA
	    		             ram_we = 1'b1;
	    		         end
	    		         
	    		         4'b1001 : begin //JMP
	    		             pc_enable = 1'b1;
	    		             pc_load = 1'b1;
	    		         end
	    		         
	    		         4'b1010 : begin //JZ
	    		             if(zero_flag == 1'b1) begin 
	    		                 pc_load = 1'b1;
	    		                 pc_enable = 1'b1;
                             end
                             
	    		             else pc_load = 1'b0;
	    		         end
	    		         
	    		         default : begin
	    		         //keep safe defaults
	    		         // HLT's next_state was already handeled above
                            
	    		         end
	    		     endcase
	    		end
	    		
	    	end
	    	
	    	HALT : begin
	    		halted = 1'b1;
	    		next_state = HALT;
	    	end
	    	
	    	default : begin
	    		next_state = FETCH;
	    	end
	    endcase
    end
    //without defaults, the CLU could retain previous values and infer a latch...

    
endmodule
