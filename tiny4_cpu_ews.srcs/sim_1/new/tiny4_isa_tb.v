`timescale 1ns / 1ps

// CPU-level memory/ALU regression for the accompanying program_rom.v.
// Uses the actual CPU and ROM. Does not force signals or write DUT RAM.
// Run as the simulation top, instead of the old demo testbench.
module tiny4_isa_tb;

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

    // Expected architectural state, maintained only by the testbench.
    reg [3:0] expected_pc, expected_acc, expected_out;
    reg expected_zero, expected_carry;
    reg [3:0] expected_ram [0:15];
    reg [15:0] ram_known;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // A broken clock or stalled test must not run forever.
    initial begin
        #5000;
        $display("FAIL: Memory/ALU suite timed out at 5000 ns.");
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
            #1; // Observe registers after their nonblocking updates.
        end
    endtask

    // Check data registers and every RAM word initialized by this program.
    // Unwritten RAM locations are intentionally not assumed to be zero.
    task check_data;
        integer address;
        begin
            check_value("Accumulator", TINY4.acc_value, expected_acc);
            check_value("Program output", PROG_OUT, expected_out);
            check_value("Stored zero", TINY4.zero_flag, expected_zero);
            check_value("Stored carry/borrow", TINY4.carry_flag, expected_carry);

            for (address = 0; address < 16; address = address + 1) begin
                if (ram_known[address]) begin
                    checks = checks + 1;

                    if (TINY4.RAM.mem[address] !== expected_ram[address]) begin
                        errors = errors + 1;
                        $display("FAIL @ %0t: RAM[%0d] expected=%h, got=%h",
                                 $time, address, expected_ram[address],
                                 TINY4.RAM.mem[address]);
                    end
                end
            end
        end
    endtask

    // Run one real instruction through FETCH, DECODE, and EXECUTE.
    task run_instruction;
        input [8*32-1:0] label;
        input [7:0] expected_word;
        input [3:0] acc_after;
        input zero_after;
        input carry_after;
        input [3:0] out_after;

        integer errors_before;

        begin
            errors_before = errors;
            instructions = instructions + 1;
            $display("\nCHECK: PC=%h, %0s", expected_pc, label);

            check_value("State before fetch", TINY4.CTRL.state, 2'b00);
            check_value("PC before fetch", TINY4.pc_value, expected_pc);
            check_value("ROM instruction", TINY4.rom_word, expected_word);

            // FETCH edge: PC increments and IR captures the old address's word.
            tick;
            expected_pc = expected_pc + 4'd1;

            check_value("State after fetch", TINY4.CTRL.state, 2'b01);
            check_value("PC after fetch", TINY4.pc_value, expected_pc);
            check_value("IR after fetch", TINY4.ir_word, expected_word);
            check_value("Not halted after fetch", HALT, 1'b0);
            check_data; // Data registers/RAM must NOT change during FETCH.

            // DECODE edge: enter EXECUTE without committing its action yet.
            tick;
            check_value("State after decode", TINY4.CTRL.state, 2'b10);
            check_value("PC after decode", TINY4.pc_value, expected_pc);
            check_value("IR after decode", TINY4.ir_word, expected_word);
            check_data;

            // For every store, pause before the write edge and verify safety.
            if (expected_word[7:4] == 4'h3) begin
                @(negedge clk);
                cpu_enable = 1'b0;
                #1;

                check_value("Paused controls", update_controls, 8'h00);

                repeat (2) begin
                    tick;
                    check_value("Paused EXECUTE state",
                                TINY4.CTRL.state, 2'b10);
                    check_value("Paused PC", TINY4.pc_value, expected_pc);
                    check_value("Paused IR", TINY4.ir_word, expected_word);
                    check_value("Paused controls", update_controls, 8'h00);
                    check_data;
                end

                @(negedge clk);
                cpu_enable = 1'b1;
            end

            // EXECUTE edge: now the architectural result must be committed.
            tick;

            if (expected_word[7:4] == 4'h3) begin
                expected_ram[expected_word[3:0]] = expected_acc;
                ram_known[expected_word[3:0]] = 1'b1;
            end

            expected_acc   = acc_after;
            expected_zero  = zero_after;
            expected_carry = carry_after;
            expected_out   = out_after;

            check_value("PC after execute", TINY4.pc_value, expected_pc);
            check_value("IR after execute", TINY4.ir_word, expected_word);

            if (expected_word[7:4] == 4'hF) begin
                check_value("HALT state", TINY4.CTRL.state, 2'b11);
                check_value("HALT output", HALT, 1'b1);
            end
            else begin
                check_value("Return to FETCH", TINY4.CTRL.state, 2'b00);
                check_value("Not halted", HALT, 1'b0);
            end

            check_data;

            if (errors == errors_before)
                $display("PASS: %0s -> A=%h Z=%b C=%b OUT=%h",
                         label, expected_acc, expected_zero,
                         expected_carry, expected_out);
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
        expected_acc = 4'h0;
        expected_out = 4'h0;
        expected_zero = 1'b0;
        expected_carry = 1'b0;
        ram_known = 16'h0000;

        $display("=== Tiny4 memory/ALU program ===");

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

        // Arguments:
        // label, ROM word, accumulator after execution, Z, C/borrow, output

        run_instruction("LDI 9",
                        8'h19, 4'h9, 1'b0, 1'b0, 4'h0);

        run_instruction("STA 4",
                        8'h34, 4'h9, 1'b0, 1'b0, 4'h0);

        run_instruction("LDI 3",
                        8'h13, 4'h3, 1'b0, 1'b0, 4'h0);

        run_instruction("STA 5",
                        8'h35, 4'h3, 1'b0, 1'b0, 4'h0);

        run_instruction("LDA 4",
                        8'h24, 4'h9, 1'b0, 1'b0, 4'h0);

        run_instruction("ADD 5",
                        8'h45, 4'hC, 1'b0, 1'b0, 4'h0);

        run_instruction("SUB 4: no borrow",
                        8'h54, 4'h3, 1'b0, 1'b0, 4'h0);

        run_instruction("SUB 4: borrow",
                        8'h54, 4'hA, 1'b0, 1'b1, 4'h0);

        run_instruction("AND 5",
                        8'h65, 4'h2, 1'b0, 1'b0, 4'h0);

        run_instruction("OR 4",
                        8'h74, 4'hB, 1'b0, 1'b0, 4'h0);

        run_instruction("XOR 4",
                        8'h84, 4'h2, 1'b0, 1'b0, 4'h0);

        run_instruction("NOT",
                        8'hD0, 4'hD, 1'b0, 1'b0, 4'h0);

        run_instruction("OUT",
                        8'hB0, 4'hD, 1'b0, 1'b0, 4'hD);

        run_instruction("ADDI 3: carry and zero",
                        8'hC3, 4'h0, 1'b1, 1'b1, 4'hD);

        run_instruction("STA 6: preserve flags",
                        8'h36, 4'h0, 1'b1, 1'b1, 4'hD);

        run_instruction("HLT",
                        8'hF0, 4'h0, 1'b1, 1'b1, 4'hD);

        // HLT was fetched from address F, so the 4-bit PC has wrapped to 0.
        // Keep cpu_enable HIGH: HALT must prevent the program restarting.
        $display("\nCHECK: HALT holds with clock and cpu_enable still active");

        repeat (8) begin
            tick;
            check_value("Held HALT state", TINY4.CTRL.state, 2'b11);
            check_value("Held HALT output", HALT, 1'b1);
            check_value("Held PC", TINY4.pc_value, 4'h0);
            check_value("Held IR", TINY4.ir_word, 8'hF0);
            check_value("No writes while halted", update_controls, 8'h00);
            check_data;
        end

        // Reset clears CPU registers, but it must NOT clear the data RAM.
        $display("\nCHECK: Reset clears registers and preserves RAM");

        @(negedge clk);
        cpu_enable = 1'b0;
        reset = 1'b1;
        tick;

        expected_pc = 4'h0;
        expected_acc = 4'h0;
        expected_out = 4'h0;
        expected_zero = 1'b0;
        expected_carry = 1'b0;

        check_value("Reset from HALT", TINY4.CTRL.state, 2'b00);
        check_value("Reset PC", TINY4.pc_value, 4'h0);
        check_value("Reset IR", TINY4.ir_word, 8'h00);
        check_value("Reset HALT output", HALT, 1'b0);
        check_value("Reset controls", update_controls, 8'h00);
        check_data;

        $display("\n==================================================");
        if (errors == 0)
            $display("PASS: Tiny4 memory/ALU suite -- %0d instructions, %0d checks, 0 failures.",
                     instructions, checks);
        else
            $display("FAIL: Tiny4 memory/ALU suite -- %0d error(s) in %0d checks.",
                     errors, checks);
        $display("==================================================");

        $finish;
    end

endmodule