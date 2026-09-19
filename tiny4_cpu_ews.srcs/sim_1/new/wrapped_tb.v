`timescale 1ns / 1ps

// Matches the wrapper ports and internal instance names posted in this chat.
// Required wrapper parameters: PULSE_CYCLES and DEBOUNCE_CYCLES.
// The wrapper must pass DEBOUNCE_CYCLES to ALL THREE conditioners.
// Uses the actual ROM. Choose a program that reaches HLT within the run limit.
// No testbench writes or forces are made to internal DUT signals.
module wrapped_tb;
    localparam integer TEST_PULSE_CYCLES = 8;
    localparam integer TEST_DEBOUNCE_CYCLES = 4;
    localparam integer SETTLE_CYCLES = TEST_DEBOUNCE_CYCLES + 6;
    localparam integer MAX_RUN_CYCLES = 4000;

    reg clk, btn_reset, btn_step, run_switch;
    wire [3:0] led;
    wire halted_led;
    wire [6:0] seg;
    wire [3:0] an;
    wire dp;

    tiny4_basys3 #(
        .PULSE_CYCLES(TEST_PULSE_CYCLES),
        .DEBOUNCE_CYCLES(TEST_DEBOUNCE_CYCLES)
    ) DUT (
        .clk(clk), .btn_reset(btn_reset), .btn_step(btn_step),
        .run_switch(run_switch), .led(led), .halted_led(halted_led),
        .seg(seg), .an(an), .dp(dp)
    );

    // CPU architectural state, observed through the existing hierarchy.
    wire [24:0] cpu_snapshot;
    wire [7:0] writes;
    assign cpu_snapshot = {
        DUT.CPU.CTRL.state, DUT.CPU.pc_value, DUT.CPU.ir_word,
        DUT.CPU.acc_value, DUT.cpu_out,
        DUT.CPU.zero_flag, DUT.CPU.carry_flag, DUT.cpu_halted
    };
    assign writes = {
        DUT.CPU.pc_enable, DUT.CPU.pc_load, DUT.CPU.pc_increment,
        DUT.CPU.ir_load, DUT.CPU.acc_load, DUT.CPU.ram_we,
        DUT.CPU.out_load, DUT.CPU.flags_load
    };

    integer checks, errors, manual_edges, auto_edges, step_events;
    integer auto_age, before_manual, before_auto, before_steps, elapsed;
    reg done, seen_reset;
    reg [24:0] saved_snapshot;

    // Pre-edge samples used by the monitor. All reads are observational.
    reg sampled_reset, sampled_enable, sampled_mode, sampled_halted;
    reg [24:0] previous_snapshot;
    reg [1:0] previous_state, expected_state;
    reg [3:0] previous_opcode;
    reg previous_step;

    initial begin
        clk = 1'b0;
        #5; // Let the stimulus initialize done before testing it.
        while (!done) begin
            clk = ~clk;
            #5;
        end
    end

    // This guard does not report a late false timeout after normal completion.
    initial begin
        #100_000;
        if (!done) begin
            $display("FAIL: Wrapper test timed out at %0t.", $time);
            done = 1'b1;
            $finish;
        end
    end

    task check_value;
        input [8*80-1:0] label;
        input [31:0] actual;
        input [31:0] expected;
        begin
            checks = checks + 1;
            if (actual !== expected) begin
                errors = errors + 1;
                if (errors <= 30)
                    $display("FAIL @ %0t: %0s expected=%h, got=%h",
                             $time, label, expected, actual);
                else if (errors == 31)
                    $display("Further failure details suppressed; summary will count ALL failures.");
            end
        end
    endtask

    // Stimulus checks run at +2 ns; the monitor below runs at +1 ns.
    task clocks;
        input integer count;
        begin
            repeat (count) begin
                @(posedge clk);
                #2;
            end
        end
    endtask

    // Independent active-low gfedcba reference table.
    function [6:0] expected_segments;
        input [3:0] value;
        begin
            case (value)
                4'h0: expected_segments = 7'b1000000;
                4'h1: expected_segments = 7'b1111001;
                4'h2: expected_segments = 7'b0100100;
                4'h3: expected_segments = 7'b0110000;
                4'h4: expected_segments = 7'b0011001;
                4'h5: expected_segments = 7'b0010010;
                4'h6: expected_segments = 7'b0000010;
                4'h7: expected_segments = 7'b1111000;
                4'h8: expected_segments = 7'b0000000;
                4'h9: expected_segments = 7'b0010000;
                4'hA: expected_segments = 7'b0001000;
                4'hB: expected_segments = 7'b0000011;
                4'hC: expected_segments = 7'b1000110;
                4'hD: expected_segments = 7'b0100001;
                4'hE: expected_segments = 7'b0000110;
                4'hF: expected_segments = 7'b0001110;
                default: expected_segments = 7'b1111111;
            endcase
        end
    endfunction

    // Drive either press bounce (level=1) or release bounce (level=0).
    task bounce_step;
        input level;
        begin
            @(negedge clk); btn_step = level;
            @(negedge clk); btn_step = ~level;
            @(negedge clk); btn_step = level;
            @(negedge clk); btn_step = ~level;
            @(negedge clk); btn_step = level;
            clocks(SETTLE_CYCLES);
        end
    endtask

    // Check selection/timing BEFORE an edge and CPU results AFTER that edge.
    always @(posedge clk) begin
        if (!done) begin
            sampled_reset = DUT.cpu_reset;
            sampled_enable = DUT.cpu_enable;
            sampled_mode = DUT.run_mode;
            sampled_halted = DUT.cpu_halted;
            previous_snapshot = cpu_snapshot;
            previous_state = DUT.CPU.CTRL.state;
            previous_opcode = DUT.CPU.opcode;

            check_value("Enable source selection", sampled_enable,
                        sampled_reset ? 1'b0 :
                        (sampled_mode ? DUT.slow_pulse : DUT.step_pulse));
            check_value("Step pulse is a known bit",
                        (DUT.step_pulse === 1'b0) || (DUT.step_pulse === 1'b1), 1'b1);
            if (DUT.step_pulse === 1'b1) begin
                step_events = step_events + 1;
                check_value("Step pulse does not span two edges", previous_step, 1'b0);
            end
            previous_step = DUT.step_pulse;

            // The registered slow pulse is consumed on the FOLLOWING edge.
            // Auto mode starts with counter=0. First consumption is edge N+1,
            // then every N edges, where N = TEST_PULSE_CYCLES.
            if (sampled_reset || !sampled_mode)
                auto_age = 0;
            else begin
                auto_age = auto_age + 1;
                check_value("Automatic enable spacing", sampled_enable,
                            (auto_age > 1) &&
                            (((auto_age - 1) % TEST_PULSE_CYCLES) == 0));
            end

            if (sampled_enable && !sampled_reset) begin
                if (sampled_mode) auto_edges = auto_edges + 1;
                else manual_edges = manual_edges + 1;
            end
            if (sampled_reset === 1'b1) seen_reset = 1'b1;
            if (seen_reset && (sampled_reset || !sampled_enable || sampled_halted))
                check_value("No CPU writes while reset/paused/halted", writes, 8'h00);

            #1;
            check_value("Slow pulse timing", DUT.slow_pulse,
                        (auto_age > 0) && ((auto_age % TEST_PULSE_CYCLES) == 0));
            check_value("Digit selection", an, 4'b1110);
            check_value("Decimal point off", dp, 1'b1);

            if (seen_reset) begin
                // Unknown CPU data must not pass merely because both sides are X.
                check_value("CPU state contains no X/Z", (^cpu_snapshot === 1'bx), 1'b0);
                check_value("Binary LED wiring", led, DUT.cpu_out);
                check_value("HALT LED wiring", halted_led, DUT.cpu_halted);
                check_value("Seven-segment encoding", seg, expected_segments(DUT.cpu_out));

                if (sampled_reset) begin
                    check_value("Reset clears CPU architectural state", cpu_snapshot, 25'd0);
                end
                else if (!sampled_enable || sampled_halted) begin
                    check_value("CPU holds without an enabled phase",
                                cpu_snapshot, previous_snapshot);
                end
                else begin
                    case (previous_state)
                        2'b00: expected_state = 2'b01;
                        2'b01: expected_state = 2'b10;
                        2'b10: expected_state = (previous_opcode == 4'hF) ? 2'b11 : 2'b00;
                        default: expected_state = 2'b11;
                    endcase
                    check_value("One enabled edge advances one CPU phase",
                                DUT.CPU.CTRL.state, expected_state);
                end
            end
        end
    end

    initial begin
        done = 1'b0;
        seen_reset = 1'b0;
        checks = 0; errors = 0;
        manual_edges = 0; auto_edges = 0; step_events = 0;
        auto_age = 0; previous_step = 1'b0;
        btn_reset = 1'b0; btn_step = 1'b0; run_switch = 1'b0;

        $display("=== Tiny4 Basys 3 wrapper suite ===");
        $display("Uses the current ROM; it must eventually execute HLT.");
        clocks(4);

        $display("\nTEST: Debounced reset in manual mode");
        @(negedge clk); btn_reset = 1'b1;
        clocks(SETTLE_CYCLES);
        check_value("Reset button accepted", DUT.cpu_reset, 1'b1);
        check_value("CPU reset state", cpu_snapshot, 25'd0);
        @(negedge clk); btn_reset = 1'b0;
        clocks(SETTLE_CYCLES);
        check_value("Reset released", DUT.cpu_reset, 1'b0);
        check_value("Manual mode selected", DUT.run_mode, 1'b0);

        $display("\nTEST: Brief step glitch is rejected");
        before_manual = manual_edges;
        saved_snapshot = cpu_snapshot;
        @(negedge clk); btn_step = 1'b1;
        @(negedge clk); btn_step = 1'b0;
        clocks(SETTLE_CYCLES);
        check_value("Glitch caused no step", manual_edges, before_manual);
        check_value("Glitch did not change CPU", cpu_snapshot, saved_snapshot);

        $display("\nTEST: Bouncing press, long hold, release, second press");
        bounce_step(1'b1);
        check_value("First press caused exactly one phase", manual_edges, before_manual + 1);
        check_value("First phase ended in DECODE", DUT.CPU.CTRL.state, 2'b01);
        clocks(16);
        check_value("Holding step caused no repeats", manual_edges, before_manual + 1);
        bounce_step(1'b0);
        check_value("Release bounce caused no step", manual_edges, before_manual + 1);
        bounce_step(1'b1);
        check_value("Second press caused one more phase", manual_edges, before_manual + 2);
        check_value("Second phase ended in EXECUTE", DUT.CPU.CTRL.state, 2'b10);
        bounce_step(1'b0);
        check_value("Second release caused no step", manual_edges, before_manual + 2);

        $display("\nTEST: Short mode-switch disturbance is rejected");
        before_auto = auto_edges;
        @(negedge clk); run_switch = 1'b1;
        clocks(1);
        check_value("Mode stays manual during short glitch", DUT.run_mode, 1'b0);
        @(negedge clk); run_switch = 1'b0;
        repeat (SETTLE_CYCLES) begin
            clocks(1);
            check_value("Run glitch was rejected", DUT.run_mode, 1'b0);
        end
        check_value("Run glitch caused no auto advance", auto_edges, before_auto);

        $display("\nTEST: Automatic mode, with step button ignored");
        @(negedge clk); run_switch = 1'b1;
        clocks(SETTLE_CYCLES + 3 * TEST_PULSE_CYCLES);
        check_value("Automatic mode accepted", DUT.run_mode, 1'b1);
        check_value("Automatic pulses occurred", auto_edges > before_auto, 1'b1);
        before_manual = manual_edges;
        before_steps = step_events;
        bounce_step(1'b1);
        clocks(3 * TEST_PULSE_CYCLES);
        check_value("Step conditioner still detects the press", step_events, before_steps + 1);
        check_value("Step does not select manual enable in auto mode", manual_edges, before_manual);
        bounce_step(1'b0);

        $display("\nTEST: Returning to manual mode pauses the CPU");
        @(negedge clk); run_switch = 1'b0;
        clocks(SETTLE_CYCLES);
        check_value("Manual mode accepted", DUT.run_mode, 1'b0);
        before_auto = auto_edges;
        saved_snapshot = cpu_snapshot;
        clocks(3 * TEST_PULSE_CYCLES);
        check_value("No auto advances in manual mode", auto_edges, before_auto);
        check_value("CPU stayed paused", cpu_snapshot, saved_snapshot);
        check_value("Automatic counter cleared", DUT.counter, 26'd0);

        $display("\nTEST: Reset overrides run mode and a step press");
        @(negedge clk); btn_reset = 1'b1;
        clocks(SETTLE_CYCLES);
        before_manual = manual_edges;
        before_auto = auto_edges;
        @(negedge clk); run_switch = 1'b1;
        clocks(SETTLE_CYCLES);
        bounce_step(1'b1);
        clocks(2 * TEST_PULSE_CYCLES);
        check_value("Reset suppresses manual advances", manual_edges, before_manual);
        check_value("Reset suppresses automatic advances", auto_edges, before_auto);
        check_value("Reset holds CPU clear", cpu_snapshot, 25'd0);
        bounce_step(1'b0);

        $display("\nTEST: Release reset, execute ROM automatically, reach HALT");
        @(negedge clk); btn_reset = 1'b0;
        clocks(SETTLE_CYCLES);
        check_value("Reset deasserted", DUT.cpu_reset, 1'b0);
        elapsed = 0;
        while ((halted_led !== 1'b1) && (elapsed < MAX_RUN_CYCLES)) begin
            clocks(1);
            elapsed = elapsed + 1;
        end
        check_value("Program reaches HALT within run limit", halted_led, 1'b1);

        if (halted_led === 1'b1) begin
            $display("Program halted with OUT=%h.", led);
            saved_snapshot = cpu_snapshot;
            before_auto = auto_edges;
            clocks(5 * TEST_PULSE_CYCLES);
            check_value("Auto enable continues after HALT", auto_edges > before_auto, 1'b1);
            check_value("HALT holds the CPU despite auto enables", cpu_snapshot, saved_snapshot);
        end

        $display("\n==================================================");
        if (errors == 0)
            $display("PASS: Tiny4 wrapper suite -- %0d checks, 0 failures.", checks);
        else
            $display("FAIL: Tiny4 wrapper suite -- %0d failure(s) in %0d checks.", errors, checks);
        $display("==================================================");
        done = 1'b1;
        $finish;
    end
endmodule
