--------------------------------------------------------------------------------
-- Project     : seven-seg-snake
-- Target      : Digilent Nexys A7 (Xilinx Artix-7 XC7A100T)
-- File        : seven_seg_snake.vhd
-- Description : "Snake" animation: each digit cycles through the same 5
--               segments (b, c, d, e, f) and then the pattern jumps to the
--               next digit. The snake ping-pongs between LED0 and LED7.
--
--   Forward leg (40 positions, LED0 -> LED7):
--     LED0:  b, c, d, e, f
--     LED1:  b, c, d, e, f
--     LED2:  b, c, d, e, f
--     ...
--     LED7:  b, c, d, e, f
--   Reverse leg: same path traversed backwards back to b@0.
--   Total: 80 unique step events per full ping-pong cycle.
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

use work.seg_mux_pkg.all;

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
    constant DEBOUNCE_CYCLES : positive := CLK_HZ / 100;            -- ~10 ms
    constant STEP_HZ         : positive := 10;                      -- snake speed
    constant STEP_DIV        : positive := CLK_HZ / STEP_HZ;        -- 10_000_000
    constant REFRESH_HZ      : positive := 1_000;                   -- per-digit refresh
    constant REFRESH_DIV     : positive := CLK_HZ / (REFRESH_HZ * 8); -- 12_500

    ----------------------------------------------------------------------------
    -- Animation table
    --   8 digits * 5 segments each = 40 positions per forward leg.
    --   The full ping-pong cycle is 2 * FORWARD_LEN = 80 positions: positions
    --   0..39 walk LED0->LED7, positions 40..79 retrace back to LED0.
    ----------------------------------------------------------------------------
    constant SEGS_PER_DIGIT : positive := 5;
    constant FORWARD_LEN    : positive := 8 * SEGS_PER_DIGIT;       -- 40
    constant NUM_POS        : positive := 2 * FORWARD_LEN;          -- 80

    constant SEG_OFF : std_logic_vector(6 downto 0) := "1111111";
    constant SEG_A   : std_logic_vector(6 downto 0) := "0111111";
    constant SEG_B   : std_logic_vector(6 downto 0) := "1011111";
    constant SEG_C   : std_logic_vector(6 downto 0) := "1101111";
    constant SEG_D   : std_logic_vector(6 downto 0) := "1110111";
    constant SEG_E   : std_logic_vector(6 downto 0) := "1111011";
    constant SEG_F   : std_logic_vector(6 downto 0) := "1111101";

    type step_t is record
        digit : integer range 0 to 7;
        seg   : std_logic_vector(6 downto 0);
    end record;

    ----------------------------------------------------------------------------
    -- Forward-leg lookup: index 0..39 -> (digit, segment).
    --   digit = idx / 5
    --   slot  = idx mod 5  -> b, c, d, e, f
    ----------------------------------------------------------------------------
    function fwd_step (idx : integer) return step_t is
        variable r : step_t;
    begin
        r.digit := idx / SEGS_PER_DIGIT;
        case idx mod SEGS_PER_DIGIT is
            when 0      => r.seg := SEG_B;
            when 1      => r.seg := SEG_C;
            when 2      => r.seg := SEG_D;
            when 3      => r.seg := SEG_E;
            when others => r.seg := SEG_F;
        end case;
        return r;
    end function;

    ----------------------------------------------------------------------------
    -- Ping-pong mapping: linear position 0..NUM_POS-1 -> forward index.
    --   p in [0, FORWARD_LEN-1]   -> p
    --   p in [FORWARD_LEN, 2L-1]  -> 2L-1-p   (mirrored back)
    -- Note: positions 0 and NUM_POS-1 both map to (digit 0, seg b), so on the
    -- wrap from position 79 -> 0 the snake holds b@0 for one extra step.
    -- That's a deliberate trade-off for the trivial FSM-with-wrap design.
    ----------------------------------------------------------------------------
    function map_pos (p : integer) return step_t is
    begin
        if p < FORWARD_LEN then return fwd_step(p);
        else                    return fwd_step(NUM_POS - 1 - p);
        end if;
    end function;

    ----------------------------------------------------------------------------
    -- Internal signals
    ----------------------------------------------------------------------------
    signal rst       : std_logic;
    signal sw_dir_db : std_logic;
    signal step_tick : std_logic;
    signal pos       : integer range 0 to NUM_POS-1;
    signal patterns  : seg_array_t;

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
        generic map (DEBOUNCE_CYCLES => DEBOUNCE_CYCLES)
        port map (
            clk      => clk_100MHz,
            rst      => rst,
            async_in => sw_dir,
            clean    => sw_dir_db
        );

    ----------------------------------------------------------------------------
    -- Snake step-tick generator (~10 Hz)
    ----------------------------------------------------------------------------
    u_step_tick : entity work.tick_gen
        generic map (DIVIDER => STEP_DIV)
        port map (
            clk  => clk_100MHz,
            rst  => rst,
            tick => step_tick
        );

    ----------------------------------------------------------------------------
    -- Position FSM: 0..NUM_POS-1 with wrap. The wrap implements the second
    -- half of the ping-pong table, and wrapping past NUM_POS-1 -> 0 starts
    -- the next forward leg.
    ----------------------------------------------------------------------------
    u_fsm : entity work.snake_fsm
        generic map (NUM_POSITIONS => NUM_POS)
        port map (
            clk  => clk_100MHz,
            rst  => rst,
            step => step_tick,
            dir  => sw_dir_db,
            pos  => pos
        );

    ----------------------------------------------------------------------------
    -- Decode pos into the per-digit cathode patterns. Only the digit named
    -- by the active step lights its segment; the rest are blank.
    ----------------------------------------------------------------------------
    gen_patterns : for d in 0 to 7 generate
        patterns(d) <= map_pos(pos).seg when map_pos(pos).digit = d else SEG_OFF;
    end generate;

    ----------------------------------------------------------------------------
    -- 8-digit time-multiplexed display driver
    ----------------------------------------------------------------------------
    u_mux : entity work.seg_mux
        generic map (REFRESH_DIV => REFRESH_DIV)
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
