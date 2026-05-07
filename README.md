# seven-seg-snake

A "snake" animation that walks around the segments of the 8-digit
seven-segment display on the Digilent **Nexys A7** board.

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
│   ├── seven_seg_snake.vhd         # top: structural wiring
│   ├── sync_reset.vhd              # 2-FF async-low -> sync-high reset
│   ├── debouncer.vhd               # 2-FF sync + counter debouncer
│   ├── tick_gen.vhd                # generic /N divider, 1-cycle pulse
│   ├── snake_fsm.vhd               # position counter, +/-, modulo wrap
│   ├── seg_decoder.vhd             # pos -> active-low a..g pattern
│   └── seg_mux.vhd                 # 8-digit time-multiplexed driver
├── constraint/
│   └── Nexys-4-DDR-Master.xdc      # board pin/timing constraints
├── sim/
│   ├── tb/tb_sync_reset.vhd        # self-checking testbench
│   └── scripts/run_sync_reset.do   # QuestaSim run script
└── .gitignore
```

## Architecture

```
btn_rst_n ──▶ sync_reset ──▶ rst ─────────────────┐
                                                  ▼
sw_dir    ──▶ debouncer  ──▶ sw_dir_db ──▶ snake_fsm ──▶ pos ──▶ seg_decoder ──┐
                                                  ▲                            │
clk_100MHz ─▶ tick_gen (~4 Hz) ───── step_tick ───┘                            ▼
                                                                          patterns(0..7)
                                                                               │
                                                                               ▼
                                                                          seg_mux ──▶ seg_n, an_n
```

| Module        | Role                                                              |
|---------------|-------------------------------------------------------------------|
| `sync_reset`  | Async-low button → 2-FF synchronized active-high reset            |
| `debouncer`   | 2-FF synchronizer + ~10 ms stability counter on `sw_dir`          |
| `tick_gen`    | Generic clock divider, emits 1-cycle pulse every `DIVIDER` clocks |
| `snake_fsm`   | Position counter 0..N-1, +1/-1 on `step`, modulo wrap             |
| `seg_decoder` | One-hot active-low pattern on segments a..f                       |
| `seg_mux`     | 8-digit time-multiplex driver at ~1 kHz/digit                     |

The single-digit demo lights one segment at a time on digit 0, walking
the perimeter `a → b → c → d → e → f → a` (or reversed). Extending the
animation across all 8 digits is documented as TODO Step 7 inside the
top module.

## Simulation (QuestaSim)

Tested with QuestaSim 10.7c. Add the QuestaSim `win64` directory to
`PATH`, then from the repo root:

```powershell
$env:Path = "C:\questasim64_10.7c\win64;" + $env:Path
cd sim
vsim -c -do scripts/run_sync_reset.do
```

Expected tail of output:

```
CHECK PASS: power-up: sync_rst held high while rst asserted
CHECK PASS: deassertion: sync_rst low within 2 clocks of release
CHECK PASS: async assertion: sync_rst high without waiting for clk
CHECK PASS: hold: sync_rst remains high while rst asserted
CHECK PASS: deassertion #2: sync_rst low within 2 clocks
CHECK PASS: short glitch: async path drove sync_rst high
CHECK PASS: recovery: sync_rst low again after glitch
==== TB_SYNC_RESET: ALL CHECKS PASSED ====
Errors: 0, Warnings: 0
```

## Build (Vivado)

1. Create a new RTL project targeting **xc7a100tcsg324-1**.
2. Add all files in `rtl/` as design sources.
3. Add `constraint/Nexys-4-DDR-Master.xdc` as a constraints file.
4. Set `seven_seg_snake` as the top module.
5. Run synthesis → implementation → generate bitstream → program device.

## Status

| Module          | Skeleton | Implemented | Simulated |
|-----------------|:--------:|:-----------:|:---------:|
| `sync_reset`    | ✅       | ✅          | ✅        |
| `debouncer`     | ✅       | ⏳          | ⏳        |
| `tick_gen`      | ✅       | ⏳          | ⏳        |
| `snake_fsm`     | ✅       | ⏳          | ⏳        |
| `seg_decoder`   | ✅       | ⏳          | ⏳        |
| `seg_mux`       | ✅       | ⏳          | ⏳        |
| `seven_seg_snake` (top) | ✅ | ✅ (wiring) | ⏳ |

Each unimplemented module has step-by-step TODO comments describing the
logic to fill in.
