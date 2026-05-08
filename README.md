# seven-seg-snake

A "snake" animation that ping-pongs across the 8-digit seven-segment
display on the Digilent **Nexys A7** board. Each digit lights segments
`b → c → d → e → f` in turn, then the trail jumps to the next digit.
At LED7 the snake reverses and walks back to LED0.

- **Board**: Digilent Nexys A7 (Xilinx Artix-7 XC7A100T)
- **Language**: VHDL-2008
- **Inputs**: 100 MHz oscillator, one slide switch (direction), one
  push-button (active-low reset)
- **Output**: 8-digit seven-segment display

## Pin mapping (Nexys A7)

| Top-level port | Board net      | Pin  |
|----------------|----------------|------|
| `clk_100MHz`   | CLK100MHZ      | E3   |
| `sw_dir`       | SW0            | J15  |
| `btn_rst_n`    | CPU_RESETN     | C12  |
| `seg_n[6:0]`   | CA..CG (a..g)  | T10/R10/K16/K13/P15/T11/L18 |
| `dp_n`         | DP             | H15  |
| `an_n[7:0]`    | AN0..AN7       | J17/J18/T9/J14/P14/T14/K2/U13 |

Constraints live in [constraint/Nexys-4-DDR-Master.xdc](constraint/Nexys-4-DDR-Master.xdc).

## Repository layout

```
seven-seg-snake/
├── rtl/                            # synthesizable RTL
│   ├── seven_seg_snake.vhd         # top: ping-pong table + structural wiring
│   ├── sync_reset.vhd              # 2-FF async-low -> sync-high reset
│   ├── debouncer.vhd               # 2-FF sync + counter debouncer
│   ├── tick_gen.vhd                # generic /N divider, 1-cycle pulse
│   ├── snake_fsm.vhd               # position counter, +/-, modulo wrap
│   ├── seg_decoder.vhd             # pos -> active-low a..g pattern (standalone)
│   └── seg_mux.vhd                 # 8-digit time-multiplexed driver
├── constraint/
│   └── Nexys-4-DDR-Master.xdc      # board pin/timing constraints
├── sim/
│   ├── tb/                         # self-checking testbenches
│   │   ├── tb_sync_reset.vhd
│   │   ├── tb_debouncer.vhd
│   │   ├── tb_tick_gen.vhd
│   │   ├── tb_snake_fsm.vhd
│   │   ├── tb_seg_decoder.vhd
│   │   ├── tb_seg_mux.vhd
│   │   ├── tb_seven_seg_snake.vhd  # legacy single-digit integration test
│   │   └── tb_perimeter.vhd        # full ping-pong integration test
│   └── scripts/                    # simulator run scripts (.do)
├── vivado/
│   ├── build.bat / scripts/build.tcl     # batch synth + impl + bitstream
│   └── program.bat / scripts/program.tcl # JTAG program the board
└── .gitignore
```

## Architecture

```
btn_rst_n ─▶ sync_reset ─▶ rst ────────────────────────────────┐
                                                               ▼
sw_dir    ─▶ debouncer  ─▶ sw_dir_db ─▶ snake_fsm ─▶ pos ─▶ map_pos
                                              ▲              │
clk_100MHz ─▶ tick_gen (~10 Hz) ─ step_tick ──┘              ▼
                                                       (digit, segment)
                                                             │
                                                             ▼
                                                       patterns(0..7)
                                                             │
                                                             ▼
                                                        seg_mux ─▶ seg_n, an_n
```

| Module        | Role                                                              |
|---------------|-------------------------------------------------------------------|
| `sync_reset`  | Async-low button → 2-FF synchronized active-high reset            |
| `debouncer`   | 2-FF synchronizer + ~10 ms stability counter on `sw_dir`          |
| `tick_gen`    | Generic clock divider, emits 1-cycle pulse every `DIVIDER` clocks |
| `snake_fsm`   | Position counter 0..N-1, +1/-1 on `step`, modulo wrap             |
| `seg_decoder` | One-hot active-low pattern on segments a..f (standalone, unused by top) |
| `seg_mux`     | 8-digit time-multiplex driver at ~1 kHz/digit                     |

### Animation

The top maintains a single ping-pong counter `pos ∈ 0..79`:

- **Forward leg** (positions 0..39): `digit = pos / 5`, segment cycles
  `b, c, d, e, f` per digit. So LED0 lights b→c→d→e→f, then LED1 does
  the same, ... up to LED7.
- **Reverse leg** (positions 40..79): mirrored back to LED0.
- The FSM's natural wrap at 79 → 0 starts the next ping-pong cycle.

A `for d in 0 to 7 generate` block builds the per-digit `patterns` array
so only the active digit shows the lit segment; the other seven digits
are blanked, and `seg_mux` time-multiplexes them at ~1 kHz/digit.

## Simulation

Any VHDL-2008 simulator that understands `.do` scripts (e.g. ModelSim
/ QuestaSim) can run the testbenches. Add the simulator's `bin` (or
`win64`) directory to `PATH`, then from the repo root:

```powershell
cd sim
vsim -c -do scripts/run_perimeter.do
```

Other run scripts in [sim/scripts/](sim/scripts/) (one per testbench):

| Script                       | DUT                          |
|------------------------------|------------------------------|
| `run_sync_reset.do`          | `sync_reset`                 |
| `run_debouncer.do`           | `debouncer`                  |
| `run_tick_gen.do`            | `tick_gen`                   |
| `run_snake_fsm.do`           | `snake_fsm`                  |
| `run_seg_decoder.do`         | `seg_decoder`                |
| `run_seg_mux.do`             | `seg_mux` (+ `seg_mux_pkg`)  |
| `run_seven_seg_snake.do`     | legacy single-digit top      |
| `run_perimeter.do`           | full ping-pong top           |

Each TB ends with `==== <TB_NAME>: ALL CHECKS PASSED ====` on success;
on failure it ends with `N FAILURES` and a non-zero exit.

## Build (Vivado 2023.1)

Two ways: scripted (recommended) or GUI.

### Scripted

```cmd
vivado\build.bat       :: synth -> impl -> bitstream
vivado\program.bat     :: JTAG program the board (volatile)
```

`build.bat` wraps [vivado/scripts/build.tcl](vivado/scripts/build.tcl):
it creates a project under `vivado/build/`, adds all `rtl/*.vhd` as
VHDL-2008 sources, applies the constraint file, runs synthesis +
implementation + bitstream, and copies the bit to
`vivado/build/seven_seg_snake.bit`.

The Vivado path is hard-coded to `F:\Xilinx\Vivado\2023.1` in the
`.bat` wrappers — edit if your install lives elsewhere.

### GUI

1. Create a new RTL project targeting **xc7a100tcsg324-1**.
2. Add all files in `rtl/` as VHDL-2008 design sources.
3. Add `constraint/Nexys-4-DDR-Master.xdc` as a constraints file.
4. Set `seven_seg_snake` as the top module.
5. Run synthesis → implementation → generate bitstream → program device.

## Status

| Module                  | Implemented | Simulated |
|-------------------------|:-----------:|:---------:|
| `sync_reset`            | ✅          | ✅        |
| `debouncer`             | ✅          | ✅        |
| `tick_gen`              | ✅          | ✅        |
| `snake_fsm`             | ✅          | ✅        |
| `seg_decoder`           | ✅          | ✅        |
| `seg_mux`               | ✅          | ✅        |
| `seven_seg_snake` (top) | ✅          | ✅        |
