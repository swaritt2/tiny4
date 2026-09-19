`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/17/2026 10:49:08 PM
// Design Name: 
// Module Name: flags_register
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


module flags_register(
    input clk,
    input reset,
    input load,
    input zero_in,
    output reg zero_out,
    output reg carry_out,
    input carry_in
    );
    
    always @(posedge clk) begin
        if(reset) begin
            zero_out <= 1'b0;
            carry_out <= 1'b0;
        end
        else if(load) begin
            zero_out <= zero_in;
            carry_out <= carry_in;
        end
        
    end
endmodule
