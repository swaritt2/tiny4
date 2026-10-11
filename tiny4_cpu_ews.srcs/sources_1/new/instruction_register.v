`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/21/2026 09:50:34 AM
// Design Name: 
// Module Name: instruction_register
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


module instruction_register(
    input [7:0]in,
    input load,
    input clk,
    input reset,
    output reg [7:0]out
    );
    always @(posedge clk) begin
    	if(reset == 1'b1) out <= 8'b00000000;
    	else if(load == 1'b1) out <= in;
    end
endmodule
