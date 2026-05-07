--------------------------------------------------------------------------------
-- File        : tb_seg_mux.vhd
-- Description : Self-checking testbench for seg_mux.
--
--   Uses a small REFRESH_DIV (4) so the test runs quickly. Drives a unique
--   pattern into each slot of patterns_in, then checks:
--     1) Reset puts the mux at slot 0 (an_n = "11111110", seg_n = patterns_in(0)).
--     2) After every REFRESH_DIV clocks, sel advances by 1: an_n is one-hot-low
--        and seg_n equals patterns_in of the active slot.
--     3) Selector wraps from 7 back to 0 after a full cycle.
--     4) an_n is always one-hot-low (exactly one zero).
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use work.seg_mux_pkg.all;

entity tb_seg_mux is
end entity tb_seg_mux;

architecture sim of tb_seg_mux is

    constant CLK_PERIOD : time     := 10 ns;
    constant DIV        : positive := 4;   -- short for fast sim

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal patterns : seg_array_t;
    signal seg_n    : std_logic_vector(6 downto 0);
    signal an_n     : std_logic_vector(7 downto 0);

    signal sim_done  : boolean := false;
    signal err_count : natural := 0;

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

    function count_zeros (v : std_logic_vector) return natural is
        variable n : natural := 0;
    begin
        for i in v'range loop
            if v(i) = '0' then n := n + 1; end if;
        end loop;
        return n;
    end function;

    function expected_an_n (slot : integer) return std_logic_vector is
        variable v : std_logic_vector(7 downto 0) := (others => '1');
    begin
        v(slot) := '0';
        return v;
    end function;

begin

    dut : entity work.seg_mux
        generic map (
            REFRESH_DIV => DIV
        )
        port map (
            clk         => clk,
            rst         => rst,
            patterns_in => patterns,
            seg_n       => seg_n,
            an_n        => an_n
        );

    clk_proc : process
    begin
        while not sim_done loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    -- Drive a unique recognizable pattern into each digit slot.
    -- patterns(i) = "0" & 6-bit slot index pattern -> easy to spot mismatches.
    pat_drive : process
    begin
        patterns(0) <= "0000001";
        patterns(1) <= "0000010";
        patterns(2) <= "0000100";
        patterns(3) <= "0001000";
        patterns(4) <= "0010000";
        patterns(5) <= "0100000";
        patterns(6) <= "1000000";
        patterns(7) <= "1111110";
        wait;
    end process;

    stim_proc : process

        -- Wait until slot `s` is active and verify outputs.
        procedure verify_slot (s : integer) is
        begin
            -- Sample shortly after a clock edge so combinational outputs are settled.
            wait for 1 ns;
            check(an_n = expected_an_n(s),
                  "slot " & integer'image(s) & ": an_n one-hot at index " & integer'image(s),
                  err_count);
            check(count_zeros(an_n) = 1,
                  "slot " & integer'image(s) & ": an_n is one-hot-low",
                  err_count);
            check(seg_n = patterns(s),
                  "slot " & integer'image(s) & ": seg_n = patterns(" & integer'image(s) & ")",
                  err_count);
        end procedure;

        procedure advance_one_slot is
        begin
            for i in 0 to DIV-1 loop
                wait until rising_edge(clk);
            end loop;
        end procedure;

    begin
        ------------------------------------------------------------------------
        -- Reset
        ------------------------------------------------------------------------
        rst <= '1';
        for i in 0 to 3 loop wait until rising_edge(clk); end loop;
        rst <= '0';
        verify_slot(0);

        ------------------------------------------------------------------------
        -- Walk through slots 1..7, then verify wrap to 0 and one more cycle.
        ------------------------------------------------------------------------
        for s in 1 to 7 loop
            advance_one_slot;
            verify_slot(s);
        end loop;

        advance_one_slot;
        verify_slot(0);  -- wrapped

        for s in 1 to 3 loop
            advance_one_slot;
            verify_slot(s);
        end loop;

        ------------------------------------------------------------------------
        -- Mid-operation reset must return to slot 0
        ------------------------------------------------------------------------
        wait until rising_edge(clk);
        rst <= '1';
        for i in 0 to 2 loop wait until rising_edge(clk); end loop;
        rst <= '0';
        verify_slot(0);

        ------------------------------------------------------------------------
        -- Done
        ------------------------------------------------------------------------
        if err_count = 0 then
            report "==== TB_SEG_MUX: ALL CHECKS PASSED ====" severity note;
        else
            report "==== TB_SEG_MUX: " & integer'image(err_count) & " FAILURES ====" severity failure;
        end if;

        sim_done <= true;
        wait;
    end process;

end architecture sim;
