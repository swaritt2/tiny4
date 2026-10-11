`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/20/2026 07:37:57 PM
// Design Name: 
// Module Name: program_counter
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


module program_counter(
    input clk,
    input reset,
    input enable,
    input increment,
    input load,
    input [3:0]load_addr,
    output reg [3:0]pc
    );
    
    always @(posedge clk) begin
    	if(reset == 1'b1) pc <= 4'b0000;
    	else if(enable == 1'b0) pc <= pc;
    	else if(enable == 1'b1 & load == 1'b1) pc <= load_addr;
    	else if(enable == 1'b1 & load == 1'b0 & increment == 1'b1) pc <= pc + 1'b1;
    	else pc <= pc;
    end
    
endmodule
