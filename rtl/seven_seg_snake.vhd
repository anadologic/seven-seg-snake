--------------------------------------------------------------------------------
-- Project     : seven-seg-snake
-- Target      : Digilent Nexys A7 (Xilinx Artix-7 XC7A100T)
-- File        : seven_seg_snake.vhd
-- Description : A "snake" animation that travels around the segments of the
--               on-board 8-digit seven-segment display. The direction of
--               travel is controlled by a slide switch, and an active-low
--               push-button provides a synchronous reset.
--
-- Inputs  :
--   clk_100MHz : 100 MHz system oscillator from the Nexys A7
--   sw_dir     : direction switch (0 = one direction, 1 = the other)
--   btn_rst_n  : active-low reset push-button
--
-- Outputs :
--   seg_n      : seven-segment cathodes (active-low) - {a,b,c,d,e,f,g}
--   dp_n       : decimal point cathode (active-low, unused -> '1')
--   an_n       : digit anode enables (active-low, 8 digits)
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity seven_seg_snake is
    port (
        clk_100MHz : in  std_logic;
        sw_dir     : in  std_logic;
        btn_rst_n  : in  std_logic;

        seg_n      : out std_logic_vector(6 downto 0); -- a,b,c,d,e,f,g
        dp_n       : out std_logic;
        an_n       : out std_logic_vector(7 downto 0)
    );
end entity seven_seg_snake;

architecture rtl of seven_seg_snake is

    ----------------------------------------------------------------------------
    -- TODO Step 1: Reset synchronizer
    --   The reset comes from a mechanical push-button (btn_rst_n) which is
    --   asynchronous to clk_100MHz. To use it as a synchronous reset safely,
    --   pass it through a 2-flip-flop synchronizer. Also invert it here so
    --   the rest of the design uses an active-high "rst" signal internally.
    ----------------------------------------------------------------------------

    -- TODO: signal rst_sync_ff1, rst_sync_ff2 : std_logic;
    -- TODO: signal rst                        : std_logic;  -- active-high, sync


    ----------------------------------------------------------------------------
    -- TODO Step 2: Switch debouncer / synchronizer
    --   sw_dir is also asynchronous and may bounce. Pass it through at least
    --   a 2-FF synchronizer; optionally add a small counter-based debouncer
    --   (e.g. require the input to be stable for ~10 ms = 1_000_000 clocks
    --   at 100 MHz) before using it as the snake direction.
    ----------------------------------------------------------------------------

    -- TODO: signal sw_dir_sync : std_logic;
    -- TODO: signal sw_dir_db   : std_logic;  -- debounced direction


    ----------------------------------------------------------------------------
    -- TODO Step 3: "Snake step" tick generator
    --   The snake should advance roughly a few times per second so the human
    --   eye can follow it (e.g. 4 Hz -> one step every 250 ms).
    --   Build a counter that rolls over every (100_000_000 / STEP_HZ) cycles
    --   and emits a one-clock-wide pulse "step_tick" on rollover.
    --
    --   constant STEP_HZ        : integer := 4;
    --   constant STEP_DIV       : integer := 100_000_000 / STEP_HZ;
    ----------------------------------------------------------------------------

    -- TODO: signal step_cnt  : unsigned( ... );
    -- TODO: signal step_tick : std_logic;


    ----------------------------------------------------------------------------
    -- Step 4 (concept): Map the snake "track"
    --
    --   The Nexys A7 has 8 seven-segment digits. We treat the whole bank as a
    --   single track that the snake walks around. A natural track on ONE digit
    --   is the 6 outer segments: a -> b -> c -> d -> e -> f -> back to a.
    --   Across 8 digits we can extend that into a long loop:
    --     - segment 'a' travels left-to-right across all 8 digits (top edge)
    --     - segment 'b' walks down on the rightmost digit (right edge)
    --     - segment 'c' is also on the right of each digit
    --     - 'd' travels right-to-left across all 8 digits (bottom edge)
    --     - 'e','f' walk up on the leftmost digit (left edge)
    --
    --   To keep the first version simple, the TODOs below implement the
    --   "single-digit loop" first (one active digit, segment index 0..5
    --   cycling through a,b,c,d,e,f). Extending this to all 8 digits is
    --   left as Step 7.
    ----------------------------------------------------------------------------


    ----------------------------------------------------------------------------
    -- TODO Step 5: Snake position state machine
    --   Keep a "pos" register that counts 0..5 (segment index on a digit).
    --   On every step_tick:
    --     if sw_dir_db = '0' -> pos <= pos + 1 (with wrap 5 -> 0)
    --     if sw_dir_db = '1' -> pos <= pos - 1 (with wrap 0 -> 5)
    --   On rst, pos <= 0.
    ----------------------------------------------------------------------------

    -- TODO: signal pos : unsigned(2 downto 0);  -- range 0..5


    ----------------------------------------------------------------------------
    -- TODO Step 6: Decode pos -> seg_n (active-low)
    --   Segment order in seg_n: (6)=a (5)=b (4)=c (3)=d (2)=e (1)=f (0)=g
    --   With 7 segments the cathodes are active-low on the Nexys A7, so the
    --   "lit" segment is '0' and all others are '1'.
    --
    --   pos = 0 -> light a -> seg_n = "0111111"
    --   pos = 1 -> light b -> seg_n = "1011111"
    --   pos = 2 -> light c -> seg_n = "1101111"
    --   pos = 3 -> light d -> seg_n = "1110111"
    --   pos = 4 -> light e -> seg_n = "1111011"
    --   pos = 5 -> light f -> seg_n = "1111101"
    --   (segment g is never used in this animation)
    ----------------------------------------------------------------------------


    ----------------------------------------------------------------------------
    -- TODO Step 7 (extension): 8-digit display multiplexing
    --   The Nexys A7 shares the 7 cathodes between all 8 digits and selects
    --   the active digit with an_n (active-low). To show different patterns
    --   per digit, you must time-multiplex:
    --     - Run a refresh counter at ~1 kHz per digit (8 kHz total) so the
    --       eye sees all digits as steady.
    --     - For each refresh slot, drive seg_n with that digit's pattern and
    --       pull only that digit's an_n bit low.
    --
    --   For the snake-on-one-digit version (Steps 1-6), you can hard-wire:
    --     an_n <= "11111110";  -- only digit 0 enabled
    --     dp_n <= '1';
    ----------------------------------------------------------------------------

begin

    ----------------------------------------------------------------------------
    -- TODO: Implement Steps 1..6 as concurrent / sequential statements here.
    -- Until then, drive safe defaults so the design still elaborates and the
    -- display stays blank.
    ----------------------------------------------------------------------------

    seg_n <= (others => '1');   -- all segments off (active-low)
    dp_n  <= '1';               -- decimal point off
    an_n  <= (others => '1');   -- all digits disabled

end architecture rtl;
