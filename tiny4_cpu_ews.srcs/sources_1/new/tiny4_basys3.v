`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/19/2026 08:00:48 AM
// Design Name: 
// Module Name: tiny4_basys3
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


module tiny4_basys3 #(
    parameter integer PULSE_CYCLES = 50_000_000,
    parameter integer DEBOUNCE_CYCLES = 1_000_000
)(
    input clk,
    input btn_reset,
    input btn_step,
    input run_switch,
    output [3:0] led,
    output halted_led,
    output [6:0] seg,
    output [3:0] an,
    output dp
);
    //input conditioning
    wire cpu_reset, step_pulse, run_mode, cpu_enable;
    button_conditioner #(
        .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)
        ) RESET_COND (
            .clk(clk),
            .raw_in(btn_reset),
            .clean_level(cpu_reset),
            .press_pulse()
        );
        
        button_conditioner #(
            .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)
        ) STEP_COND (
            .clk(clk),
            .raw_in(btn_step),
            .clean_level(),
            .press_pulse(step_pulse)
        );
        
        button_conditioner #(
            .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)
        ) RUN_COND (
            .clk(clk),
            .raw_in(run_switch),
            .clean_level(run_mode),
            .press_pulse()
        );
            
    
    
    
    assign an = 4'b1110;
    assign dp = 1'b1;

    reg [25:0] counter = 26'd0;
    reg slow_pulse = 1'b0;
    
    //Cpu enable logic
    always @(posedge clk) begin
        // Normally, the NEXT value of the pulse is zero.
        slow_pulse <= 1'b0;
    
        if (cpu_reset || !run_mode) begin
            // TODO: clear the counter.
            // slow_pulse already defaults to zero.
            counter <= 0;
        end
        else if (counter == PULSE_CYCLES - 1) begin
            // TODO: restart the counter at zero.
            // TODO: set slow_pulse to one for this clock interval.
            counter <= 0;
            slow_pulse <= 1'b1;
        end
        else begin
            // TODO: increment the counter.
            counter <= counter + 1'b1;
        end
    end
    
   assign cpu_enable = cpu_reset ? 1'b0 : (run_mode ? slow_pulse : step_pulse);
   
   wire [3:0] cpu_out;
   wire cpu_halted;
   tiny4 CPU(.clk(clk),
            .reset(cpu_reset),
            .cpu_enable(cpu_enable),
            .output_val(cpu_out),
            .halted(cpu_halted));
   assign led = cpu_out;
   assign halted_led = cpu_halted;
   hex_to_7seg HX(.hex(cpu_out), .seg(seg));
    
endmodule
