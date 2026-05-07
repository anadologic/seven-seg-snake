--------------------------------------------------------------------------------
-- File        : tb_seg_decoder.vhd
-- Description : Self-checking testbench for seg_decoder.
--
--   Sweeps pos = 0..5 and verifies each active-low one-hot pattern.
--   Also checks that exactly one bit of seg_n is '0' for every valid pos
--   (one-hot-low property).
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_seg_decoder is
end entity tb_seg_decoder;

architecture sim of tb_seg_decoder is

    signal pos   : integer range 0 to 5 := 0;
    signal seg_n : std_logic_vector(6 downto 0);

    signal err_count : natural := 0;

    type pattern_array_t is array (0 to 5) of std_logic_vector(6 downto 0);
    constant EXPECTED : pattern_array_t := (
        0 => "0111111",  -- a
        1 => "1011111",  -- b
        2 => "1101111",  -- c
        3 => "1110111",  -- d
        4 => "1111011",  -- e
        5 => "1111101"   -- f
    );

    procedure check (
        cond             : in    boolean;
        msg              : in    string;
        signal err_count : inout natural
    ) is
    begin
        if not cond then
            err_count <= err_count + 1;
            report "CHECK FAIL: " & msg severity error;
        else
            report "CHECK PASS: " & msg severity note;
        end if;
    end procedure;

    -- Count zeros in a vector — for a valid pos this must equal 1.
    function count_zeros (v : std_logic_vector) return natural is
        variable n : natural := 0;
    begin
        for i in v'range loop
            if v(i) = '0' then
                n := n + 1;
            end if;
        end loop;
        return n;
    end function;

begin

    dut : entity work.seg_decoder
        port map (
            pos   => pos,
            seg_n => seg_n
        );

    stim_proc : process
    begin
        for i in 0 to 5 loop
            pos <= i;
            wait for 1 ns;  -- let combinational logic settle

            check(seg_n = EXPECTED(i),
                  "pos=" & integer'image(i) & " pattern matches",
                  err_count);

            check(count_zeros(seg_n) = 1,
                  "pos=" & integer'image(i) & " is one-hot-low",
                  err_count);
        end loop;

        if err_count = 0 then
            report "==== TB_SEG_DECODER: ALL CHECKS PASSED ====" severity note;
        else
            report "==== TB_SEG_DECODER: " & integer'image(err_count) & " FAILURES ====" severity failure;
        end if;

        wait;
    end process;

end architecture sim;
