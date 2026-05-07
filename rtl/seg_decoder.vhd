--------------------------------------------------------------------------------
-- File        : seg_decoder.vhd
-- Description : Decodes a snake position (0..5) to an active-low 7-segment
--               cathode pattern. Segment order in seg_n:
--                 (6)=a (5)=b (4)=c (3)=d (2)=e (1)=f (0)=g
--               Active-low: '0' lights the segment, '1' is off.
--
--   pos = 0 -> a   -> "0111111"
--   pos = 1 -> b   -> "1011111"
--   pos = 2 -> c   -> "1101111"
--   pos = 3 -> d   -> "1110111"
--   pos = 4 -> e   -> "1111011"
--   pos = 5 -> f   -> "1111101"
--   (segment g is unused for the snake animation)
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity seg_decoder is
    port (
        pos   : in  integer range 0 to 5;
        seg_n : out std_logic_vector(6 downto 0)
    );
end entity seg_decoder;

architecture rtl of seg_decoder is
begin

    ----------------------------------------------------------------------------
    -- TODO Step 1: Combinational decode
    --   Use a `with pos select` or a `case` inside a process(pos) to map
    --   each position 0..5 to the patterns listed in the header.
    --   Provide a safe default (all '1', display blank) for any out-of-range
    --   value (defensive coding).
    ----------------------------------------------------------------------------

    seg_n <= (others => '1');  -- safe default: all segments off

end architecture rtl;
