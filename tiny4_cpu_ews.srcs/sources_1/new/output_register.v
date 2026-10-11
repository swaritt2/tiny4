`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/21/2026 05:57:54 PM
// Design Name: 
// Module Name: output_register
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


module output_register(
    input clk,
    input reset,
    input load,
    input [3:0]in,
    output reg [3:0]out
    );
    
    always @(posedge clk) begin
    	if(reset) out <= 4'b0000;
    	else if(load) out <= in;
    end
endmodule
