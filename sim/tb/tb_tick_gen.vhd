--------------------------------------------------------------------------------
-- File        : tb_tick_gen.vhd
-- Description : Self-checking testbench for tick_gen.
--
--   Uses a small DIVIDER (5) so tick events are easy to count. Checks:
--     1) Reset holds tick = '0'.
--     2) After reset is released, the first tick fires exactly DIVIDER
--        clocks later.
--     3) Tick is exactly one clock wide.
--     4) Subsequent ticks fire every DIVIDER clocks (period stable across
--        many cycles).
--     5) Synchronous reset mid-stream restarts the cadence from scratch.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_tick_gen is
end entity tb_tick_gen;

architecture sim of tb_tick_gen is

    constant CLK_PERIOD : time     := 10 ns;
    constant DIV        : positive := 5;

    signal clk  : std_logic := '0';
    signal rst  : std_logic := '1';
    signal tick : std_logic;

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

begin

    dut : entity work.tick_gen
        generic map (
            DIVIDER => DIV
        )
        port map (
            clk  => clk,
            rst  => rst,
            tick => tick
        );

    clk_proc : process
    begin
        while not sim_done loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    stim_proc : process
        variable cnt_clks : natural;
    begin
        ------------------------------------------------------------------------
        -- 1) Reset holds tick low
        ------------------------------------------------------------------------
        rst <= '1';
        for i in 0 to 3 loop wait until rising_edge(clk); end loop;
        wait for 1 ns;
        check(tick = '0', "during reset: tick = 0", err_count);

        ------------------------------------------------------------------------
        -- 2) Release reset; first tick should fire DIVIDER clocks later.
        --    Counter starts at 0 and pulses when cnt = DIV-1, i.e. on the
        --    DIV-th rising edge after release.
        --    Deassert rst BETWEEN edges so the DUT sees rst=0 at the next edge.
        ------------------------------------------------------------------------
        wait until falling_edge(clk);
        rst <= '0';
        cnt_clks := 0;
        loop
            wait until rising_edge(clk);
            wait for 1 ns;  -- let DUT outputs settle past the delta
            cnt_clks := cnt_clks + 1;
            exit when tick = '1';
            if cnt_clks > DIV + 2 then
                report "CHECK FAIL: first tick never fired" severity error;
                err_count <= err_count + 1;
                exit;
            end if;
        end loop;
        check(cnt_clks = DIV,
              "first tick fired after exactly DIVIDER clocks (got " &
              integer'image(cnt_clks) & ")", err_count);

        ------------------------------------------------------------------------
        -- 3) Period: measure intervals between several subsequent ticks.
        --    Each iteration counts rising edges from one tick to the next.
        --    Tick must also be exactly one clock wide: when we resume the
        --    loop, the previous tick should have already deasserted.
        ------------------------------------------------------------------------
        for n in 1 to 5 loop
            -- Skip past the just-asserted tick edge. The DUT clears tick
            -- on the next rising edge, so this also implicitly verifies
            -- the one-clock-wide property.
            wait until rising_edge(clk);
            wait for 1 ns;
            check(tick = '0', "tick is one clock wide before period #" &
                  integer'image(n), err_count);
            cnt_clks := 1;  -- account for the rising edge consumed above
            loop
                wait until rising_edge(clk);
                wait for 1 ns;
                cnt_clks := cnt_clks + 1;
                exit when tick = '1';
                if cnt_clks > DIV + 2 then exit; end if;
            end loop;
            check(cnt_clks = DIV,
                  "tick period #" & integer'image(n) & " = DIVIDER (got " &
                  integer'image(cnt_clks) & ")", err_count);
        end loop;

        ------------------------------------------------------------------------
        -- 4) Mid-stream reset restarts the cadence.
        ------------------------------------------------------------------------
        wait until rising_edge(clk);
        rst <= '1';
        for i in 0 to 1 loop wait until rising_edge(clk); end loop;
        wait for 1 ns;
        check(tick = '0', "during mid-op reset: tick = 0", err_count);

        wait until falling_edge(clk);
        rst <= '0';
        cnt_clks := 0;
        loop
            wait until rising_edge(clk);
            wait for 1 ns;  -- let DUT outputs settle past the delta
            cnt_clks := cnt_clks + 1;
            exit when tick = '1';
            if cnt_clks > DIV + 2 then
                report "CHECK FAIL: post-reset tick never fired" severity error;
                err_count <= err_count + 1;
                exit;
            end if;
        end loop;
        check(cnt_clks = DIV,
              "post-reset first tick after DIVIDER clocks (got " &
              integer'image(cnt_clks) & ")", err_count);

        ------------------------------------------------------------------------
        -- Done
        ------------------------------------------------------------------------
        if err_count = 0 then
            report "==== TB_TICK_GEN: ALL CHECKS PASSED ====" severity note;
        else
            report "==== TB_TICK_GEN: " & integer'image(err_count) & " FAILURES ====" severity failure;
        end if;

        sim_done <= true;
        wait;
    end process;

end architecture sim;
