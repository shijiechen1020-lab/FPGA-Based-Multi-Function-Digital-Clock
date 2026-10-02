FPGA Multifunctional Digital Clock

A multifunctional digital clock implemented in Verilog HDL and running on a Cyclone III FPGA development board.

Features

Digital clock with `HH:MM:SS` display
Time adjustment with field selection
Alarm clock
Hourly chime
Stopwatch with lap function
Countdown timer
12/24-hour mode
Button debounce and long-press input
Buzzer output with different tones

Hardware

FPGA: Altera Cyclone III EP3C5E144C8
Development board: GW48-CK with GW3C5 adapter
Clock input: 12 MHz
Display: 8-digit 4-bit BCD interface
Input: 8 push buttons
Output: 8 LEDs and onboard speaker

Software

Quartus II 13.0 SP1
ModelSim-Altera 10.1d
Verilog HDL


Simulation

Two testbenches are included:

`tb_time_keeper.v` tests the clock counting and rollover logic.
`tb_clock_core.v` tests the main system, including mode switching, time adjustment, alarm, chime, stopwatch, and countdown.

The testbenches use a reduced clock frequency during simulation so that longer time intervals can be tested without excessive simulation time.

Build

Open `top_clock_gw48.qpf` with Quartus II 13.0 SP1 and compile the project.


The design is intended for the GW48-CK / GW3C5 hardware setup used in the project.

Notes

The pin assignments in `constraints/` are specific to the GW48-CK board configuration used for this project.
