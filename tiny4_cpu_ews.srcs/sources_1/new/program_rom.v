`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/21/2026 12:29:24 AM
// Design Name: 
// Module Name: program_rom
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
module program_rom (
    input [3:0] addr,
    output reg [7:0] instruction
);
    always @(*) begin
        case (addr)
            4'h0: instruction = 8'h10; // LDI 0
            4'h1: instruction = 8'hB0; // OUT
            4'h2: instruction = 8'hC1; // ADDI 1
            4'h3: instruction = 8'hA6; // JZ 6
            4'h4: instruction = 8'hB0; // OUT
            4'h5: instruction = 8'h92; // JMP 2
            4'h6: instruction = 8'hFF; // HLT
            default: instruction = 8'h00;
        endcase
    end
endmodule

