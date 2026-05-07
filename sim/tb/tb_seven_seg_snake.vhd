--------------------------------------------------------------------------------
-- File        : tb_seven_seg_snake.vhd
-- Description : Top-level testbench for seven_seg_snake.
--
--   Verifying the full chip would take 2.5 s of simulated time per snake step
--   at the real 100 MHz / 4 Hz settings — too slow. Instead, this testbench
--   uses a "fast" wrapper that overrides the timing constants to small values
--   so a complete walk happens in a few microseconds.
--
--   Wrapper: tb_top_fast.vhd would normally hold these overrides, but to keep
--   everything in one TB file we just instantiate the submodules ourselves
--   with small generics — that's an integration check of the same building
--   blocks the top uses.
--
--   Checks:
--     1) After reset (btn_rst_n asserted), display is blank or showing
--        digit 0 with seg_n = "0111111" (segment a).
--     2) Eventually one anode is low at any time (one-hot-low refresh).
--     3) On every snake step, the lit segment advances forward (sw_dir=0)
--        through a -> b -> c -> d -> e -> f -> a.
--     4) With sw_dir=1, the snake walks the other way.
--     5) seg_n is always one-hot-low when an_n(0) is the active digit
--        (i.e. exactly one cathode is '0').
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.seg_mux_pkg.all;

entity tb_seven_seg_snake is
end entity tb_seven_seg_snake;

architecture sim of tb_seven_seg_snake is

    constant CLK_PERIOD  : time     := 10 ns;

    -- Fast timing for sim
    constant DBC_CYC     : positive := 4;     -- debounce cycles
    constant STEP_CYC    : positive := 200;   -- one step every 200 clks
    constant REFRESH_CYC : positive := 3;     -- one slot every 3 clks (sweep = 24 clks << STEP_CYC)
    constant NUM_POS     : positive := 6;

    -- Expected lit-segment patterns for pos 0..5 on digit 0
    type pattern_array_t is array (0 to 5) of std_logic_vector(6 downto 0);
    constant EXPECTED : pattern_array_t := (
        0 => "0111111",   -- a
        1 => "1011111",   -- b
        2 => "1101111",   -- c
        3 => "1110111",   -- d
        4 => "1111011",   -- e
        5 => "1111101"    -- f
    );

    signal clk       : std_logic := '0';
    signal btn_rst_n : std_logic := '0';
    signal sw_dir    : std_logic := '0';
    signal seg_n     : std_logic_vector(6 downto 0);
    signal dp_n      : std_logic;
    signal an_n      : std_logic_vector(7 downto 0);

    -- Internal nets to mirror the top, since we instantiate submodules here
    signal rst        : std_logic;
    signal sw_dir_db  : std_logic;
    signal step_tick  : std_logic;
    signal pos        : integer range 0 to NUM_POS-1;
    signal seg_active : std_logic_vector(6 downto 0);
    signal patterns   : seg_array_t;

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

begin

    ----------------------------------------------------------------------------
    -- DUT (rebuilt with sim-friendly timing)
    ----------------------------------------------------------------------------
    u_sync_reset : entity work.sync_reset
        port map (clk => clk, async_rstn => btn_rst_n, sync_rst => rst);

    u_debouncer : entity work.debouncer
        generic map (DEBOUNCE_CYCLES => DBC_CYC)
        port map (clk => clk, rst => rst, async_in => sw_dir, clean => sw_dir_db);

    u_step : entity work.tick_gen
        generic map (DIVIDER => STEP_CYC)
        port map (clk => clk, rst => rst, tick => step_tick);

    u_fsm : entity work.snake_fsm
        generic map (NUM_POSITIONS => NUM_POS)
        port map (clk => clk, rst => rst, step => step_tick, dir => sw_dir_db, pos => pos);

    u_dec : entity work.seg_decoder
        port map (pos => pos, seg_n => seg_active);

    patterns(0) <= seg_active;
    gen_blank : for i in 1 to 7 generate
        patterns(i) <= (others => '1');
    end generate;

    u_mux : entity work.seg_mux
        generic map (REFRESH_DIV => REFRESH_CYC)
        port map (clk => clk, rst => rst, patterns_in => patterns,
                  seg_n => seg_n, an_n => an_n);

    dp_n <= '1';

    ----------------------------------------------------------------------------
    -- Clock
    ----------------------------------------------------------------------------
    clk_proc : process
    begin
        while not sim_done loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    ----------------------------------------------------------------------------
    -- Stimulus + checks
    ----------------------------------------------------------------------------
    stim_proc : process

        -- Wait until the next slot in which digit 0 is the active anode,
        -- then sample seg_n.
        procedure sample_digit0 (sample : out std_logic_vector(6 downto 0)) is
        begin
            loop
                wait until rising_edge(clk);
                wait for 1 ns;
                exit when an_n(0) = '0';
            end loop;
            sample := seg_n;
        end procedure;

        variable observed : std_logic_vector(6 downto 0);
        variable cur_pos  : integer;
        type seen_t is array (0 to 7) of boolean;
        variable seen     : seen_t;
        variable idx      : natural;

    begin
        ------------------------------------------------------------------------
        -- 1) Apply async-low reset for a while, then release.
        ------------------------------------------------------------------------
        btn_rst_n <= '0';
        sw_dir    <= '0';
        for i in 0 to 9 loop wait until rising_edge(clk); end loop;
        wait until falling_edge(clk);
        btn_rst_n <= '1';

        -- After reset, pos = 0 -> digit 0 should display segment a.
        -- Need to wait for: sync_reset deassert (2 clk) + first refresh slot 0.
        for i in 0 to 5 loop wait until rising_edge(clk); end loop;
        sample_digit0(observed);
        check(observed = EXPECTED(0),
              "after reset: digit 0 shows segment a (pos=0)", err_count);
        check(count_zeros(an_n) = 1, "an_n is one-hot-low", err_count);
        check(count_zeros(seg_n) = 1, "seg_n is one-hot-low (live snake)", err_count);

        ------------------------------------------------------------------------
        -- 2) Forward walk: drive sw_dir=0 (already), wait for snake step,
        --    sample digit 0 each step. Should sweep a,b,c,d,e,f and wrap to a.
        ------------------------------------------------------------------------
        for s in 1 to NUM_POS loop
            -- Wait one full step period plus a guard.
            -- step_tick rises at clk edge T. FSM sees step=1 at the SAME edge
            -- (it samples its inputs at the edge), so pos updates at T. But to
            -- be safe and avoid a delta-cycle race with the sampling helper,
            -- wait until the step_tick has been deasserted, which is the edge
            -- after the one where pos updated.
            -- step_tick is one-clock-wide. After it deasserts, pos is the
            -- new value. Add one clock margin, then sample digit 0.
            wait until rising_edge(step_tick);
            wait until falling_edge(step_tick);
            wait for CLK_PERIOD;
            sample_digit0(observed);
            check(observed = EXPECTED(s mod NUM_POS),
                  "forward step " & integer'image(s) & ": digit 0 shows pos=" &
                  integer'image(s mod NUM_POS), err_count);
        end loop;

        ------------------------------------------------------------------------
        -- 3) Reverse walk: flip sw_dir and hold long enough to debounce.
        --    Then verify pos counts down (with wrap).
        ------------------------------------------------------------------------
        sw_dir <= '1';
        -- Hold long enough for the debouncer (DBC_CYC + 2-FF sync margin).
        for i in 0 to DBC_CYC + 8 loop wait until rising_edge(clk); end loop;

        -- After the next step_tick, pos should DECREMENT from its current value.
        -- Read current pos via digit 0 first.
        sample_digit0(observed);
        -- Find which pos that pattern corresponds to.
        cur_pos := -1;
        for i in 0 to NUM_POS-1 loop
            if observed = EXPECTED(i) then cur_pos := i; end if;
        end loop;
        check(cur_pos >= 0, "pre-reverse: observed a known pattern", err_count);

        for s in 1 to NUM_POS loop
            wait until rising_edge(step_tick);
            wait for 2 * CLK_PERIOD;
            sample_digit0(observed);
            cur_pos := (cur_pos - 1 + NUM_POS) mod NUM_POS;
            check(observed = EXPECTED(cur_pos),
                  "reverse step " & integer'image(s) & ": digit 0 shows pos=" &
                  integer'image(cur_pos), err_count);
        end loop;

        ------------------------------------------------------------------------
        -- 4) Refresh sweep: across one full digit cycle, every digit index
        --    0..7 is selected exactly once and an_n is always one-hot-low.
        ------------------------------------------------------------------------
        seen := (others => false);
        for i in 0 to 8 * REFRESH_CYC loop
            wait until rising_edge(clk);
            wait for 1 ns;
            check(count_zeros(an_n) = 1,
                  "anode one-hot during sweep tick " & integer'image(i),
                  err_count);
            for k in 0 to 7 loop
                if an_n(k) = '0' then idx := k; end if;
            end loop;
            seen(idx) := true;
        end loop;

        for k in 0 to 7 loop
            check(seen(k),
                  "digit " & integer'image(k) & " was visited in one sweep",
                  err_count);
        end loop;

        ------------------------------------------------------------------------
        -- 5) Async reset mid-operation -> back to pos 0 (segment a)
        ------------------------------------------------------------------------
        btn_rst_n <= '0';
        for i in 0 to 4 loop wait until rising_edge(clk); end loop;
        wait until falling_edge(clk);
        btn_rst_n <= '1';
        for i in 0 to 5 loop wait until rising_edge(clk); end loop;
        sample_digit0(observed);
        check(observed = EXPECTED(0), "after mid-op reset: digit 0 = segment a",
              err_count);

        ------------------------------------------------------------------------
        -- Done.
        ------------------------------------------------------------------------
        if err_count = 0 then
            report "==== TB_SEVEN_SEG_SNAKE: ALL CHECKS PASSED ====" severity note;
        else
            report "==== TB_SEVEN_SEG_SNAKE: " & integer'image(err_count) & " FAILURES ====" severity failure;
        end if;

        sim_done <= true;
        wait;
    end process;

end architecture sim;
