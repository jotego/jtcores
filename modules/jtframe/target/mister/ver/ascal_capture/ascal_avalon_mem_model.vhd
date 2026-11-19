-- Independent simulation-only HPS SDRAM model for jtcores #224.
-- Copyright (c) 2026 Jose Tejada. SPDX-License-Identifier: GPL-3.0-or-later
-- Transactions on different pages may retire out of arrival order. Reads force
-- older overlapping writes to retire. ORDER_SAME_PAGE additionally models the
-- documented same-page ordering; its default false is a weaker adversarial test.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ascal_avalon_mem_model is
    generic (
        BASE_ADDRESS             : natural := 16#20000000#;
        RAMSIZE_BYTES            : positive := 16#800000#;
        SLOT_FOOTPRINT_BYTES     : positive := 65536;
        SLOTS                    : positive := 3;
        REORDER_CROSS_PAGE       : boolean := true;
        ORDER_SAME_PAGE          : boolean := false;
        PAGE_BYTES               : positive := 4096;
        QUEUE_DEPTH              : positive := 32;
        MAX_BURST_BEATS          : positive := 32;
        FENCE_CORRUPT_BEAT        : natural range 0 to 16 := 16;
        BACKGROUND_WRITE_DELAY   : natural := 128;
        READ_LATENCY_CYCLES      : natural := 3;
        READ_GAP_CYCLES          : natural := 1;
        STALL_PERIOD             : positive := 17;
        STALL_CYCLES             : natural := 5
    );
    port (
        clk              : in std_logic;
        waitrequest      : out std_logic;
        readdata         : out std_logic_vector(127 downto 0) := (others => '0');
        readdatavalid    : out std_logic := '0';
        burstcount       : in std_logic_vector(7 downto 0);
        writedata        : in std_logic_vector(127 downto 0);
        address          : in std_logic_vector(27 downto 0);
        write            : in std_logic;
        read             : in std_logic;
        byteenable       : in std_logic_vector(15 downto 0);
        reset            : in std_logic := '0';
        -- Test-only global backpressure. It can hold the first beat of an
        -- unconsumed burst without making waitrequest depend on master data.
        stall_all        : in std_logic := '0';
        stall_enable     : in std_logic := '0';
        stall_target_last: in std_logic := '0';
        phase_seed       : in natural := 0;
        -- Disable background retirement without disabling read dependencies.
        background_enable: in std_logic := '1';
        -- A registered debug read of committed RAM; never drains queued writes.
        observe_address  : in std_logic_vector(27 downto 0) :=
                              std_logic_vector(to_unsigned(BASE_ADDRESS / 16, 28));
        observe_data     : out std_logic_vector(127 downto 0) := (others => '0');
        accepted_write_beats : out unsigned(63 downto 0) := (others => '0');
        committed_write_beats: out unsigned(63 downto 0) := (others => '0');
        returned_read_beats  : out unsigned(63 downto 0) := (others => '0');
        pending_writes   : out natural := 0;
        pending_reads    : out natural := 0;
        accepted_write  : out std_logic := '0';
        accepted_address: out std_logic_vector(31 downto 0) := (others => '0');
        accepted_last   : out std_logic := '0';
        committed_write : out std_logic := '0';
        committed_address:out std_logic_vector(31 downto 0) := (others => '0');
        committed_last  : out std_logic := '0';
        returned_read   : out std_logic := '0';
        returned_address: out std_logic_vector(31 downto 0) := (others => '0');
        returned_last   : out std_logic := '0';
        fence_corrupt_drain_done : out std_logic := '0';
        fault           : out std_logic := '0'
    );
end entity;

architecture simulation of ascal_avalon_mem_model is
    subtype word_t is std_logic_vector(127 downto 0);
    subtype mask_t is std_logic_vector(15 downto 0);
    type words_t is array (0 to MAX_BURST_BEATS-1) of word_t;
    type masks_t is array (0 to MAX_BURST_BEATS-1) of mask_t;
    type operation_t is record
        valid, is_read, complete : boolean;
        sequence_id, base, beats, received, born : natural;
        words : words_t;
        masks : masks_t;
    end record;
    constant EMPTY_OP : operation_t := (
        valid => false, is_read => false, complete => false,
        sequence_id => 0, base => 0, beats => 0, received => 0, born => 0,
        words => (others => (others => '0')),
        masks => (others => (others => '0')));
    type operations_t is array (0 to QUEUE_DEPTH-1) of operation_t;
    type ram_t is array (0 to SLOTS*SLOT_FOOTPRINT_BYTES-1)
        of std_logic_vector(7 downto 0);
    signal full_queue : boolean := false;
    signal filling_write : boolean := false;
    signal filling_last : boolean := false;
    signal tick_count : natural := 0;
    signal wait_i : std_logic;

    function physical_byte(a : std_logic_vector(27 downto 0)) return natural is
        variable b : unsigned(31 downto 0);
    begin
        assert not is_x(a) report "FAIL model unknown Avalon address" severity failure;
        b := unsigned(a) & "0000";
        assert b <= to_unsigned(integer'high, 32)
            report "FAIL model address exceeds natural implementation range" severity failure;
        return to_integer(b);
    end function;

    function compact_index(a : natural) return natural is
        variable delta, slot, off : natural;
    begin
        assert a >= BASE_ADDRESS report "FAIL model address below framebuffer" severity failure;
        delta := a - BASE_ADDRESS;
        slot := delta / RAMSIZE_BYTES;
        off := delta mod RAMSIZE_BYTES;
        assert slot < SLOTS report "FAIL model framebuffer slot out of bounds" severity failure;
        assert off < SLOT_FOOTPRINT_BYTES
            report "FAIL model address exceeds compact slot footprint" severity failure;
        return slot*SLOT_FOOTPRINT_BYTES + off;
    end function;

    function same_page(a, b : operation_t) return boolean is
    begin
        return a.base/PAGE_BYTES <= (b.base+b.beats*16-1)/PAGE_BYTES and
               b.base/PAGE_BYTES <= (a.base+a.beats*16-1)/PAGE_BYTES;
    end function;

    function ordered_addresses(a, b : operation_t) return boolean is
    begin
        if ORDER_SAME_PAGE then return same_page(a, b); end if;
        return a.base < b.base+b.beats*16 and b.base < a.base+a.beats*16;
    end function;

    function eligible(q : operations_t; k : natural) return boolean is
    begin
        if not q(k).valid or not q(k).complete then return false; end if;
        for j in q'range loop
            if q(j).valid and q(j).sequence_id < q(k).sequence_id then
                if not REORDER_CROSS_PAGE or ordered_addresses(q(j), q(k)) then
                    return false;
                end if;
            end if;
        end loop;
        return true;
    end function;
begin
    assert SLOT_FOOTPRINT_BYTES <= RAMSIZE_BYTES
        report "FAIL compact footprint exceeds slot stride" severity failure;
    assert BASE_ADDRESS mod 16 = 0 and SLOT_FOOTPRINT_BYTES mod 16 = 0
        report "FAIL unaligned memory model geometry" severity failure;
    assert STALL_CYCLES < STALL_PERIOD
        report "FAIL periodic stalls must eventually release" severity failure;
    -- waitrequest is independent of master write/read to avoid a combinational
    -- loop in a master which selects the next DPRAM word from waitrequest.
    wait_i <= '1' when reset = '1' or stall_all = '1' or
        (full_queue and not filling_write) or
        (stall_target_last = '1' and filling_last) or
        (stall_enable = '1' and
         ((tick_count mod STALL_PERIOD + phase_seed mod STALL_PERIOD)
            mod STALL_PERIOD) < STALL_CYCLES) else '0';
    waitrequest <= wait_i;

    process(clk)
        variable ram : ram_t := (others => (others => '0'));
        variable q : operations_t := (others => EMPTY_OP);
        variable fill, active_write, active_read : integer := -1;
        variable write_beat, read_beat, read_delay : natural := 0;
        variable next_sequence : natural := 1;
        variable naccepted, ncommitted, nreturned : unsigned(63 downto 0) := (others => '0');
        variable had_stall : boolean := false;
        variable held_address : std_logic_vector(27 downto 0);
        variable held_burst : std_logic_vector(7 downto 0);
        variable held_data : word_t;
        variable held_be : mask_t;
        variable held_write, held_read : std_logic;
        variable free_index, earliest_read, chosen : integer;
        variable a, ix, base_ix, beats, nw, nr : natural;
        variable value : word_t;
        variable urgent : boolean;
        variable fence_corrupted, fence_corrupt_active : boolean := false;
        procedure check(ok : boolean; message : string) is
        begin
            if not ok then
                fault <= '1';
                assert false report "FAIL " & message severity failure;
            end if;
        end procedure;
    begin
        if rising_edge(clk) then
            readdatavalid <= '0';
            accepted_write <= '0'; accepted_last <= '0';
            committed_write <= '0'; committed_last <= '0';
            returned_read <= '0'; returned_last <= '0';
            if reset = '1' then
                q := (others => EMPTY_OP);
                fill := -1; active_write := -1; active_read := -1;
                write_beat := 0; read_beat := 0; read_delay := 0;
                next_sequence := 1; tick_count <= 0;
                naccepted := (others => '0'); ncommitted := (others => '0');
                nreturned := (others => '0'); had_stall := false; fault <= '0';
                fence_corrupted := false; fence_corrupt_active := false;
                fence_corrupt_drain_done <= '0';
                -- RAM retains its committed contents across model reset.
            else
                tick_count <= tick_count + 1;
                check(write /= '1' or read /= '1', "simultaneous Avalon read/write");
                if had_stall then
                    check(address = held_address and burstcount = held_burst and
                          write = held_write and read = held_read,
                          "master changed stalled command");
                    if held_write = '1' then
                        check(writedata = held_data and byteenable = held_be,
                              "master changed stalled write data");
                    end if;
                end if;
                had_stall := wait_i = '1' and (write = '1' or read = '1');
                if had_stall then
                    held_address := address; held_burst := burstcount;
                    held_write := write; held_read := read;
                    held_data := writedata; held_be := byteenable;
                end if;

                -- Accept one beat (write) or one complete read command.
                if wait_i = '0' and (write = '1' or read = '1') then
                    check(not is_x(burstcount), "unknown burst count");
                    beats := to_integer(unsigned(burstcount));
                    check(beats > 0 and beats <= MAX_BURST_BEATS, "unsupported burst count");
                    a := physical_byte(address);
                    if write = '1' then
                        if is_x(writedata) or is_x(byteenable) then
                            assert false report "FAIL unknown write payload at " & to_hstring(address) &
                                " data=" & to_hstring(writedata) severity failure;
                        end if;
                        if fill = -1 then
                            free_index := -1;
                            for j in q'range loop
                                if not q(j).valid and free_index = -1 then free_index := j; end if;
                            end loop;
                            check(free_index /= -1, "write queue overflow");
                            fill := free_index; q(fill) := EMPTY_OP;
                            q(fill).valid := true; q(fill).base := a;
                            q(fill).beats := beats; q(fill).born := tick_count;
                            q(fill).sequence_id := next_sequence;
                            next_sequence := next_sequence + 1;
                            ix := compact_index(a);
                            ix := compact_index(a + beats*16-1);
                        else
                            check(a = q(fill).base and beats = q(fill).beats,
                                  "ascal changed burst base/length between write beats");
                        end if;
                        ix := q(fill).received;
                        q(fill).words(ix) := writedata;
                        q(fill).masks(ix) := byteenable;
                        accepted_write <= '1';
                        accepted_address <= std_logic_vector(to_unsigned(a + ix*16, 32));
                        naccepted := naccepted + 1;
                        q(fill).received := ix + 1;
                        if q(fill).received = q(fill).beats then
                            accepted_last <= '1'; q(fill).complete := true; fill := -1;
                        end if;
                    else
                        check(fill = -1, "read command inside incomplete write burst");
                        free_index := -1;
                        for j in q'range loop
                            if not q(j).valid and free_index = -1 then free_index := j; end if;
                        end loop;
                        check(free_index /= -1, "read queue overflow");
                        q(free_index) := EMPTY_OP;
                        q(free_index).valid := true; q(free_index).complete := true;
                        q(free_index).is_read := true; q(free_index).base := a;
                        q(free_index).beats := beats; q(free_index).born := tick_count;
                        q(free_index).sequence_id := next_sequence;
                        next_sequence := next_sequence + 1;
                        ix := compact_index(a);
                        ix := compact_index(a + beats*16-1);
                    end if;
                end if;

                -- Commit buffered writes a beat at a time; acceptance did not
                -- modify RAM. Keep the operation valid through the final beat.
                if active_write /= -1 then
                    a := q(active_write).base + write_beat*16;
                    ix := compact_index(a);
                    for b in 0 to 15 loop
                        if q(active_write).masks(write_beat)(b) = '1' then
                            ram(ix+b) := q(active_write).words(write_beat)(8*b+7 downto 8*b);
                        end if;
                    end loop;
                    committed_write <= '1';
                    committed_address <= std_logic_vector(to_unsigned(a, 32));
                    ncommitted := ncommitted + 1;
                    write_beat := write_beat + 1;
                    if write_beat = q(active_write).beats then
                        committed_last <= '1'; q(active_write).valid := false;
                        active_write := -1;
                    end if;
                end if;

                -- Return reads in request order, sampling actual committed RAM.
                if active_read /= -1 then
                    if read_delay /= 0 then
                        read_delay := read_delay - 1;
                    else
                        a := q(active_read).base + read_beat*16;
                        ix := compact_index(a);
                        for b in 0 to 15 loop value(8*b+7 downto 8*b) := ram(ix+b); end loop;
                        if not fence_corrupted and FENCE_CORRUPT_BEAT<16 and
                           read_beat=FENCE_CORRUPT_BEAT and q(active_read).beats=16 and
                           q(active_read).base>=BASE_ADDRESS and
                           (q(active_read).base-BASE_ADDRESS) mod RAMSIZE_BYTES=0 then
                            base_ix:=compact_index(q(active_read).base);
                            if ram(base_ix+192)=x"4A" and ram(base_ix+193)=x"54" and
                               ram(base_ix+194)=x"43" and ram(base_ix+195)=x"32" and
                               ram(base_ix+252)=x"52" and ram(base_ix+253)=x"44" and
                               ram(base_ix+254)=x"59" and ram(base_ix+255)=x"32" then
                                value(0):=not value(0);
                                fence_corrupted:=true;
                                fence_corrupt_active:=true;
                                report "injected exact-header fence corruption at beat " &
                                    integer'image(FENCE_CORRUPT_BEAT) severity note;
                            end if;
                        end if;
                        readdata <= value; readdatavalid <= '1'; returned_read <= '1';
                        returned_address <= std_logic_vector(to_unsigned(a, 32));
                        nreturned := nreturned + 1; read_beat := read_beat + 1;
                        if fence_corrupt_active and read_beat=q(active_read).beats then
                            fence_corrupt_active:=false;
                            fence_corrupt_drain_done<='1';
                            report "completed corrupted fence burst with all 16 returned beats" severity note;
                        end if;
                        if read_beat = q(active_read).beats then
                            returned_last <= '1'; q(active_read).valid := false;
                            active_read := -1;
                        else
                            read_delay := READ_GAP_CYCLES;
                        end if;
                    end if;
                end if;

                earliest_read := -1;
                for j in q'range loop
                    if q(j).valid and q(j).is_read then
                        if earliest_read = -1 then earliest_read := j;
                        elsif q(j).sequence_id < q(earliest_read).sequence_id then earliest_read := j;
                        end if;
                    end if;
                end loop;
                if active_read = -1 and earliest_read /= -1 then
                    if eligible(q, earliest_read) then
                        active_read := earliest_read; read_beat := 0;
                        read_delay := READ_LATENCY_CYCLES;
                    end if;
                end if;

                if active_write = -1 then
                    chosen := -1;
                    for j in q'range loop
                        if q(j).valid and not q(j).is_read and eligible(q, j) then
                            urgent := false;
                            -- An earlier read's older dependent writes are required
                            -- even when background_enable is disabled.
                            for k in q'range loop
                                if q(k).valid and q(k).is_read and
                                   q(j).sequence_id < q(k).sequence_id and ordered_addresses(q(j), q(k)) then
                                    urgent := true;
                                end if;
                            end loop;
                            if urgent or (background_enable = '1' and
                                tick_count-q(j).born >= BACKGROUND_WRITE_DELAY) then
                                if chosen = -1 then chosen := j;
                                elsif REORDER_CROSS_PAGE and
                                      q(j).sequence_id > q(chosen).sequence_id then chosen := j;
                                end if;
                            end if;
                        end if;
                    end loop;
                    if chosen /= -1 then active_write := chosen; write_beat := 0; end if;
                end if;
            end if;

            nw := 0; nr := 0; free_index := -1;
            for j in q'range loop
                if q(j).valid then
                    if q(j).is_read then nr := nr + 1; else nw := nw + 1; end if;
                else free_index := j;
                end if;
            end loop;
            pending_writes <= nw; pending_reads <= nr;
            full_queue <= free_index = -1;
            filling_write <= fill /= -1;
            filling_last <= false;
            if fill /= -1 then filling_last <= q(fill).received + 1 = q(fill).beats; end if;
            accepted_write_beats <= naccepted;
            committed_write_beats <= ncommitted;
            returned_read_beats <= nreturned;
            a := physical_byte(observe_address); ix := compact_index(a);
            for b in 0 to 15 loop value(8*b+7 downto 8*b) := ram(ix+b); end loop;
            observe_data <= value;
        end if;
    end process;
end architecture;
