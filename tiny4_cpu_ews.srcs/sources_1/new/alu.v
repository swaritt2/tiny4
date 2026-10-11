`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/20/2026 02:30:25 AM
// Design Name: 
// Module Name: alu
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


module alu(
    input [3:0]a,
    input [3:0]b,
    input [2:0]op,
    output [3:0]result,
    output zero,
    output carry
    );
    reg [4:0]res;
    reg z;
    reg c;
    always @(*) begin
    	z = 1'b0;
    	c = 1'b0;
    	res = 5'b0;
    	case(op)
    		3'b000 : begin
    			res = a + b;
    			c = res[4]; end
    		3'b001 : begin
    			res = a - b;
    			if(a < b)
    				c = 1'b1; 
    			end
    		3'b010 : res = a & b;
    		3'b011 : res = a | b;
    		3'b100 : res = a ^ b;
    		3'b101 : res = ~a;
    		3'b110 : res = b;
    		3'b111 : res = a;
    	endcase
    	if(res[3:0] == 4'b0000)
    		z = 1'b1;
    	
    end
    assign result = res[3:0];  
    assign zero = z; 
    assign carry = c; 
    
endmodule
