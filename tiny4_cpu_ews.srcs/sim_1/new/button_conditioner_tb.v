`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/19/2026 03:35:54 PM
// Design Name: 
// Module Name: button_conditioner_tb
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


module button_conditioner_tb(

    );
    reg clk, raw_in;
    wire clean_level, press_pulse;
    
        button_conditioner #(
        .DEBOUNCE_CYCLES(4)
    ) BC (
            .clk(clk),
            .raw_in(raw_in),
            .clean_level(clean_level),
            .press_pulse(press_pulse)
        );
                            
   
    
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        raw_in = 1'b0;
        #20;
        
        // Simulate bouncing during a press
        @(negedge clk);
        raw_in = 1'b1;
        
        @(negedge clk);
        raw_in = 1'b0;
        
        @(negedge clk);
        raw_in = 1'b1;
        
        @(negedge clk);
        raw_in = 1'b0;
        
        // Finally settle HIGH
        @(negedge clk);
        raw_in = 1'b1;
        
        // Leave it high long enough to be accepted
        repeat (10) @(posedge clk);
        
        
        @(negedge clk);
raw_in = 1'b0;

@(negedge clk);
raw_in = 1'b1;

@(negedge clk);
raw_in = 1'b0;

@(negedge clk);
raw_in = 1'b1;

// Finally settle LOW
@(negedge clk);
raw_in = 1'b0;

// Give synchronizer + debounce enough time
repeat (10) @(posedge clk);
#1;

if (clean_level !== 1'b0)
    $display("ERROR: clean_level did not return LOW after release");
else
    $display("PASS: release successfully debounced");

if (press_pulse !== 1'b0)
    $display("ERROR: press_pulse occurred during release");


// ------------------------------------------------------------
// TEST: SECOND PRESS
// ------------------------------------------------------------

// Simulate bouncing again
        @(negedge clk);
        raw_in = 1'b1;
        
        @(negedge clk);
        raw_in = 1'b0;
        
        @(negedge clk);
        raw_in = 1'b1;
        
        @(negedge clk);
        raw_in = 1'b0;
        
        // Finally settle HIGH
        @(negedge clk);
        raw_in = 1'b1;
        
        // Wait until clean_level becomes accepted HIGH
        wait (clean_level === 1'b1);

        // The pulse occurs one clock after clean_level rises
        @(posedge clk);
        #1;
        
        if (press_pulse !== 1'b1)
            $display("ERROR: second press did not generate a pulse");
        else
            $display("PASS: second press generated one pulse");
        
        // Next clock: pulse must return LOW
        @(posedge clk);
        #1;
        
        if (press_pulse !== 1'b0)
            $display("ERROR: press_pulse lasted more than one clock");
        else
            $display("PASS: second press pulse lasted exactly one clock");
        
        // Hold the button HIGH for several clocks.
        // No extra pulses should occur.
        repeat (5) begin
            @(posedge clk);
            #1;
        
            if (press_pulse !== 1'b0)
                $display("ERROR: repeated pulse while button held");
        end
                
        $finish;
    end
    
endmodule
