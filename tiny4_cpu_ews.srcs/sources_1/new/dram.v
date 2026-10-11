`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/21/2026 02:52:41 PM
// Design Name: 
// Module Name: dram
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


module dram(
    input clk,
    input WE,
    input [3:0]addr,
    input [3:0]WD,
    output reg [3:0] RD
    );
    reg [3:0] mem[0:15];
    always @(*) begin
    	RD = mem[addr];
    end
    
    always @(posedge clk) begin
    	if(WE) mem[addr] <= WD;
    end
endmodule
