`timescale 1ns / 1ps

// Behavioral CPU-level test for the accompanying branch-test ROM.
// Expected fetched addresses (hex): 0,4,5,6,7,8,9,C,D,9,A,B.
// No internal CPU signals are forced or written by the testbench.
module tiny4_branch_tb;

    reg clk, reset, cpu_enable;
    wire [3:0] PROG_OUT;
    wire HALT;
    integer checks, errors, instructions;

    tiny4 TINY4 (
        .clk(clk), .reset(reset), .cpu_enable(cpu_enable),
        .output_val(PROG_OUT), .halted(HALT)
    );

    wire [7:0] update_controls;
    assign update_controls = {
        TINY4.pc_enable, TINY4.pc_load, TINY4.pc_increment,
        TINY4.ir_load, TINY4.acc_load, TINY4.ram_we,
        TINY4.out_load, TINY4.flags_load
    };

    reg [3:0] expected_pc, expected_acc, expected_out;
    reg [7:0] expected_ir;
    reg expected_zero, expected_carry;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        #5000;
        $display("FAIL: Branch suite timed out at 5000 ns.");
        $finish;
    end

    task check_value;
        input [8*64-1:0] label;
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

    task tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task check_data;
        begin
            check_value("Accumulator", TINY4.acc_value, expected_acc);
            check_value("Program output", PROG_OUT, expected_out);
            check_value("Stored zero", TINY4.zero_flag, expected_zero);
            check_value("Stored carry", TINY4.carry_flag, expected_carry);
            // This program never stores to RAM.
            check_value("No RAM write", TINY4.ram_we, 1'b0);
        end
    endtask

    task run_instruction;
        input [8*40-1:0] label;
        input [7:0] expected_word;
        input [3:0] pc_after;
        input [3:0] acc_after;
        input zero_after;
        input carry_after;
        input [3:0] out_after;

        reg [3:0] sequential_pc;
        reg [7:0] expected_execute_controls;
        integer errors_before;

        begin
            errors_before = errors;
            instructions = instructions + 1;
            sequential_pc = expected_pc + 4'd1;
            expected_execute_controls = 8'h00;

            // Order: PCen, PCload, PCinc, IRload, ACCload, RAMwe, OUTload, FLAGSload.
            case (expected_word[7:4])
                4'h1, 4'hC: expected_execute_controls = 8'h09; // A + flags
                4'hB:       expected_execute_controls = 8'h02; // Output
                4'h9:       expected_execute_controls = 8'hC0; // PC enable + load
                4'hA: begin
                    if (expected_zero)
                        expected_execute_controls = 8'hC0;
                end
                default: expected_execute_controls = 8'h00;
            endcase

            $display("\nCHECK: PC=%h, %0s", expected_pc, label);
            check_value("State before FETCH", TINY4.CTRL.state, 2'b00);
            check_value("PC before FETCH", TINY4.pc_value, expected_pc);
            check_value("ROM word", TINY4.rom_word, expected_word);
            check_value("FETCH controls", update_controls, 8'hB0);

            // FETCH: IR captures this instruction, PC increments normally.
            tick;
            check_value("DECODE state", TINY4.CTRL.state, 2'b01);
            check_value("PC after FETCH", TINY4.pc_value, sequential_pc);
            check_value("IR after FETCH", TINY4.ir_word, expected_word);
            check_value("DECODE controls", update_controls, 8'h00);
            check_value("Not halted during DECODE", HALT, 1'b0);
            check_data;

            // DECODE: enter EXECUTE, but do not commit its action yet.
            tick;
            check_value("EXECUTE state", TINY4.CTRL.state, 2'b10);
            check_value("PC before execution", TINY4.pc_value, sequential_pc);
            check_value("IR before execution", TINY4.ir_word, expected_word);
            check_value("EXECUTE controls", update_controls, expected_execute_controls);
            check_value("Not halted before execution", HALT, 1'b0);
            check_data;

            // Pause each JMP/JZ before its execution edge.
            if (expected_word[7:4] == 4'h9 || expected_word[7:4] == 4'hA) begin
                @(negedge clk);
                cpu_enable = 1'b0;
                #1;
                check_value("Controls clear when paused", update_controls, 8'h00);

                repeat (2) begin
                    tick;
                    check_value("Paused EXECUTE state", TINY4.CTRL.state, 2'b10);
                    check_value("Paused PC", TINY4.pc_value, sequential_pc);
                    check_value("Paused IR", TINY4.ir_word, expected_word);
                    check_value("Paused controls", update_controls, 8'h00);
                    check_value("Not halted while paused", HALT, 1'b0);
                    check_data;
                end

                @(negedge clk);
                cpu_enable = 1'b1;
                #1;
                check_value("Controls after resume", update_controls,
                            expected_execute_controls);
            end

            // EXECUTE edge: commit the instruction's effects.
            tick;
            expected_pc    = pc_after;
            expected_ir    = expected_word;
            expected_acc   = acc_after;
            expected_zero  = zero_after;
            expected_carry = carry_after;
            expected_out   = out_after;

            check_value("PC after execution", TINY4.pc_value, expected_pc);
            check_value("IR after execution", TINY4.ir_word, expected_ir);

            if (expected_word[7:4] == 4'hF) begin
                check_value("HALT state", TINY4.CTRL.state, 2'b11);
                check_value("HALT output", HALT, 1'b1);
                check_value("HALT controls", update_controls, 8'h00);
            end
            else begin
                check_value("Return to FETCH", TINY4.CTRL.state, 2'b00);
                check_value("Not halted", HALT, 1'b0);
                check_value("Next FETCH controls", update_controls, 8'hB0);
            end
            check_data;

            if (errors == errors_before)
                $display("PASS: %0s -> PC=%h A=%h Z=%b C=%b OUT=%h",
                         label, expected_pc, expected_acc,
                         expected_zero, expected_carry, expected_out);
            else
                $display("FAIL: %0s", label);
        end
    endtask

    initial begin
        reset = 1'b1;
        cpu_enable = 1'b0;
        checks = 0;
        errors = 0;
        instructions = 0;
        expected_pc = 4'h0;
        expected_ir = 8'h00;
        expected_acc = 4'h0;
        expected_out = 4'h0;
        expected_zero = 1'b0;
        expected_carry = 1'b0;

        $display("=== Tiny4 JMP/JZ branch suite ===");
        tick;
        check_value("Reset state", TINY4.CTRL.state, 2'b00);
        check_value("Reset PC", TINY4.pc_value, 4'h0);
        check_value("Reset IR", TINY4.ir_word, 8'h00);
        check_value("Reset HALT", HALT, 1'b0);
        check_value("Reset controls", update_controls, 8'h00);
        check_data;

        @(negedge clk);
        reset = 1'b0;
        cpu_enable = 1'b1;
        #1;

        // Arguments: label, word, PC afterward, A afterward, Z, C, output.
        // The expected instruction stream is explicit, not derived from DUT PC.
        run_instruction("JMP 4: forward",
                        8'h94, 4'h4, 4'h0, 1'b0, 1'b0, 4'h0);
        run_instruction("LDI 15",
                        8'h1F, 4'h5, 4'hF, 1'b0, 1'b0, 4'h0);
        run_instruction("ADDI 1: set Z and C",
                        8'hC1, 4'h6, 4'h0, 1'b1, 1'b1, 4'h0);
        run_instruction("OUT: preserve Z and C",
                        8'hB0, 4'h7, 4'h0, 1'b1, 1'b1, 4'h0);
        run_instruction("NOP: preserve flags",
                        8'h00, 4'h8, 4'h0, 1'b1, 1'b1, 4'h0);
        run_instruction("RESERVED: preserve flags",
                        8'hE0, 4'h9, 4'h0, 1'b1, 1'b1, 4'h0);
        run_instruction("JZ C: TAKEN",
                        8'hAC, 4'hC, 4'h0, 1'b1, 1'b1, 4'h0);
        run_instruction("LDI 5: clear Z and C",
                        8'h15, 4'hD, 4'h5, 1'b0, 1'b0, 4'h0);
        run_instruction("JMP 9: backward",
                        8'h99, 4'h9, 4'h5, 1'b0, 1'b0, 4'h0);
        run_instruction("JZ C: NOT TAKEN",
                        8'hAC, 4'hA, 4'h5, 1'b0, 1'b0, 4'h0);
        run_instruction("OUT 5",
                        8'hB0, 4'hB, 4'h5, 1'b0, 1'b0, 4'h5);
        run_instruction("HLT",
                        8'hF0, 4'hC, 4'h5, 1'b0, 1'b0, 4'h5);

        $display("\nCHECK: HALT holds with cpu_enable still high");
        repeat (10) begin
            tick;
            check_value("Held HALT state", TINY4.CTRL.state, 2'b11);
            check_value("Held HALT output", HALT, 1'b1);
            check_value("Held PC", TINY4.pc_value, 4'hC);
            check_value("Held IR", TINY4.ir_word, 8'hF0);
            check_value("No updates while halted", update_controls, 8'h00);
            check_data;
        end

        $display("\n==================================================");
        if (errors == 0)
            $display("PASS: Tiny4 branch suite -- %0d instructions, %0d checks, 0 failures.",
                     instructions, checks);
        else
            $display("FAIL: Tiny4 branch suite -- %0d failure(s) in %0d checks.",
                     errors, checks);
        $display("==================================================");
        $finish;
    end
endmodule