--------------------------------------------------------------------------------
-- Project     : seven-seg-snake
-- Target      : Digilent Nexys A7 (Xilinx Artix-7 XC7A100T)
-- File        : seven_seg_snake.vhd
-- Description : Top-level wiring for the seven-segment "snake" animation.
--               This file only instantiates submodules and connects them;
--               all logic lives in the children:
--
--                 sync_reset   - 2-FF reset synchronizer (async-low -> sync-high)
--                 debouncer    - 2-FF synchronizer + counter-based debouncer
--                 tick_gen     - generic /N divider, emits 1-cycle pulse
--                 snake_fsm    - position counter (up/down, modulo wrap)
--                 seg_decoder  - position -> active-low cathode pattern
--                 seg_mux      - 8-digit time-multiplexed display driver
--
-- Inputs  :
--   clk_100MHz : 100 MHz system oscillator (Nexys A7 pin E3)
--   sw_dir     : direction switch (SW0)
--   btn_rst_n  : active-low reset push-button (CPU_RESETN)
--
-- Outputs :
--   seg_n      : seven-segment cathodes, active-low (a..g = bits 6..0)
--   dp_n       : decimal point cathode, active-low (unused -> '1')
--   an_n       : digit anode enables, active-low (8 digits)
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.seg_mux_pkg.all;  -- seg_array_t

entity seven_seg_snake is
    port (
        clk_100MHz : in  std_logic;
        sw_dir     : in  std_logic;
        btn_rst_n  : in  std_logic;

        seg_n      : out std_logic_vector(6 downto 0);
        dp_n       : out std_logic;
        an_n       : out std_logic_vector(7 downto 0)
    );
end entity seven_seg_snake;

architecture rtl of seven_seg_snake is

    ----------------------------------------------------------------------------
    -- Timing constants (100 MHz clock)
    ----------------------------------------------------------------------------
    constant CLK_HZ          : positive := 100_000_000;
    constant DEBOUNCE_CYCLES : positive := CLK_HZ / 100;     -- ~10 ms
    constant STEP_HZ         : positive := 4;                -- snake speed
    constant STEP_DIV        : positive := CLK_HZ / STEP_HZ; -- 25_000_000
    constant REFRESH_HZ      : positive := 1_000;            -- per-digit refresh
    constant REFRESH_DIV     : positive := CLK_HZ / (REFRESH_HZ * 8); -- 12_500
    constant NUM_POS         : positive := 6;                -- a..f loop

    ----------------------------------------------------------------------------
    -- Internal signals
    ----------------------------------------------------------------------------
    signal rst        : std_logic;
    signal sw_dir_db  : std_logic;
    signal step_tick  : std_logic;
    signal pos        : integer range 0 to NUM_POS-1;
    signal seg_active : std_logic_vector(6 downto 0);

    ----------------------------------------------------------------------------
    -- TODO Step A: Per-digit pattern array for the multiplexer.
    --   For the simple "snake on digit 0" version, only index 0 carries the
    --   live pattern; all others are blank ("1111111").
    --   Later, fill more slots to extend the snake across multiple digits.
    ----------------------------------------------------------------------------
    signal patterns : seg_array_t;

begin

    ----------------------------------------------------------------------------
    -- Reset synchronizer: btn_rst_n (async, active-low) -> rst (sync, high)
    ----------------------------------------------------------------------------
    u_sync_reset : entity work.sync_reset
        port map (
            clk        => clk_100MHz,
            async_rstn => btn_rst_n,
            sync_rst   => rst
        );

    ----------------------------------------------------------------------------
    -- Direction switch debouncer
    ----------------------------------------------------------------------------
    u_debouncer : entity work.debouncer
        generic map (
            DEBOUNCE_CYCLES => DEBOUNCE_CYCLES
        )
        port map (
            clk      => clk_100MHz,
            rst      => rst,
            async_in => sw_dir,
            clean    => sw_dir_db
        );

    ----------------------------------------------------------------------------
    -- Snake step-tick generator (~4 Hz)
    ----------------------------------------------------------------------------
    u_step_tick : entity work.tick_gen
        generic map (
            DIVIDER => STEP_DIV
        )
        port map (
            clk  => clk_100MHz,
            rst  => rst,
            tick => step_tick
        );

    ----------------------------------------------------------------------------
    -- Position FSM: 0..NUM_POS-1, advances on each step_tick
    ----------------------------------------------------------------------------
    u_fsm : entity work.snake_fsm
        generic map (
            NUM_POSITIONS => NUM_POS
        )
        port map (
            clk  => clk_100MHz,
            rst  => rst,
            step => step_tick,
            dir  => sw_dir_db,
            pos  => pos
        );

    ----------------------------------------------------------------------------
    -- Segment decoder: pos -> active-low cathode pattern
    ----------------------------------------------------------------------------
    u_decoder : entity work.seg_decoder
        port map (
            pos   => pos,
            seg_n => seg_active
        );

    ----------------------------------------------------------------------------
    -- TODO Step B: Build the per-digit patterns array.
    --   Simple version: snake lives only on digit 0.
    ----------------------------------------------------------------------------
    patterns(0) <= seg_active;
    gen_blank : for i in 1 to 7 generate
        patterns(i) <= (others => '1');
    end generate;

    ----------------------------------------------------------------------------
    -- 8-digit time-multiplexed display driver
    ----------------------------------------------------------------------------
    u_mux : entity work.seg_mux
        generic map (
            REFRESH_DIV => REFRESH_DIV
        )
        port map (
            clk         => clk_100MHz,
            rst         => rst,
            patterns_in => patterns,
            seg_n       => seg_n,
            an_n        => an_n
        );

    -- Decimal point unused
    dp_n <= '1';

end architecture rtl;
