## Tiny4 CPU - Basys 3 constraints
## Top-level module ports expected:
## clk, btn_reset, btn_step, run_switch,
## led[3:0], halted_led, seg[6:0], an[3:0], dp


## ============================================================
## 100 MHz board clock
## ============================================================

set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports clk]

create_clock -add -name sys_clk_pin -period 10.000 \
    -waveform {0.000 5.000} [get_ports clk]


## ============================================================
## Inputs
## ============================================================

## SW0: automatic/manual run switch
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } \
    [get_ports run_switch]

## Center button: reset
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } \
    [get_ports btn_reset]

## Up button: manual step
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } \
    [get_ports btn_step]


## ============================================================
## LEDs
## ============================================================

## LED0 - Tiny4 OUT bit 0
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } \
    [get_ports {led[0]}]

## LED1 - Tiny4 OUT bit 1
set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } \
    [get_ports {led[1]}]

## LED2 - Tiny4 OUT bit 2
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } \
    [get_ports {led[2]}]

## LED3 - Tiny4 OUT bit 3
set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 } \
    [get_ports {led[3]}]

## LED4 - HALT indicator
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } \
    [get_ports halted_led]


## ============================================================
## Seven-segment display
##
## Your decoder convention:
##
## seg[0] = a
## seg[1] = b
## seg[2] = c
## seg[3] = d
## seg[4] = e
## seg[5] = f
## seg[6] = g
##
## Basys 3 display signals are active-low.
## ============================================================

set_property -dict { PACKAGE_PIN W7 IOSTANDARD LVCMOS33 } \
    [get_ports {seg[0]}]

set_property -dict { PACKAGE_PIN W6 IOSTANDARD LVCMOS33 } \
    [get_ports {seg[1]}]

set_property -dict { PACKAGE_PIN U8 IOSTANDARD LVCMOS33 } \
    [get_ports {seg[2]}]

set_property -dict { PACKAGE_PIN V8 IOSTANDARD LVCMOS33 } \
    [get_ports {seg[3]}]

set_property -dict { PACKAGE_PIN U5 IOSTANDARD LVCMOS33 } \
    [get_ports {seg[4]}]

set_property -dict { PACKAGE_PIN V5 IOSTANDARD LVCMOS33 } \
    [get_ports {seg[5]}]

set_property -dict { PACKAGE_PIN U7 IOSTANDARD LVCMOS33 } \
    [get_ports {seg[6]}]


## Decimal point
set_property -dict { PACKAGE_PIN V7 IOSTANDARD LVCMOS33 } \
    [get_ports dp]


## ============================================================
## Seven-segment digit enables
## ============================================================

## AN0 - rightmost digit
set_property -dict { PACKAGE_PIN U2 IOSTANDARD LVCMOS33 } \
    [get_ports {an[0]}]

## AN1
set_property -dict { PACKAGE_PIN U4 IOSTANDARD LVCMOS33 } \
    [get_ports {an[1]}]

## AN2
set_property -dict { PACKAGE_PIN V4 IOSTANDARD LVCMOS33 } \
    [get_ports {an[2]}]

## AN3 - leftmost digit
set_property -dict { PACKAGE_PIN W4 IOSTANDARD LVCMOS33 } \
    [get_ports {an[3]}]