`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/17/2026 05:24:29 PM
// Design Name: 
// Module Name: control_unit_tb
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

module control_unit_tb;

    reg reset;
    reg cpu_enable;
    reg zero_flag;
    reg clk;
    reg [3:0] opcode;

    wire pc_enable;
    wire pc_increment;
    wire pc_load;
    wire ir_load;
    wire acc_load;
    wire ram_we;
    wire out_load;
    wire flags_load;
    wire alu_src_imm;
    wire halted;
    wire [2:0] alu_op;

    control_unit CLU(
        .clk(clk),
        .reset(reset),
        .cpu_enable(cpu_enable),
        .opcode(opcode),
        .zero_flag(zero_flag),
        .pc_enable(pc_enable),
        .pc_load(pc_load),
        .pc_increment(pc_increment),
        .ir_load(ir_load),
        .acc_load(acc_load),
        .ram_we(ram_we),
        .out_load(out_load),
        .flags_load(flags_load),
        .alu_op(alu_op),
        .alu_src_imm(alu_src_imm),
        .halted(halted)
    );
    // These declarations and the task go at MODULE LEVEL,
// not inside an initial or always block.

integer opcode_errors;
integer opcode_tests;

// Bundle all control outputs into one vector for comparison.
// Bit order: PC/IR controls | register writes | ALU op | source | halted
wire [12:0] opcode_controls;

assign opcode_controls = {
    pc_enable, pc_load, pc_increment, ir_load,
    acc_load, ram_we, out_load, flags_load,
    alu_op, alu_src_imm, halted
};

// Defaults from YOUR controller: no writes, PASS A, RAM source.
localparam [12:0] OPCODE_IDLE = 13'b0000_0000_111_0_0;


task check_opcode;
    input [8*12-1:0] test_name;
    input [3:0] test_opcode;
    input [2:0] expected_alu_op;
    input expected_imm;
    input expected_acc;
    input expected_flags;
    input expected_ram;
    input expected_out;

    reg [12:0] expected_controls;
    integer errors_before;

    begin
        errors_before = opcode_errors;
        opcode_tests = opcode_tests + 1;

        // These 13 instructions must not modify PC or IR during EXECUTE.
        expected_controls = {
            4'b0000,
            expected_acc, expected_ram, expected_out, expected_flags,
            expected_alu_op, expected_imm, 1'b0
        };

        // Start from a known state, even if earlier tests entered HALT.
        @(negedge clk);
        reset      = 1'b1;
        cpu_enable = 1'b0;
        opcode     = test_opcode;
        zero_flag  = 1'b0;

        @(posedge clk);
        #1;

        if (CLU.state !== 2'b00 || opcode_controls !== OPCODE_IDLE) begin
            opcode_errors = opcode_errors + 1;
            $display("ERROR %0s: reset/disabled FETCH incorrect.", test_name);
        end

        // Advance FETCH -> DECODE -> EXECUTE.
        @(negedge clk);
        reset      = 1'b0;
        cpu_enable = 1'b1;

        repeat (2) @(posedge clk);
        #1;

        if (CLU.state !== 2'b10) begin
            opcode_errors = opcode_errors + 1;
            $display("ERROR %0s: expected EXECUTE, got state=%b.",
                     test_name, CLU.state);
        end

        // Check BEFORE the next rising edge finishes EXECUTE.
        if (opcode_controls !== expected_controls) begin
            opcode_errors = opcode_errors + 1;
            $display("ERROR %0s: EXECUTE controls expected=%b, got=%b.",
                     test_name, expected_controls, opcode_controls);
        end

        // Pause in EXECUTE; no register or RAM writes may remain active.
        @(negedge clk);
        cpu_enable = 1'b0;
        #1;

        if (opcode_controls !== OPCODE_IDLE) begin
            opcode_errors = opcode_errors + 1;
            $display("ERROR %0s: controls did not clear when paused.",
                     test_name);
        end

        repeat (2) begin
            @(posedge clk);
            #1;

            if (CLU.state !== 2'b10 || opcode_controls !== OPCODE_IDLE) begin
                opcode_errors = opcode_errors + 1;
                $display("ERROR %0s: paused EXECUTE did not hold safely.",
                         test_name);
            end
        end

        // Resume: the same instruction controls must reappear.
        @(negedge clk);
        cpu_enable = 1'b1;
        #1;

        if (opcode_controls !== expected_controls) begin
            opcode_errors = opcode_errors + 1;
            $display("ERROR %0s: resumed controls expected=%b, got=%b.",
                     test_name, expected_controls, opcode_controls);
        end

        // This rising edge finishes EXECUTE.
        @(posedge clk);
        #1;

        if (CLU.state !== 2'b00) begin
            opcode_errors = opcode_errors + 1;
            $display("ERROR %0s: expected FETCH after EXECUTE.", test_name);
        end

        // Leave the FSM paused before starting another test.
        @(negedge clk);
        cpu_enable = 1'b0;
        #1;

        if (opcode_errors == errors_before)
            $display("PASS: %0s controls, pause/resume, and return to FETCH.",
                     test_name);
        else
            $display("FAIL: %0s.", test_name);
    end
endtask

    // 10 ns clock period
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin

        // Initialize ALL testbench-controlled signals
        reset      = 1'b1;
        cpu_enable = 1'b0;
        opcode     = 4'b0000;   // NOP
        zero_flag  = 1'b0;

        // =====================================================
        // TEST 1: RESET
        // =====================================================

        @(posedge clk);
        #1;

        if (CLU.state != 2'b00)
            $display("ERROR: Expected FETCH after reset.");
        else
            $display("PASS: Reset -> FETCH.");

        reset = 1'b0;


        // =====================================================
        // TEST 2: CPU DISABLED
        // =====================================================

        // cpu_enable remains 0
        @(posedge clk);
        #1;

        if (CLU.state != 2'b00)
            $display("ERROR: State changed while CPU disabled.");

        if (ir_load != 0 || pc_enable != 0 || pc_increment != 0)
            $display("ERROR: FETCH controls active while CPU disabled.");
        else
            $display("PASS: CPU holds while disabled.");


        // =====================================================
        // TEST 3: FETCH -> DECODE
        // =====================================================

        cpu_enable = 1'b1;
        opcode = 4'b0000;   // NOP

        // We are currently in FETCH.
        // Before the edge, FETCH controls should be asserted.
        #1;

        if (ir_load != 1'b1 ||
            pc_enable != 1'b1 ||
            pc_increment != 1'b1 ||
            pc_load != 1'b0)
            $display("ERROR: Incorrect FETCH control signals.");
        else
            $display("PASS: FETCH control signals correct.");

        @(posedge clk);
        #1;

        if (CLU.state != 2'b01)
            $display("ERROR: Expected DECODE.");
        else
            $display("PASS: FETCH -> DECODE.");


        // =====================================================
        // TEST 4: DECODE -> EXECUTE
        // =====================================================

        @(posedge clk);
        #1;

        if (CLU.state != 2'b10)
            $display("ERROR: Expected EXECUTE.");
        else
            $display("PASS: DECODE -> EXECUTE.");


        // =====================================================
        // TEST 5: NORMAL EXECUTE -> FETCH
        // =====================================================

        // opcode is still NOP

        @(posedge clk);
        #1;

        if (CLU.state != 2'b00)
            $display("ERROR: Expected FETCH after normal EXECUTE.");
        else
            $display("PASS: EXECUTE -> FETCH.");


        // =====================================================
        // TEST 6: HLT
        // =====================================================

        // FETCH -> DECODE
        @(posedge clk);
        #1;

        if (CLU.state != 2'b01)
            $display("ERROR: Expected DECODE before HLT test.");

        // Set HLT before entering EXECUTE.
        opcode = 4'b1111;

        // DECODE -> EXECUTE
        @(posedge clk);
        #1;

        if (CLU.state != 2'b10)
            $display("ERROR: Expected EXECUTE before HALT.");

        // EXECUTE -> HALT
        @(posedge clk);
        #1;

        if (CLU.state != 2'b11)
            $display("ERROR: Expected HALT state.");
        else
            $display("PASS: HLT enters HALT.");

        if (halted != 1'b1)
            $display("ERROR: halted signal should be 1 in HALT.");


        // =====================================================
        // TEST 7: HALT HOLDS
        // =====================================================

        @(posedge clk);
        #1;

        if (CLU.state != 2'b11)
            $display("ERROR: HALT state did not hold.");
        else
            $display("PASS: HALT state holds.");


        // =====================================================
        // TEST 8: RESET OUT OF HALT
        // =====================================================

        reset = 1'b1;

        @(posedge clk);
        #1;

        if (CLU.state != 2'b00)
            $display("ERROR: Reset did not return FSM to FETCH.");
        else
            $display("PASS: Reset returns HALT -> FETCH.");

            // Paste inside your EXISTING stimulus initial block, before $finish.
    begin : jump_tests
        integer test_id;
        integer errors;
        integer errors_before_test;
        reg [2:0] expected_pc_controls;

        errors = 0;

        // 0 = JMP, 1 = JZ taken, 2 = JZ not taken
        for (test_id = 0; test_id < 3; test_id = test_id + 1) begin
            errors_before_test = errors;

            // Reset each test, even if previous tests left us in HALT.
            @(negedge clk);
            reset      = 1'b1;
            cpu_enable = 1'b0;
            opcode     = 4'b1001;
            zero_flag  = 1'b0;

            // Expected order: {pc_enable, pc_load, pc_increment}
            expected_pc_controls = 3'b110;

            case (test_id)
                0: begin
                    $display("\n--- JMP ---");
                end
                1: begin
                    $display("\n--- JZ taken: zero_flag = 1 ---");
                    opcode    = 4'b1010;
                    zero_flag = 1'b1;
                end
                2: begin
                    $display("\n--- JZ not taken: zero_flag = 0 ---");
                    opcode = 4'b1010;
                    expected_pc_controls = 3'b000;
                end
            endcase

            @(posedge clk);
            #1;
            if (CLU.state !== 2'b00) begin
                errors = errors + 1;
                $display("ERROR: Reset did not produce FETCH.");
            end

            // Release reset and allow the FSM to advance.
            @(negedge clk);
            reset      = 1'b0;
            cpu_enable = 1'b1;

            @(posedge clk);
            #1;
            if (CLU.state !== 2'b01) begin
                errors = errors + 1;
                $display("ERROR: Expected DECODE after FETCH.");
            end

            @(posedge clk);
            #1;
            if (CLU.state !== 2'b10) begin
                errors = errors + 1;
                $display("ERROR: Expected EXECUTE after DECODE.");
            end

            // Check controls NOW, before the edge that finishes EXECUTE.
            if ({pc_enable, pc_load, pc_increment} !== expected_pc_controls) begin
                errors = errors + 1;
                $display("ERROR: PC controls expected=%b, got=%b",
                         expected_pc_controls,
                         {pc_enable, pc_load, pc_increment});
            end

            // A jump must not write other registers/RAM or assert halted.
            if ({ir_load, acc_load, flags_load, ram_we, out_load, halted}
                !== 6'b000000) begin
                errors = errors + 1;
                $display("ERROR: Unwanted non-PC control during EXECUTE.");
            end

            // Pause BEFORE the next rising edge can execute the jump.
            @(negedge clk);
            cpu_enable = 1'b0;
            #1;

            if ({pc_enable, pc_load, pc_increment,
                 ir_load, acc_load, flags_load, ram_we, out_load, halted}
                !== 9'b000000000) begin
                errors = errors + 1;
                $display("ERROR: Controls did not clear when paused.");
            end

            // Two clock edges while disabled: state and controls must hold.
            repeat (2) begin
                @(posedge clk);
                #1;
                if (CLU.state !== 2'b10 ||
                    {pc_enable, pc_load, pc_increment,
                     ir_load, acc_load, flags_load, ram_we, out_load, halted}
                    !== 9'b000000000) begin
                    errors = errors + 1;
                    $display("ERROR: Paused EXECUTE did not hold safely.");
                end
            end

            // Resume and recheck BEFORE the execution edge.
            @(negedge clk);
            cpu_enable = 1'b1;
            #1;

            if ({pc_enable, pc_load, pc_increment,
                 ir_load, acc_load, flags_load, ram_we, out_load, halted}
                !== {expected_pc_controls, 6'b000000}) begin
                errors = errors + 1;
                $display("ERROR: Incorrect controls after resuming.");
            end

            // This edge finishes EXECUTE.
            @(posedge clk);
            #1;
            if (CLU.state !== 2'b00) begin
                errors = errors + 1;
                $display("ERROR: Expected FETCH after executing jump.");
            end

            if (errors == errors_before_test)
                $display("PASS: Jump test %0d, including pause/resume.", test_id + 1);
            else
                $display("FAIL: Jump test %0d.", test_id + 1);
        end

        // Leave the CPU paused for any subsequent tests.
        @(negedge clk);
        cpu_enable = 1'b0;
        #1;

        if (errors == 0)
            $display("\nPASS: All 3 jump tests passed.");
        else
            $display("\nFAIL: Jump tests found %0d error(s).", errors);
    end
        opcode_errors = 0;
opcode_tests  = 0;

$display("\n--- Non-jump opcode tests ---");
$display("Control vector: PCen PCload PCinc IRload Aload RAMwe OUTload FLAGSload ALUop[2:0] IMM HALTED");

// Arguments:
// name, opcode, ALU operation, immediate, A load, flags load, RAM write, OUT load

check_opcode("NOP",      4'h0, 3'b111, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
check_opcode("LDI",      4'h1, 3'b110, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0);
check_opcode("LDA",      4'h2, 3'b110, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0);
check_opcode("STA",      4'h3, 3'b111, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0);
check_opcode("ADD",      4'h4, 3'b000, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0);
check_opcode("SUB",      4'h5, 3'b001, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0);
check_opcode("AND",      4'h6, 3'b010, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0);
check_opcode("OR",       4'h7, 3'b011, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0);
check_opcode("XOR",      4'h8, 3'b100, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0);
check_opcode("OUT",      4'hB, 3'b111, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1);
check_opcode("ADDI",     4'hC, 3'b000, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0);
check_opcode("NOT",      4'hD, 3'b101, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0);
check_opcode("RESERVED", 4'hE, 3'b111, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);

if (opcode_errors == 0)
    $display("\nPASS: All %0d non-jump opcode tests passed.", opcode_tests);
else
    $display("\nFAIL: %0d error(s) across %0d non-jump opcode tests.",
             opcode_errors, opcode_tests);

// Keep your existing $finish; AFTER these calls and the summary.
        $finish;
    end

endmodule
