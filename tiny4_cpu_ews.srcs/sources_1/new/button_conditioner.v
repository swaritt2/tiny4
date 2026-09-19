`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/19/2026 10:51:22 AM
// Design Name: 
// Module Name: button_conditioner
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


module button_conditioner(
    input clk,
    input raw_in,
    output reg clean_level,
    output reg press_pulse
    );
    reg [19:0] counter = 20'd0;   
    reg clean_prev = 1'b0;
    initial begin
        clean_level = 1'b0;
        press_pulse = 1'b0;
    end
    (* ASYNC_REG = "TRUE" *) reg sync_1 = 1'b0;
    (* ASYNC_REG = "TRUE" *) reg sync_2 = 1'b0;
    parameter integer DEBOUNCE_CYCLES = 1_000_000;
    
    //Clocked Section 1
    always @(posedge clk) begin
        sync_2 <= sync_1;
        sync_1 <= raw_in;
    end
    
    //Clocked Section 2
    always @(posedge clk) begin
        if(sync_2 == clean_level) counter <= 20'd0;
        else if(counter == DEBOUNCE_CYCLES - 1) begin
            clean_level <= sync_2;
            counter <= 20'd0;
        end
        else counter <= counter + 20'd1;
    end
    
    //Clocked Section 3
    always @(posedge clk) begin
        press_pulse <= clean_level & ~clean_prev;
        clean_prev <= clean_level;
    end
    
endmodule
