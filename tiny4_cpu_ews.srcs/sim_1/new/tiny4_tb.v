`timescale 1ns / 1ps

// Behavioral RTL test for the CURRENT ROM contents:
//   ROM[0] = 8'h13;  // LDI 3
//   ROM[1] = 8'hC2;  // ADDI 2
//   ROM[2] = 8'hB0;  // OUT
//   ROM[3] = 8'hF0;  // HLT
// Does not modify the ROM or force any internal CPU signals.

module tiny4_tb;

    reg clk, reset, cpu_enable;
    wire [3:0] PROG_OUT;
    wire HALT;
    integer checks, errors;

    localparam [1:0] FETCH = 2'b00;
    localparam [1:0] EXECUTE = 2'b10;
    localparam [1:0] HALTED_STATE = 2'b11;

    tiny4 TINY4 (
        .clk(clk),
        .reset(reset),
        .cpu_enable(cpu_enable),
        .output_val(PROG_OUT),
        .halted(HALT)
    );

    // Observe existing internal signals; these do not drive the CPU.
    wire [24:0] cpu_snapshot;
    wire [7:0] update_controls;

    assign cpu_snapshot = {
        TINY4.CTRL.state, TINY4.pc_value, TINY4.ir_word,
        TINY4.acc_value, PROG_OUT,
        TINY4.zero_flag, TINY4.carry_flag, HALT
    };

    assign update_controls = {
        TINY4.pc_enable, TINY4.pc_load, TINY4.pc_increment,
        TINY4.ir_load, TINY4.acc_load, TINY4.ram_we,
        TINY4.out_load, TINY4.flags_load
    };

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Prevent an unfinished test from running forever.
    initial begin
        #5000;
        $display("FAIL: Timeout -- the test did not finish within 5000 ns.");
        $finish;
    end

    // Case inequality treats unexpected X/Z values as failures.
    task check_value;
        input [8*80-1:0] label;
        input [31:0] actual;
        input [31:0] expected;
        begin
            checks = checks + 1;
            if (actual !== expected) begin
                errors = errors + 1;
                $display("FAIL @ %0t: %0s expected=%h, got=%h",
                         $time, label, expected, actual);
            end
        end
    endtask

    // Sample after the rising-edge nonblocking assignments have settled.
    task cycles;
        input integer count;
        begin
            repeat (count) @(posedge clk);
            #1;
        end
    endtask

    // Check instruction-boundary state. For THIS program Z and C stay 0.
    task check_cpu;
        input [8*80-1:0] label;
        input [1:0] expected_state;
        input [3:0] expected_pc;
        input [7:0] expected_ir;
        input [3:0] expected_acc;
        input [3:0] expected_out;
        input expected_halt;
        integer previous_errors;
        begin
            previous_errors = errors;
            $display("\nCHECK: %0s", label);
            check_value("FSM state", TINY4.CTRL.state, expected_state);
            check_value("PC", TINY4.pc_value, expected_pc);
            check_value("IR", TINY4.ir_word, expected_ir);
            check_value("Accumulator", TINY4.acc_value, expected_acc);
            check_value("Program output", PROG_OUT, expected_out);
            check_value("Stored zero flag", TINY4.zero_flag, 1'b0);
            check_value("Stored carry flag", TINY4.carry_flag, 1'b0);
            check_value("HALT", HALT, expected_halt);
            if (errors == previous_errors)
                $display("PASS: %0s", label);
        end
    endtask

    // Reset while disabled, then leave the CPU paused in FETCH.
    task reset_cpu;
        begin
            @(negedge clk);
            reset = 1'b1;
            cpu_enable = 1'b0;
            cycles(2);
            check_cpu("Reset", FETCH, 4'h0, 8'h00, 4'h0, 4'h0, 1'b0);
            check_value("Update controls during reset", update_controls, 8'h00);
            @(negedge clk);
            reset = 1'b0;
        end
    endtask

    // Pause at a falling edge. Leave cpu_enable LOW on return.
    task pause_cpu;
        input integer count;
        reg [24:0] saved_snapshot;
        integer previous_errors;
        begin
            previous_errors = errors;
            @(negedge clk);
            saved_snapshot = cpu_snapshot;
            cpu_enable = 1'b0;
            #1;
            check_value("Paused controls", update_controls, 8'h00);

            repeat (count) begin
                cycles(1);
                check_value("State held while paused", cpu_snapshot, saved_snapshot);
                check_value("Writes disabled while paused", update_controls, 8'h00);
            end

            if (errors == previous_errors)
                $display("PASS: CPU held for %0d paused clock edges.", count);
        end
    endtask

    task run_demo;
        input pause_during_addi;
        reg [24:0] halted_snapshot;
        integer previous_errors;
        begin
            // Caller has reset the CPU and left it disabled in FETCH.
            @(negedge clk);
            cpu_enable = 1'b1;

            // FETCH + DECODE + EXECUTE: LDI 3.
            cycles(3);
            check_cpu("LDI 3", FETCH, 4'h1, 8'h13, 4'h3, 4'h0, 1'b0);

            if (pause_during_addi) begin
                // Enter EXECUTE for ADDI, but do not execute it yet.
                cycles(2);
                check_cpu("Before ADDI execution", EXECUTE,
                          4'h2, 8'hC2, 4'h3, 4'h0, 1'b0);

                pause_cpu(3);

                // Resume; the next edge executes ADDI exactly once.
                @(negedge clk);
                cpu_enable = 1'b1;
                cycles(1);
            end
            else begin
                cycles(3);
            end

            check_cpu("ADDI 2", FETCH, 4'h2, 8'hC2, 4'h5, 4'h0, 1'b0);

            cycles(3);
            check_cpu("OUT", FETCH, 4'h3, 8'hB0, 4'h5, 4'h5, 1'b0);

            previous_errors = errors;
            cycles(3);
            check_cpu("HLT", HALTED_STATE, 4'h4, 8'hF0,
                      4'h5, 4'h5, 1'b1);

            // Keep execution enabled: HALT itself must prevent updates.
            halted_snapshot = cpu_snapshot;
            check_value("HALT controls", update_controls, 8'h00);
            repeat (10) begin
                cycles(1);
                check_value("State held after HALT", cpu_snapshot, halted_snapshot);
                check_value("Writes disabled after HALT", update_controls, 8'h00);
            end
            if (errors == previous_errors)
                $display("PASS: HALT held for 10 clock edges while enabled.");
        end
    endtask

    // Main test sequence.
    initial begin
        reset      = 1'b1;
        cpu_enable = 1'b0;
        checks     = 0;
        errors     = 0;

        $display("=== RUN 1: Reset, pause in FETCH, and execute demo ===");
        reset_cpu;
        pause_cpu(2);
        run_demo(1'b0);

        $display("\n=== RUN 2: Reset out of HALT, restart, pause during ADDI ===");
        reset_cpu;
        run_demo(1'b1);

        $display("\n==================================================");
        if (errors == 0)
            $display("PASS: Tiny4 demo-program suite -- %0d checks, 0 failures.", checks);
        else
            $display("FAIL: Tiny4 demo-program suite -- %0d failure(s) in %0d checks.",
                     errors, checks);
        $display("==================================================");
        $finish;
    end

endmodule