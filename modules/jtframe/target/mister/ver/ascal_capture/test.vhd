library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use std.textio.all;

entity test is
    generic (
        CAPTURE_ENABLE : boolean := true;
        CAPTURE_ARM_CHECKPOINT : natural := 0;
        ARM_CAPTURE : boolean := true;
        INVALID_ARM_TEST : boolean := false;
        VIDEO_TRACE : boolean := false;
        BUS_TRACE : boolean := false;
        INPUT_HALF_NS : positive := 11;
        AVL_PHASE_NS : natural := 0;
        MEM_STALL_CYCLES : natural := 5;
        TEST_IDLE_PROGRESS : boolean := false;
        INTERLACED_SOURCE : boolean := false;
        SEED_WRITE_IDS_NEAR_WRAP : boolean := false;
        COALESCE_TWO_ACKS : boolean := false;
        STALL_CAPTURE_FINAL : boolean := false;
        STALL_TWO_OUTSTANDING : boolean := false;
        STALL_TWO_ABORT : boolean := false;
        HOLD_READY_TO_DONE : boolean := false;
        ABORT_AFTER_ARM : boolean := false;
        ABORT_BEFORE_FIRST_FRAME : boolean := false;
        BAD_RELEASE_THEN_ABORT : boolean := false;
        RELEASE_BEFORE_READY : boolean := false;
        WATCHDOG_AFTER_BAD_RELEASE : boolean := false;
        LIFECYCLE_ERROR_BEFORE_ARM : boolean := false;
        LIFECYCLE_UNKNOWN_BEFORE_ARM : boolean := false;
        LIFECYCLE_RUNNING_BEFORE_ARM : boolean := false;
        LIFECYCLE_ARMED_REARM : boolean := false;
        LIFECYCLE_UNEXPECTED_REARM : boolean := false;
        LIFECYCLE_UNKNOWN_ACTIVE_REARM : boolean := false;
        LIFECYCLE_REARM_RACE : boolean := false;
        LIFECYCLE_START_ARM_RACE : boolean := false;
        LIFECYCLE_DONE_ARM_RACE : boolean := false;
        LIFECYCLE_STOP_BEFORE_TARGET : boolean := false;
        REARM_AFTER_CLEANUP : boolean := false;
        EXPECT_WATCHDOG : boolean := false;
        HALT_INPUT_CLOCK_ON_READY : boolean := false;
        UNSUPPORTED_MODE_ARM : boolean := false;
        ARMED_FAULT_WATCHDOG : boolean := false;
        DOUBLE_CAPTURE_SUCCESS : boolean := false;
        RESET_READY_RESULT : boolean := false;
        CLEAN_IDLE_ONLY : boolean := false;
        LARGE_SCAN_TEST : boolean := false;
        FENCE_CORRUPTION_TEST : boolean := false;
        CAPTURE_HOLD_MS : natural := 1000;
        WATCHDOG_CYCLES_PER_MS : natural := 100000;
        EXPECT_WRITE_COLLISION : boolean := false;
        COLLISION_STALL_HALF0 : boolean := false;
        COLLISION_STALL_HALF1 : boolean := false;
        FENCE_CORRUPT_BEAT : natural range 0 to 16 := 16;
        PADDING_FILL : std_logic_vector(7 downto 0) := x"00"
    );
end entity;

architecture tb of test is
    constant BASE_ADDRESS : natural := 16#20000000#;
    constant RAMSIZE_BYTES : natural := 16#200000#;
    function choose(large_i : boolean; small_i,big_i : natural) return natural is
    begin
        if large_i then return big_i; end if;
        return small_i;
    end function;
    function choose_sl(large_i : boolean; small_i,big_i : std_logic) return std_logic is
    begin
        if large_i then return big_i; end if;
        return small_i;
    end function;
    constant TEST_IAUTO : std_logic := choose_sl(LARGE_SCAN_TEST,'1','0');
    constant TEST_ACTIVE_HEIGHT : natural := choose(LARGE_SCAN_TEST,9,600);
    constant TEST_VTOTAL : natural := choose(LARGE_SCAN_TEST,32,624);
    constant TEST_FRAME_COUNT : natural := choose(LARGE_SCAN_TEST,20,8);
    constant TEST_SCAN_BURSTS : natural := TEST_ACTIVE_HEIGHT*2;
    constant SLOT_FOOTPRINT_BYTES : natural := choose(LARGE_SCAN_TEST,65536,1048576);
    procedure check_visible_slot(
        signal address_o : out std_logic_vector(27 downto 0);
        signal data_i : in std_logic_vector(127 downto 0);
        signal clk_i : in std_logic;
        constant slot_i, frame_i : in natural
    ) is
        variable pixel_byte_i,row_byte_i,xpix_i,channel_i,row_i : natural;
        variable value_i : natural;
    begin
        for sample_i in 0 to 11 loop
            if LARGE_SCAN_TEST or sample_i<9 then
              if LARGE_SCAN_TEST and sample_i>=9 then
                  case sample_i is
                      when 9 => row_i:=511;
                      when 10 => row_i:=512;
                      when others => row_i:=599;
                  end case;
              else
                  row_i:=sample_i;
              end if;
            for word_i in 0 to 16 loop
                pixel_byte_i:=BASE_ADDRESS+slot_i*RAMSIZE_BYTES+256+row_i*512+word_i*16;
                address_o<=std_logic_vector(to_unsigned(pixel_byte_i/16,28));
                wait until falling_edge(clk_i);
                wait until falling_edge(clk_i);
                assert not is_x(data_i) report "READY oracle found unknown selected-slot pixel data" severity failure;
                for lane_i in 0 to 15 loop
                    row_byte_i:=word_i*16+lane_i;
                    if row_byte_i<261 then
                        xpix_i:=4+row_byte_i/3;
                        channel_i:=row_byte_i mod 3;
                        value_i:=to_integer(unsigned(data_i(lane_i*8+7 downto lane_i*8)));
                        if channel_i=0 then
                            assert value_i=((frame_i*37) mod 256)
                                report "READY oracle red byte mismatch" severity failure;
                        elsif channel_i=1 then
                            assert value_i=xpix_i report "READY oracle green byte mismatch" severity failure;
                        else
                            assert value_i=(((row_i+4)*13+frame_i) mod 256)
                                report "READY oracle blue byte mismatch" severity failure;
                        end if;
                    end if;
                end loop;
            end loop;
            end if;
        end loop;
    end procedure;
    function calc_write_id_seed return unsigned is
    begin
        if SEED_WRITE_IDS_NEAR_WRAP then return x"FFFFFFFE"; end if;
        return x"00000000";
    end function;
    constant WRITE_ID_SEED : unsigned(31 downto 0) := calc_write_id_seed;
    type native_manifest_t is array (1 to 17) of integer range -1 to 20;
    function gfw1_oracle(hash_value, word_value : unsigned(31 downto 0)) return unsigned is
        variable polynomial : unsigned(32 downto 0);
    begin
        polynomial := ('0' & hash_value) sll 1;
        if polynomial(32)='1' then
            polynomial := polynomial xor ('1' & x"00400007");
        end if;
        return polynomial(31 downto 0) xor word_value;
    end function;

    function crc32_reference(data_i : std_logic_vector(447 downto 0)) return std_logic_vector is
        variable crc_v : unsigned(31 downto 0) := (others=>'1');
    begin
        for byte_i in 0 to 55 loop
            crc_v:=crc_v xor resize(unsigned(data_i(byte_i*8+7 downto byte_i*8)),32);
            for bit_i in 0 to 7 loop
                if crc_v(0)='1' then crc_v:=shift_right(crc_v,1) xor x"EDB88320";
                else crc_v:=shift_right(crc_v,1); end if;
            end loop;
        end loop;
        return std_logic_vector(not crc_v);
    end function;

    signal i_clk : std_logic := '0';
    signal input_clock_enable : std_logic := '1';
    signal coalesced_ack_test_passed : std_logic := '0';
    signal o_clk : std_logic := '0';
    signal avl_clk : std_logic := '0';
    signal reset_na : std_logic := '0';
    signal run : std_logic := '1';
    signal freeze_input : std_logic := '1';
    signal i_ce_enable : std_logic := '1';
    signal fifo_capacity_done : std_logic := '0';
    signal i_r,i_g,i_b : unsigned(7 downto 0) := (others=>'0');
    signal video_r,video_g,video_b : unsigned(7 downto 0);
    signal video_hs,video_vs,video_de : std_logic;
    signal video_hash : unsigned(31 downto 0) := x"811C9DC5";
    signal video_samples : natural := 0;
    signal video_nonblack : natural := 0;
    signal i_hs,i_vs,i_de : std_logic := '0';
    signal i_fl : std_logic := '0';
    signal ascal_i_vs : std_logic;
    signal native_lvbl : std_logic := '0';
    signal native_frame_id : integer range 0 to 20 := 0;
    signal native_manifest : native_manifest_t := (others=>-1);
    signal avl_waitrequest,avl_readdatavalid,avl_write,avl_read : std_logic;
    signal stall_all : std_logic := '0';
    signal stall_target_last : std_logic := '0';
    signal stall_release_seen : std_logic := '0';
    signal two_stall_ready : std_logic := '0';
    signal avl_burstcount : std_logic_vector(7 downto 0);
    signal avl_writedata,avl_readdata : std_logic_vector(127 downto 0);
    signal model_writedata : std_logic_vector(127 downto 0);
    signal avl_address : std_logic_vector(27 downto 0);
    signal avl_byteenable : std_logic_vector(15 downto 0);
    signal observe_address : std_logic_vector(27 downto 0) :=
        std_logic_vector(to_unsigned(BASE_ADDRESS/16+16,28));
    signal ready_observe_address : std_logic_vector(27 downto 0) :=
        std_logic_vector(to_unsigned(BASE_ADDRESS/16+16,28));
    signal ready_oracle_active : std_logic := '0';
    signal observe_data : std_logic_vector(127 downto 0);
    signal accepted_beats,committed_beats,returned_beats : unsigned(63 downto 0);
    signal pending_writes,pending_reads : natural;
    signal accepted_write,accepted_last,committed_write,committed_last : std_logic;
    signal returned_read,returned_last,model_fault : std_logic;
    signal fence_corrupt_drain_done : std_logic;
    signal accepted_address,committed_address,returned_address : std_logic_vector(31 downto 0);
    signal slot_mask : std_logic_vector(2 downto 0) := (others=>'0');
    signal collision_observe_address : std_logic_vector(27 downto 0) :=
        std_logic_vector(to_unsigned(BASE_ADDRESS/16+16,28));
    signal model_observe_address : std_logic_vector(27 downto 0);
    signal padding_unknown : std_logic := '0';
    signal first_header_done : std_logic := '0';
    signal write_beat_index : natural range 0 to 15 := 0;
    signal header_count : natural := 0;
    signal pad_substituted_bits : natural := 0;
    signal pad_first_address,pad_last_address : std_logic_vector(31 downto 0) := (others=>'0');

    signal cap_io_clk : std_logic := '0';
    signal cap_io_rst,cap_tag_rst : std_logic;
    signal cap_tag_clk : std_logic := '0';
    signal cap_tag_valid : std_logic := '0';
    signal cap_tag : std_logic_vector(14 downto 0) := (others=>'0');
    signal cap_req_toggle,cap_req_ack : std_logic := '0';
    signal cap_req : std_logic_vector(31 downto 0) := (others=>'0');
    signal capture_rearm_toggle,capture_rearm_ack : std_logic := '0';
    signal capture_rearm_bundle : std_logic_vector(31 downto 0) := (others=>'0');
    signal cap_release_toggle,cap_release_ack,cap_abort_toggle,cap_abort_ack : std_logic := '0';
    signal cap_mode_supported : std_logic := '1';
    signal mode_fault_inject : std_logic := '0';
    signal cap_release,cap_abort : std_logic_vector(15 downto 0) := (others=>'0');
    signal cap_life_toggle : std_logic := '0';
    signal cap_life : std_logic_vector(31 downto 0) := (others=>'0');
    signal native_tag_count : natural := 0;
    signal native_done : std_logic := '0';
    signal native_vs_rise_soon : std_logic := '0';
    signal held_write_snapshot_valid : std_logic := '0';
    signal held_write_snapshot : unsigned(63 downto 0) := (others=>'0');
    signal post_hold_target_pixel_writes : natural := 0;
    signal capture_request_acked : std_logic := '0';
    signal cap_life_ack : std_logic;
    signal capture_lifecycle_armed : std_logic := '0';
    signal lifecycle_rearm_request,lifecycle_rearm_done : std_logic := '0';
    signal lifecycle_start_race_fire,lifecycle_rearm_race_fire : std_logic := '0';
    signal cap_tag_ready,cap_result_toggle : std_logic;
    signal cap_result_ack : std_logic := '0';
    signal cap_result : std_logic_vector(511 downto 0);
    signal reset_after_ready_request,reset_after_ready_done : std_logic := '0';
    signal post_reset_arm_request,post_reset_arm_done : std_logic := '0';
    signal post_reset_life_done : std_logic := '0';
    signal cap_state,cap_fault : std_logic_vector(7 downto 0);
    signal release_test_done : std_logic := '0';
    signal clean_idle_arm_rejected : std_logic := '0';

    function life_packet(state,error_code : natural; completed : natural)
        return std_logic_vector is
        variable packet : std_logic_vector(31 downto 0) := (others=>'0');
    begin
        packet(14 downto 0) := std_logic_vector(to_unsigned(completed,15));
        packet(17 downto 15) := std_logic_vector(to_unsigned(state,3));
        packet(25 downto 18) := std_logic_vector(to_unsigned(error_code,8));
        return packet;
    end function;
begin
    InputClock: process
    begin
        loop
            wait for INPUT_HALF_NS * 1 ns;
            if input_clock_enable='1' then i_clk<=not i_clk; end if;
        end loop;
    end process;
    o_clk <= not o_clk after 7 ns;
    AvalonClock: process
    begin
        wait for AVL_PHASE_NS * 1 ns;
        loop
            wait for 5 ns;
            avl_clk<=not avl_clk;
        end loop;
    end process;
    cap_io_clk <= not cap_io_clk after 5 ns;
    cap_tag_clk <= not cap_tag_clk after 6.5 ns;
    cap_io_rst <= not reset_na;
    cap_tag_rst <= not reset_na;
    cap_mode_supported <= '0' when UNSUPPORTED_MODE_ARM or mode_fault_inject='1' else '1';

    -- Compare the actual output stream, not just the input framebuffer slots,
    -- with regression inactive. The memory model applies bounded stalls.
    VideoOutputHash: process(o_clk)
        variable next_hash : unsigned(31 downto 0);
    begin
        if rising_edge(o_clk) and reset_na='1' and now>=1 ms and now<1900 us then
            if video_de='1' then
                assert not is_x(std_logic_vector(video_r & video_g & video_b))
                    report "unknown visible video output" severity failure;
                next_hash:=rotate_left(video_hash,5) xor resize(video_r,32);
                next_hash:=rotate_left(next_hash,5) xor resize(video_g,32);
                next_hash:=rotate_left(next_hash,5) xor resize(video_b,32);
                video_hash<=next_hash;
                video_samples<=video_samples+1;
                if video_r/=0 or video_g/=0 or video_b/=0 then
                    video_nonblack<=video_nonblack+1;
                end if;
            end if;
        end if;
    end process;

    VideoOutputReport: process
    begin
        wait for 1900 us;
        if not ARM_CAPTURE then
            assert video_samples>=1000 and video_nonblack>=100
                report "insufficient nonblack video output samples" severity failure;
            report "VIDEO_OUTPUT samples=" & integer'image(video_samples) &
                " nonblack=" & integer'image(video_nonblack) &
                " hash=" & to_hstring(video_hash) severity note;
        end if;
        wait;
    end process;

    VideoTraceEnabled: if VIDEO_TRACE generate
        VideoTrace: process(o_clk)
            file trace_file : text open write_mode is "video.txt";
            variable row : line;
        begin
            if rising_edge(o_clk) and reset_na='1' and now>=1 ms and now<1900 us and video_de='1' then
                write(row,to_hstring(video_r & video_g & video_b));
                writeline(trace_file,row);
            end if;
        end process;
    end generate;

    BusTraceEnabled: if BUS_TRACE generate
        BusTrace: process(avl_clk)
            file trace_file : text open write_mode is "bus.txt";
            variable row : line;
        begin
            if rising_edge(avl_clk) and reset_na='1' then
                if avl_write='1' and avl_waitrequest='0' then
                    write(row,string'("W ")); write(row,now); write(row,string'(" "));
                    write(row,to_hstring(avl_address)); write(row,string'(" "));
                    write(row,to_hstring(model_writedata)); writeline(trace_file,row);
                elsif avl_read='1' and avl_waitrequest='0' then
                    write(row,string'("R ")); write(row,now); write(row,string'(" "));
                    write(row,to_hstring(avl_address)); writeline(trace_file,row);
                end if;
                if avl_readdatavalid='1' then
                    write(row,string'("D ")); write(row,now); write(row,string'(" "));
                    write(row,to_hstring(avl_readdata)); writeline(trace_file,row);
                end if;
            end if;
        end process;
    end generate;

    ArmedFaultInjection: process
    begin
        if CAPTURE_ENABLE and ARMED_FAULT_WATCHDOG then
            wait until cap_req_ack='1';
            wait for 20 ns;
            mode_fault_inject<='1';
        end if;
        wait;
    end process;
    ascal_i_vs <= i_vs when i_ce_enable='1' else '0';
    model_observe_address <= collision_observe_address when EXPECT_WRITE_COLLISION else
                             ready_observe_address when ready_oracle_active='1' else observe_address;

    InputClockEnable: process
    begin
        if CAPTURE_ENABLE and ARM_CAPTURE and CAPTURE_ARM_CHECKPOINT=0 and
           not TEST_IDLE_PROGRESS then
            i_ce_enable<='0';
            wait until fifo_capacity_done='1';
            i_ce_enable<='1';
        else
            i_ce_enable<='1';
        end if;
        wait;
    end process;

    ResetDrive: process
    begin
        -- Keep the scaler reset while the external raster presents a full
        -- sync cycle, so its frame-boundary and address acquisition start
        -- from a valid video phase.
        wait for 100 us;
        reset_na <= '1';
        if RESET_READY_RESULT then
            wait until reset_after_ready_request='1';
            wait for 5 ns;
            reset_na <= '0';
            wait for 60 ns;
            reset_na <= '1';
            wait for 20 ns;
            reset_after_ready_done <= '1';
        end if;
        wait;
    end process;

    FreezeInput: process
    begin
        wait until reset_na='1';
        wait until i_vs'event and i_vs='1';
        -- Auto-size learns the first complete native image before ascal's
        -- vertical input window is valid. Keep writes frozen through another
        -- complete active frame so startup line history is initialized.
        wait until i_vs'event and i_vs='1';
        if LARGE_SCAN_TEST then wait until i_vs'event and i_vs='1'; end if;
        wait until i_de='1';
        wait for 1 ns;
        freeze_input <= '0';
        wait;
    end process;

    CaptureTrace: process(cap_req_ack,cap_state,cap_fault,native_tag_count)
    begin
        report "capture trace req_ack=" & std_logic'image(cap_req_ack) &
               " state=" & to_hstring(cap_state) & " fault=" & to_hstring(cap_fault) &
               " tags=" & integer'image(native_tag_count) severity note;
    end process;

    TagFifoCapacityEnabled: if CAPTURE_ENABLE and ARM_CAPTURE and
                                CAPTURE_ARM_CHECKPOINT=0 and not TEST_IDLE_PROGRESS generate
    begin
    TagFifoCapacity: process
    begin
        if not LIFECYCLE_UNKNOWN_BEFORE_ARM then
            wait until cap_tag_rst='0';
            cap_life<=life_packet(0,0,0);
            cap_life_toggle<=NOT cap_life_toggle;
            wait until cap_life_ack=cap_life_toggle;
            if LIFECYCLE_ERROR_BEFORE_ARM then
                cap_life <= life_packet(1,1,1);
            else
                cap_life <= life_packet(1,0,1);
            end if;
            cap_life_toggle<=NOT cap_life_toggle;
            wait until cap_life_ack=cap_life_toggle;
            capture_lifecycle_armed<='1';
        end if;
        wait until capture_request_acked='1';
        wait for 26 ns;
        for token in 0 to 3 loop
            wait until falling_edge(cap_tag_clk);
            cap_tag <= std_logic_vector(to_unsigned(token+1,15));
            cap_tag_valid <= '1';
            wait until rising_edge(cap_tag_clk);
            assert cap_tag_ready='1'
                report "depth-four tag FIFO rejected entry " & integer'image(token+1)
                severity failure;
            wait until falling_edge(cap_tag_clk);
            cap_tag_valid <= '0';
        end loop;
        wait for 40 ns;
        assert cap_tag_ready='0'
            report "depth-four tag FIFO did not become full after four entries"
            severity failure;
        report "PASS tag FIFO accepts exactly four queued entries" severity note;
        fifo_capacity_done<='1';
        wait;
    end process;
    end generate;

    CaptureRequest: process
        variable requested_checkpoint : natural;
        variable rearm_seen,rearm_value : std_logic := '0';
    begin
        if CAPTURE_ENABLE and ARM_CAPTURE then
            requested_checkpoint:=CAPTURE_ARM_CHECKPOINT;
            if requested_checkpoint=0 and not INVALID_ARM_TEST then requested_checkpoint:=1; end if;
            wait until reset_na='1';
            if not LIFECYCLE_UNKNOWN_BEFORE_ARM then
                wait until capture_lifecycle_armed='1';
            end if;
            if CLEAN_IDLE_ONLY then
                if cap_state/=x"00" then wait until cap_state=x"00"; end if;
                assert cap_fault=x"00"
                    report "observed clean IDLE did not clear the recovery drain indicator" severity failure;
            end if;
            if LARGE_SCAN_TEST and freeze_input/='0' then wait until freeze_input='0'; end if;
            if LIFECYCLE_START_ARM_RACE then
                lifecycle_start_race_fire<='1';
                wait until falling_edge(i_clk);
                cap_req <= "00000" & std_logic_vector(to_unsigned(CAPTURE_HOLD_MS,11)) & '0' &
                           std_logic_vector(to_unsigned(requested_checkpoint,15));
                cap_req_toggle<='1';
            else
                wait for 20 ns;
                cap_req <= "00000" & std_logic_vector(to_unsigned(CAPTURE_HOLD_MS,11)) & '0' &
                           std_logic_vector(to_unsigned(requested_checkpoint,15));
                cap_req_toggle<='1';
            end if;
            wait until cap_req_ack='1';
            capture_request_acked<='1';
            if CLEAN_IDLE_ONLY then
                if cap_fault/=x"03" then wait until cap_fault=x"03"; end if;
                assert cap_state=x"00" and cap_result_toggle='0'
                    report "CAP ARM succeeded before a fresh IDLE-to-ARMED barrier" severity failure;
                clean_idle_arm_rejected<='1';
            end if;
            if RESET_READY_RESULT then
                wait until reset_na='0';
                cap_req<=(others=>'0');
                cap_req_toggle<='0';
                capture_request_acked<='0';
                wait until post_reset_arm_request='1';
                wait until post_reset_life_done='1';
                cap_req <= "00000" & std_logic_vector(to_unsigned(CAPTURE_HOLD_MS,11)) & '0' &
                           std_logic_vector(to_unsigned(CAPTURE_ARM_CHECKPOINT+1,15));
                cap_req_toggle<='1';
                wait until cap_req_ack='1';
                post_reset_arm_done<='1';
                wait;
            end if;
            if LIFECYCLE_REARM_RACE or LIFECYCLE_DONE_ARM_RACE then
                wait until lifecycle_rearm_race_fire='1';
                wait until falling_edge(i_clk);
                if LIFECYCLE_DONE_ARM_RACE then
                    cap_req<="00000" & std_logic_vector(to_unsigned(1000,11)) & '0' &
                             std_logic_vector(to_unsigned(17,15));
                else
                    cap_req<="00000" & std_logic_vector(to_unsigned(1000,11)) & '0' &
                             std_logic_vector(to_unsigned(CAPTURE_ARM_CHECKPOINT+1,15));
                end if;
                rearm_value:=NOT cap_req_toggle;
                cap_req_toggle<=rearm_value;
                wait until cap_req_ack=rearm_value;
                capture_rearm_ack<='1';
                wait;
            end if;
            loop
                wait until capture_rearm_toggle/=rearm_seen;
                rearm_seen:=capture_rearm_toggle;
                cap_req<=capture_rearm_bundle;
                rearm_value:=NOT cap_req_toggle;
                cap_req_toggle<=rearm_value;
                wait until cap_req_ack=rearm_value;
                capture_rearm_ack<=capture_rearm_toggle;
            end loop;
        end if;
        wait;
    end process;

    Gfw1Vectors: process
        type words_t is array(0 to 255) of unsigned(31 downto 0);
        variable words : words_t;
        variable h, sums : unsigned(31 downto 0);
        variable j : natural;
    begin
        h:=(others=>'0');
        h:=gfw1_oracle(h,x"80000000"); h:=gfw1_oracle(h,x"80000001");
        h:=gfw1_oracle(h,x"40000003"); h:=gfw1_oracle(h,x"11223344");
        assert h=x"90A23354" report "GFW1 forward vector" severity failure;
        h:=(others=>'0');
        h:=gfw1_oracle(h,x"11223344"); h:=gfw1_oracle(h,x"40000003");
        h:=gfw1_oracle(h,x"80000001"); h:=gfw1_oracle(h,x"80000000");
        assert h=x"09119A2E" report "GFW1 reverse vector" severity failure;
        words(0):=x"01020304";
        for i in 1 to 255 loop words(i):=words(i-1)+x"9E3779B9"; end loop;
        for permutation in 0 to 2 loop
            h:=(others=>'0'); sums:=(others=>'0');
            for i in 0 to 255 loop
                j:=i;
                if permutation=1 and i<128 then j:=(i+64) mod 128; end if;
                if permutation=2 then j:=(i+128) mod 256; end if;
                h:=gfw1_oracle(h,words(j)); sums:=sums+words(j);
            end loop;
            assert sums=x"A322A780" report "GFW1 vector sum" severity failure;
            case permutation is
                when 0 => assert h=x"85C41297" report "GFW1 vector original" severity failure;
                when 1 => assert h=x"7EAD5021" report "GFW1 vector burst swap" severity failure;
                when 2 => assert h=x"E69F5929" report "GFW1 vector row swap" severity failure;
            end case;
        end loop;
        report "PASS GFW1 independent fixed vectors" severity note;
        wait;
    end process;

    CaptureRelease: process
        variable release_value : std_logic;
        variable result_snapshot : std_logic_vector(511 downto 0);
        variable pixel_hash,pixel_sum,original_hash,original_sum : unsigned(31 downto 0);
        variable mapped_beat : natural;
    begin
        if CAPTURE_ENABLE and STALL_TWO_ABORT then
            wait until two_stall_ready='1';
            cap_abort<="0" & std_logic_vector(to_unsigned(CAPTURE_ARM_CHECKPOINT,15));
            release_value:=not cap_abort_toggle;
            cap_abort_toggle<=release_value;
            wait until cap_abort_ack=release_value;
            assert cap_result_toggle='0' report "abort published a capture result" severity failure;
            report "PASS two outstanding halves drained before abort acknowledgement" severity note;
            finish;
        elsif CAPTURE_ENABLE and INVALID_ARM_TEST then
            wait until cap_req_ack='1';
            if cap_fault/=x"03" then wait until cap_fault=x"03"; end if;
            assert (cap_state=x"00" or cap_state=x"05") and cap_result_toggle='0'
                report "invalid ARM acquired capture ownership" severity failure;
            report "PASS invalid checkpoint or hold rejected by ascal" severity note;
            finish;
        elsif CAPTURE_ENABLE and UNSUPPORTED_MODE_ARM then
            wait until cap_req_ack='1';
            if cap_fault/=x"06" then wait until cap_fault=x"06"; end if;
            assert cap_state=x"00" or cap_state=x"05"
                report "unsupported ARM incorrectly acquired scaler ownership" severity failure;
            wait for 250 us;
            assert cap_state=x"05" and cap_fault=x"06"
                report "unsupported ARM did not preserve the startup drain barrier or ordinary video" severity failure;
            release_test_done<='1';
            report "PASS unsupported ARM rejected without stopping ordinary video" severity note;
        elsif CAPTURE_ENABLE and ARMED_FAULT_WATCHDOG then
            wait until cap_state=x"04" and cap_fault=x"06";
            wait for 10 ns;
            assert cap_state=x"04" and cap_fault=x"06"
                report "ARMED fault was not observable before bounded watchdog cleanup" severity failure;
            if cap_state/=x"00" then wait until cap_state=x"00"; end if;
            assert cap_fault=x"06"
                report "ARMED fault watchdog did not preserve the first host-visible fault" severity failure;
            cap_abort<="0" & std_logic_vector(to_unsigned(CAPTURE_ARM_CHECKPOINT,15));
            release_value:=NOT cap_abort_toggle;
            cap_abort_toggle<=release_value;
            wait until cap_abort_ack=release_value;
            assert cap_state=x"00" and cap_fault=x"06"
                report "late ABORT after ARMED watchdog cleanup lost safe state or sticky fault" severity failure;
            release_test_done<='1';
            report "PASS ARMED fault watchdog released hold and preserved sticky fault" severity note;
            finish;
        elsif CAPTURE_ENABLE and (LIFECYCLE_ERROR_BEFORE_ARM or LIFECYCLE_UNKNOWN_BEFORE_ARM) then
            wait until cap_req_ack='1';
            if LIFECYCLE_ERROR_BEFORE_ARM then
                if cap_fault/=x"03" then wait until cap_fault=x"03"; end if;
                assert cap_state=x"00" or cap_state=x"05"
                    report "ARM accepted lifecycle state carrying a producer error" severity failure;
            else
                if cap_fault/=x"03" then wait until cap_fault=x"03"; end if;
                assert cap_state=x"00" or cap_state=x"05"
                    report "ARM accepted before any coherent lifecycle state was known" severity failure;
            end if;
            wait for 250 us;
            assert cap_state=x"05"
                report "rejected lifecycle ARM did not preserve the startup drain barrier" severity failure;
            release_test_done<='1';
            report "PASS ARM rejected unknown or errored lifecycle state" severity note;
        elsif CAPTURE_ENABLE and LIFECYCLE_STOP_BEFORE_TARGET then
            wait until cap_state=x"01";
            if cap_fault/=x"05" then wait until cap_fault=x"05"; end if;
            if cap_state/=x"00" then wait until cap_state=x"00"; end if;
            assert cap_fault=x"05"
                report "pre-target lifecycle STOP cleanup lost its first fault" severity failure;
            release_test_done<='1';
            report "PASS pre-target lifecycle STOP automatically drained and released ownership" severity note;
        elsif CAPTURE_ENABLE and FENCE_CORRUPTION_TEST and CAPTURE_ARM_CHECKPOINT>0 then
            wait until cap_state=x"04";
            assert cap_fault=x"0A" and cap_result_toggle='0' and
                   cap_result=std_logic_vector(to_unsigned(0,512))
                report "corrupted exact-header beat published READY or changed result" severity failure;
            if fence_corrupt_drain_done/='1' then
                wait until fence_corrupt_drain_done='1';
            end if;
            assert fence_corrupt_drain_done='1'
                report "selected exact-header corruption was not injected and fully returned" severity failure;
            cap_abort<="0" & std_logic_vector(to_unsigned(CAPTURE_ARM_CHECKPOINT,15));
            release_value:=NOT cap_abort_toggle;
            cap_abort_toggle<=release_value;
            wait until cap_abort_ack=release_value;
            if cap_state/=x"00" then wait until cap_state=x"00"; end if;
            assert cap_fault=x"0A" and cap_result_toggle='0' and
                   cap_result=std_logic_vector(to_unsigned(0,512)) and model_fault='0'
                report "corrupted exact-header beat cleanup changed fault/result or broke Avalon" severity failure;
            release_test_done<='1';
            report "PASS exact header fence corruption was rejected and drained" severity note;
            finish;
        elsif CAPTURE_ENABLE and RESET_READY_RESULT and CAPTURE_ARM_CHECKPOINT>0 then
            wait until cap_state=x"03";
            wait until native_done='1';
            result_snapshot:=cap_result;
            assert result_snapshot(31 downto 0)=x"3243544A" and cap_result_toggle='1'
                report "READY descriptor was not published before reset test" severity failure;
            reset_after_ready_request<='1';
            wait until reset_after_ready_done='1';
			wait for 250 ns;
            assert cap_state=x"05" and cap_fault=x"00" and
                   cap_result=std_logic_vector(to_unsigned(0,512)) and cap_result_toggle='0'
                report "shared reset retained stale READY data or skipped the startup drain barrier" severity failure;
			post_reset_arm_request<='1';
			wait until post_reset_arm_done='1';
			assert cap_state=x"05" and cap_fault=x"03" and
			       cap_result=std_logic_vector(to_unsigned(0,512)) and cap_result_toggle='0'
				report "post-reset ARM bypassed the fresh IDLE-to-ARMED lifecycle barrier" severity failure;
            release_test_done<='1';
            report "PASS shared reset invalidated held descriptor and result mailbox" severity note;
            finish;
        elsif CAPTURE_ENABLE and
              (LIFECYCLE_UNEXPECTED_REARM or LIFECYCLE_UNKNOWN_ACTIVE_REARM) and
              CAPTURE_ARM_CHECKPOINT>0 then
            wait until cap_state=x"03";
            wait until native_done='1';
            result_snapshot:=cap_result;
            assert cap_fault=x"00" and cap_result_toggle='1'
                report "unexpected-rearm test did not begin with a live READY result" severity failure;
            lifecycle_rearm_request<='1';
            wait until lifecycle_rearm_done='1';
            if cap_state/=x"04" then wait until cap_state=x"04"; end if;
            assert cap_fault=x"05" and cap_result=result_snapshot and cap_result_toggle='1'
                report "unexpected ARMED did not fail closed while preserving the owned result" severity failure;
            cap_result_ack<=cap_result_toggle;
            if cap_state/=x"05" then wait until cap_state=x"05"; end if;
            wait for 100 us;
            assert cap_state=x"05" and cap_fault=x"05" and
                   cap_result=result_snapshot and cap_result_toggle='1'
                report "unexpected ARMED cleanup lost the first fault or held result" severity failure;
            release_test_done<='1';
            if LIFECYCLE_UNKNOWN_ACTIVE_REARM then
                report "PASS unknown lifecycle state canceled active owner and preserved its result" severity note;
            else
                report "PASS unexpected ARMED canceled active owner and preserved its result" severity note;
            end if;
            finish;
        elsif CAPTURE_ENABLE and EXPECT_WATCHDOG and not EXPECT_WRITE_COLLISION then
            wait until cap_state=x"03";
            cap_result_ack<=cap_result_toggle;
            result_snapshot:=cap_result;
            wait for 40 us;
            assert cap_state=x"03" and cap_fault=x"00" and cap_result=result_snapshot and
                   post_hold_target_pixel_writes=0
                report "READY hold changed before configured watchdog expiry" severity failure;
            if HALT_INPUT_CLOCK_ON_READY then
                input_clock_enable<='0';
                wait until cap_fault=x"0B";
                assert cap_state=x"04"
                    report "Avalon watchdog did not invalidate stale READY while i_clk was stopped" severity failure;
                wait for 20 us;
                assert cap_state=x"04" and cap_fault=x"0B"
                    report "halted i_clk watchdog override lost its fault/ownership indication" severity failure;
                input_clock_enable<='1';
            end if;
            wait until cap_state=x"00" and cap_fault=x"0B";
            if REARM_AFTER_CLEANUP then
                capture_rearm_bundle<="00000" & std_logic_vector(to_unsigned(1000,11)) & '0' &
                         std_logic_vector(to_unsigned(17,15));
                release_value:=NOT cap_req_toggle;
                capture_rearm_toggle<=NOT capture_rearm_toggle;
                wait until capture_rearm_ack=capture_rearm_toggle;
                if cap_state/=x"01" then wait until cap_state=x"01"; end if;
                assert cap_fault=x"00"
                    report "valid ARM did not clear sticky watchdog fault" severity failure;
                cap_abort<="0" & std_logic_vector(to_unsigned(17,15));
                release_value:=NOT cap_abort_toggle;
                cap_abort_toggle<=release_value;
                wait until cap_abort_ack=release_value;
                if cap_state/=x"00" then wait until cap_state=x"00"; end if;
                assert cap_fault=x"00" report "re-armed abort retained watchdog fault" severity failure;
                release_test_done<='1';
                report "PASS watchdog cleanup and fault-clear re-arm" severity note;
            ELSE
                cap_abort<="0" & std_logic_vector(to_unsigned(CAPTURE_ARM_CHECKPOINT,15));
                release_value:=NOT cap_abort_toggle;
                cap_abort_toggle<=release_value;
                wait until cap_abort_ack=release_value;
                assert cap_state=x"00" and cap_fault=x"0B"
                    report "rejected post-watchdog ABORT did not retire its toggle in IDLE" severity failure;
                release_test_done<='1';
                report "PASS bounded watchdog cleanup and rejected post-watchdog ABORT ACK" severity note;
                finish;
            END IF;
        elsif CAPTURE_ENABLE and RELEASE_BEFORE_READY and CAPTURE_ARM_CHECKPOINT>0 and
           not EXPECT_WRITE_COLLISION then
            wait until cap_state=x"01";
            cap_release<="0" & std_logic_vector(to_unsigned(CAPTURE_ARM_CHECKPOINT,15));
            release_value:=NOT cap_release_toggle;
            cap_release_toggle<=release_value;
            wait until cap_release_ack=release_value;
            assert cap_state=x"04" and cap_fault=x"0C"
                report "rejected pre-READY RELEASE did not ack and preserve BAD_RELEASE" severity failure;
            cap_abort<="0" & std_logic_vector(to_unsigned(CAPTURE_ARM_CHECKPOINT,15));
            release_value:=NOT cap_abort_toggle;
            cap_abort_toggle<=release_value;
            wait until cap_abort_ack=release_value;
            if cap_state/=x"00" then wait until cap_state=x"00"; end if;
            assert cap_fault=x"0C"
                report "cleanup after rejected pre-READY RELEASE lost its sticky fault" severity failure;
            release_test_done<='1';
            report "PASS rejected pre-READY RELEASE ACK and matching cleanup" severity note;
            finish;
        elsif CAPTURE_ENABLE and BAD_RELEASE_THEN_ABORT and CAPTURE_ARM_CHECKPOINT>0 and
           not EXPECT_WRITE_COLLISION then
            wait until cap_state=x"03";
            cap_result_ack<=cap_result_toggle;
            result_snapshot:=cap_result;
            cap_release<="0" & std_logic_vector(to_unsigned(2,15));
            release_value:=NOT cap_release_toggle;
            cap_release_toggle<=release_value;
            wait until cap_fault=x"0C";
            if cap_release_ack/=release_value then
                wait until cap_release_ack=release_value;
            end if;
            assert cap_state=x"04" and cap_result=result_snapshot
                report "wrong release tuple did not retain ERROR ownership and descriptor" severity failure;
            wait for 100 us;
            if WATCHDOG_AFTER_BAD_RELEASE then
                wait for 30 us;
                assert (cap_state=x"04" or cap_state=x"00") and cap_fault=x"0C" and
                       cap_abort_ack='0' and cap_result=result_snapshot
                    report "later watchdog replaced the earlier BAD_RELEASE first fault" severity failure;
                report "PASS later watchdog kept the first BAD_RELEASE diagnostic" severity note;
            else
                assert cap_state=x"04"
                    report "wrong release tuple did not retain ERROR ownership" severity failure;
            end if;
            if cap_state=x"04" then
                cap_abort<="0" & std_logic_vector(to_unsigned(CAPTURE_ARM_CHECKPOINT,15));
                release_value:=NOT cap_abort_toggle;
                cap_abort_toggle<=release_value;
                wait until cap_abort_ack=release_value;
                if cap_state/=x"00" then wait until cap_state=x"00"; end if;
            else
                assert cap_state=x"00"
                    report "watchdog cleanup did not reach safe IDLE after BAD_RELEASE" severity failure;
            end if;
            assert cap_result=result_snapshot
                report "capture cleanup or fault overwrote the published descriptor" severity failure;
            IF REARM_AFTER_CLEANUP THEN
                capture_rearm_bundle<="00000" & std_logic_vector(to_unsigned(1000,11)) & '0' &
                         std_logic_vector(to_unsigned(17,15));
                release_value:=NOT cap_req_toggle;
                capture_rearm_toggle<=NOT capture_rearm_toggle;
                wait until capture_rearm_ack=capture_rearm_toggle;
                if cap_state/=x"01" then wait until cap_state=x"01"; end if;
                assert cap_fault=x"00"
                    report "valid ARM did not clear prior sticky cleanup fault" severity failure;
                cap_abort<="0" & std_logic_vector(to_unsigned(17,15));
                release_value:=NOT cap_abort_toggle;
                cap_abort_toggle<=release_value;
                wait until cap_abort_ack=release_value;
                if cap_state/=x"00" then wait until cap_state=x"00"; end if;
                assert cap_fault=x"00" report "re-armed abort retained an obsolete fault" severity failure;
                report "PASS valid ARM clears sticky capture and Avalon faults" severity note;
            ELSE
                assert cap_fault=x"0C" report "sticky BAD_RELEASE fault was lost during cleanup" severity failure;
            END IF;
            release_test_done<='1';
            report "PASS wrong release retained ownership; matching abort cleaned up" severity note;
        elsif CAPTURE_ENABLE and ABORT_AFTER_ARM and not EXPECT_WRITE_COLLISION then
            wait until cap_state=x"01";
            if not ABORT_BEFORE_FIRST_FRAME then
                wait for 350 us; -- Also cover cancellation after a real admitted image.
            end if;
            assert cap_state=x"01" report "capture left ARMED before requested abort" severity failure;
            cap_abort<="0" & std_logic_vector(to_unsigned(CAPTURE_ARM_CHECKPOINT,15));
            release_value:=NOT cap_abort_toggle;
            cap_abort_toggle<=release_value;
            report "abort submitted while ARMED" severity note;
            wait until cap_abort_ack=release_value;
            if cap_state/=x"00" then wait until cap_state=x"00"; end if;
            assert cap_fault=x"00" report "valid matching abort raised a capture fault" severity failure;
            release_test_done<='1';
            report "PASS matching abort cleanup" severity note;
        elsif CAPTURE_ENABLE and CLEAN_IDLE_ONLY then
            wait until clean_idle_arm_rejected='1';
            assert cap_state=x"00" and cap_fault=x"03"
                report "observed IDLE recovery drain failed to keep pre-ARM capture closed" severity failure;
            report "PASS observed clean IDLE permits recovery drain but blocks CAP ARM" severity note;
            finish;
        elsif CAPTURE_ENABLE and CAPTURE_ARM_CHECKPOINT>0 and not EXPECT_WRITE_COLLISION then
            wait until cap_state=x"03";
            if LIFECYCLE_START_ARM_RACE then
                assert cap_fault=x"00" report "ARMED-to-RUNNING race left a lifecycle fault" severity failure;
                report "PASS same-edge ARMED-to-RUNNING progress allowed CAP ARM" severity note;
            end if;
            if LIFECYCLE_RUNNING_BEFORE_ARM then
                assert native_tag_count>=10
                    report "cached RUNNING lifecycle failed to consume native EOF tags after ARM" severity failure;
                report "PASS cached RUNNING lifecycle consumed on ARM" severity note;
            end if;
            if not DOUBLE_CAPTURE_SUCCESS then cap_result_ack<=cap_result_toggle; end if;
            assert cap_fault=x"00" report "READY carried a capture fault" severity failure;
            report "CAPTURE descriptor bytes=" & to_hstring(cap_result) severity note;
            assert cap_result(31 downto 0)=x"3243544A" report "descriptor magic mismatch" severity failure;
            assert cap_result(47 downto 32)=x"0002" and cap_result(63 downto 48)=x"0040"
                report "descriptor version/length mismatch" severity failure;
            assert unsigned(cap_result(79 downto 64))=to_unsigned(CAPTURE_ARM_CHECKPOINT,16) and
                   unsigned(cap_result(95 downto 80))=to_unsigned(CAPTURE_ARM_CHECKPOINT-1,16)
                report "descriptor checkpoint/interval mismatch" severity failure;
            assert cap_result(127 downto 96)=x"20400000" and
                   cap_result(159 downto 128)=x"00200000"
                report "descriptor slot base/stride mismatch" severity failure;
            assert cap_result(175 downto 160)=x"0057" and
                   unsigned(cap_result(191 downto 176))=to_unsigned(TEST_ACTIVE_HEIGHT,16) and
                   cap_result(223 downto 192)=x"00000200" and
                   unsigned(cap_result(255 downto 224))=to_unsigned(TEST_ACTIVE_HEIGHT*512,32) and
                   cap_result(287 downto 256)=x"00000E01"
                report "descriptor geometry/payload/mode mismatch" severity failure;
            assert unsigned(cap_result(319 downto 288))=to_unsigned(1+TEST_ACTIVE_HEIGHT*2,32) and
                   cap_result(351 downto 320)=x"31574647" and
                   cap_result(511 downto 480)=x"32594452"
                report "descriptor burst count, algorithm tag or READY commit mismatch" severity failure;
            assert cap_result(479 downto 448)/=x"00000000"
                report "descriptor CRC was not committed" severity failure;
            assert cap_result(479 downto 448)=crc32_reference(cap_result(447 downto 0))
                report "READY descriptor CRC mismatch" severity failure;
            assert cap_result(447 downto 384)=std_logic_vector(to_unsigned(0,64))
                report "descriptor reserved bytes 48..55 are not zero" severity failure;
            assert post_hold_target_pixel_writes=0
                report "selected slot pixel bytes changed before READY release" severity failure;
            assert native_manifest(CAPTURE_ARM_CHECKPOINT)>=0
                report "READY descriptor has no independent native frame manifest" severity failure;
            ready_oracle_active<='1';
            -- READY follows Avalon acceptance, so allow the adversarial DDR
            -- model to retire late writes before independently summing RAM.
            if pending_writes/=0 then wait until pending_writes=0; end if;
            -- Reorder committed storage as an adversarial DDR observation while
            -- leaving the write-side digest and accepted logical stream untouched.
            for permutation in 0 to 2 loop
                pixel_hash:=(others=>'0'); pixel_sum:=(others=>'0');
                for beat in 0 to TEST_ACTIVE_HEIGHT*32-1 loop
                    mapped_beat:=beat;
                    if permutation=1 and beat<32 then mapped_beat:=(beat+16) mod 32; end if;
                    if permutation=2 and beat<64 then mapped_beat:=(beat+32) mod 64; end if;
                    ready_observe_address<=std_logic_vector(to_unsigned(
                        (BASE_ADDRESS+2*RAMSIZE_BYTES+256)/16+mapped_beat,28));
                    wait until falling_edge(avl_clk);
                    wait until falling_edge(avl_clk);
                    assert not is_x(observe_data) report "unknown checksum payload" severity failure;
                    for word_index in 0 to 3 loop
                        pixel_hash:=gfw1_oracle(pixel_hash,unsigned(observe_data(word_index*32+31 downto word_index*32)));
                        pixel_sum:=pixel_sum+unsigned(observe_data(word_index*32+31 downto word_index*32));
                    end loop;
                end loop;
                if permutation=0 then
                    original_hash:=pixel_hash; original_sum:=pixel_sum;
                    assert pixel_hash=unsigned(cap_result(383 downto 352))
                        report "write-side hash differs from committed DDR bytes" severity failure;
                else
                    assert pixel_sum=original_sum and pixel_hash/=original_hash
                        report "reordered DDR payload escaped the position-sensitive hash" severity failure;
                end if;
            end loop;
            report "PASS GFW1 matches DDR and detects burst and row swaps with unchanged sum" severity note;
            check_visible_slot(ready_observe_address,observe_data,avl_clk,
                to_integer(unsigned(cap_result(265 downto 264))),
                natural(native_manifest(CAPTURE_ARM_CHECKPOINT)));
            ready_oracle_active<='0';
            report "PASS READY target slot matches independent native-frame pixel oracle" severity note;
            result_snapshot:=cap_result;
            if HOLD_READY_TO_DONE then
                wait until native_done='1';
            else
                if native_tag_count<choose(LARGE_SCAN_TEST,13,3) then
                    wait until native_tag_count>=choose(LARGE_SCAN_TEST,13,3);
                end if;
            end if;
            assert cap_state=x"03" and cap_fault=x"00"
                report "READY ownership was lost while native frames continued" severity failure;
            assert cap_result=result_snapshot
                report "READY descriptor changed during the copy hold" severity failure;
            assert post_hold_target_pixel_writes=0
                report "selected slot pixels changed during multi-frame READY hold" severity failure;
            if not DOUBLE_CAPTURE_SUCCESS then cap_result_ack<=cap_result_toggle; end if;
            cap_release<="0" & std_logic_vector(to_unsigned(CAPTURE_ARM_CHECKPOINT,15));
            release_value:=NOT cap_release_toggle;
            cap_release_toggle<=release_value;
            report "release submitted toggle=" & std_logic'image(release_value) &
                   " state=" & to_hstring(cap_state) & " fault=" & to_hstring(cap_fault) severity note;
            wait until cap_release_ack=release_value;
            report "release acknowledged toggle=" & std_logic'image(cap_release_ack) &
                   " state=" & to_hstring(cap_state) & " fault=" & to_hstring(cap_fault) severity note;
			if DOUBLE_CAPTURE_SUCCESS then
				assert cap_state=x"05" and cap_result=result_snapshot
					report "drain did not wait for the held result ACK after release" severity failure;
			else
				if cap_state/=x"00" then wait until cap_state=x"00"; end if;
			end if;
			if DOUBLE_CAPTURE_SUCCESS then
				assert cap_state=x"05" and cap_fault=x"00"
					report "clean release lost the expected held-result drain state" severity failure;
			else
				assert cap_state=x"00" and cap_fault=x"00"
					report "clean release did not clear capture ownership" severity failure;
			end if;
            if LIFECYCLE_REARM_RACE then
                -- Publish an invalid new ARMED lifecycle and a fresh CAP ARM
                -- together after clean result cleanup. The old run's READY
                -- state must not admit the request on the event edge.
                wait until native_done='1';
                lifecycle_rearm_race_fire<='1';
                wait until lifecycle_rearm_done='1';
                report "same-edge lifecycle request acknowledged" severity note;
                if cap_fault/=x"03" then wait until cap_fault=x"03"; end if;
                if cap_state/=x"05" then wait until cap_state=x"05"; end if;
                wait for 40 ns;
                assert cap_state=x"05" and cap_fault=x"03" and
                       cap_result=result_snapshot and cap_result_toggle='1'
                    report "same-edge lifecycle re-ARM admitted a new capture or damaged old result" severity failure;
                release_test_done<='1';
                report "PASS same-edge invalid ARMED and CAP ARM rejected with old READY ownership drained" severity note;
                finish;
            end if;
            if LIFECYCLE_DONE_ARM_RACE then
                if native_tag_count<17 then wait until native_tag_count=17; end if;
                if cap_state/=x"05" then wait until cap_state=x"05"; end if;
                if cap_state/=x"00" then wait until cap_state=x"00"; end if;
                lifecycle_rearm_race_fire<='1';
                wait until lifecycle_rearm_done='1';
                if cap_state/=x"01" then wait until cap_state=x"01"; end if;
                assert cap_fault=x"00"
                    report "same-edge RUNNING-to-DONE progress spuriously rejected CAP ARM" severity failure;
                cap_abort<="0" & std_logic_vector(to_unsigned(17,15));
                release_value:=NOT cap_abort_toggle;
                cap_abort_toggle<=release_value;
                wait until cap_abort_ack=release_value;
                if cap_state/=x"00" then wait until cap_state=x"00"; end if;
                assert cap_fault=x"00"
                    report "valid DONE progress ARM cleanup raised a fault" severity failure;
                release_test_done<='1';
                report "PASS same-edge RUNNING-to-DONE progress allowed CAP ARM" severity note;
                finish;
            end if;
            if LIFECYCLE_ARMED_REARM then
                lifecycle_rearm_request<='1';
                wait until lifecycle_rearm_done='1';
                -- IDLE→ARMED and its lifecycle ACK can precede the asynchronous
                -- tag FIFO's final empty snapshot. Match Main's CAPS drain gate.
                if cap_state/=x"00" then wait until cap_state=x"00"; end if;
                capture_rearm_bundle<="00000" & std_logic_vector(to_unsigned(1000,11)) & '0' &
                    std_logic_vector(to_unsigned(1,15));
                capture_rearm_toggle<=NOT capture_rearm_toggle;
                wait until capture_rearm_ack=capture_rearm_toggle;
                if cap_state/=x"01" then wait until cap_state=x"01"; end if;
                wait for 20 us;
                assert cap_state=x"01" and cap_fault=x"00"
                    report "new ARMED lifecycle inherited RUNNING from the completed prior run" severity failure;
                cap_abort<="0" & std_logic_vector(to_unsigned(1,15));
                release_value:=NOT cap_abort_toggle;
                cap_abort_toggle<=release_value;
                wait until cap_abort_ack=release_value;
                if cap_state/=x"00" then wait until cap_state=x"00"; end if;
                assert cap_fault=x"00" report "cached ARMED abort raised a capture fault" severity failure;
                report "PASS clean ARMED lifecycle starts after prior result cleanup" severity note;
            end if;
            if DOUBLE_CAPTURE_SUCCESS then
                capture_rearm_bundle<="00000" & std_logic_vector(to_unsigned(1000,11)) & '0' &
                    std_logic_vector(to_unsigned(17,15));
                capture_rearm_toggle<=NOT capture_rearm_toggle;
                if capture_rearm_ack/=capture_rearm_toggle then
                    wait until capture_rearm_ack=capture_rearm_toggle;
                end if;
                -- The first descriptor is still unacknowledged. A new ARM must
                -- be rejected without overwriting its cache/result bundle.
                if cap_fault/=x"03" then wait until cap_fault=x"03"; end if;
				assert cap_state=x"05" and cap_result=result_snapshot
					report "drain did not preserve the unacknowledged result" severity failure;
                cap_result_ack<=cap_result_toggle;
				if cap_state/=x"00" then wait until cap_state=x"00"; end if;
                wait for 40 ns;
                capture_rearm_toggle<=NOT capture_rearm_toggle;
                if capture_rearm_ack/=capture_rearm_toggle then
                    wait until capture_rearm_ack=capture_rearm_toggle;
                end if;
                if cap_state/=x"01" then wait until cap_state=x"01"; end if;
                assert cap_fault=x"00" report "valid retry did not clear unacknowledged-result diagnostic" severity failure;
                if cap_state/=x"03" then wait until cap_state=x"03"; end if;
                assert cap_fault=x"00" and cap_result(31 downto 0)=x"3243544A" and
                       cap_result(47 downto 32)=x"0002" and cap_result(63 downto 48)=x"0040" and
                       cap_result(79 downto 64)=x"0011" and cap_result(95 downto 80)=x"0010" and
                       cap_result(511 downto 480)=x"32594452"
                    report "second READY descriptor has stale/mismatched capture identity" severity failure;
                assert cap_result(479 downto 448)=crc32_reference(cap_result(447 downto 0))
                    report "second READY descriptor CRC mismatch" severity failure;
                assert native_manifest(17)>=0
                    report "second capture target has no independent native manifest" severity failure;
                ready_oracle_active<='1';
                check_visible_slot(ready_observe_address,observe_data,avl_clk,
                    to_integer(unsigned(cap_result(265 downto 264))),natural(native_manifest(17)));
                ready_oracle_active<='0';
                cap_result_ack<=cap_result_toggle;
                cap_release<="0" & std_logic_vector(to_unsigned(17,15));
                release_value:=NOT cap_release_toggle;
                cap_release_toggle<=release_value;
                wait until cap_release_ack=release_value;
                if cap_state/=x"00" then wait until cap_state=x"00"; end if;
                assert cap_fault=x"00" report "second capture clean release faulted" severity failure;
                report "PASS two fresh READY results with delayed cache ACK and clean re-arm" severity note;
            end if;
            release_test_done<='1';
            if LARGE_SCAN_TEST then
                assert accepted_beats=committed_beats and pending_writes=0 and
                       post_hold_target_pixel_writes=0 and model_fault='0'
                    report "large scan release/read fence did not drain cleanly" severity failure;
                assert native_tag_count>=3 and held_write_snapshot_valid='1'
                    report "large scan lacked its native-frame or next-boundary write fence" severity failure;
                report "PASS 1200-burst payload checksum, CRC, RGB, release"
                    severity note;
                finish;
            end if;
            report "PASS immutable descriptor READY and clean release" severity note;
        end if;
        wait;
    end process;

    NativeTagSourceEnabled: if CAPTURE_ENABLE and ARM_CAPTURE and CAPTURE_ARM_CHECKPOINT>0 generate
    begin
    NativeTagSource: process
    begin
        wait until cap_tag_rst='0';
        if LARGE_SCAN_TEST and freeze_input/='0' then wait until freeze_input='0'; end if;
        if LARGE_SCAN_TEST then
            -- Let one complete admitted image update scaler geometry and line
            -- history before lifecycle/CAP ARM for the next complete frame.
            wait until native_vs_rise_soon='1';
        end if;
        if not LIFECYCLE_UNKNOWN_BEFORE_ARM then
            if CLEAN_IDLE_ONLY then
                cap_life<=life_packet(0,0,0);
                cap_life_toggle<=NOT cap_life_toggle;
                wait until cap_life_ack=cap_life_toggle;
            elsif LIFECYCLE_RUNNING_BEFORE_ARM then
                cap_life<=life_packet(0,0,0);
                cap_life_toggle<='1';
                wait until cap_life_ack='1';
                cap_life<=life_packet(1,0,1);
                cap_life_toggle<='0';
                wait until cap_life_ack='0';
                cap_life<=life_packet(2,0,1);
                cap_life_toggle<='1';
                wait until cap_life_ack='1';
            elsif LIFECYCLE_ERROR_BEFORE_ARM then
                cap_life<=life_packet(0,0,0);
                cap_life_toggle<=NOT cap_life_toggle;
                wait until cap_life_ack=cap_life_toggle;
                cap_life<=life_packet(1,1,1);
                cap_life_toggle<=NOT cap_life_toggle;
                wait until cap_life_ack=cap_life_toggle;
            else
                cap_life<=life_packet(0,0,0);
                cap_life_toggle<=NOT cap_life_toggle;
                wait until cap_life_ack=cap_life_toggle;
                cap_life<=life_packet(1,0,1);
                cap_life_toggle<=NOT cap_life_toggle;
                wait until cap_life_ack=cap_life_toggle;
            end if;
            capture_lifecycle_armed<='1';
        end if;
        if CLEAN_IDLE_ONLY then wait; end if;
        if LIFECYCLE_START_ARM_RACE then
            if lifecycle_start_race_fire/='1' then wait until lifecycle_start_race_fire='1'; end if;
            wait until falling_edge(i_clk);
            cap_life<=life_packet(2,0,1);
            cap_life_toggle<=NOT cap_life_toggle;
            wait until cap_life_ack=cap_life_toggle;
            lifecycle_rearm_done<='1';
        end if;
        wait until capture_request_acked='1';
        if not LIFECYCLE_RUNNING_BEFORE_ARM and not LIFECYCLE_START_ARM_RACE then
            if LIFECYCLE_ERROR_BEFORE_ARM then
                cap_life <= life_packet(2,1,2);
            else
                cap_life <= life_packet(2,0,2);
            end if;
            cap_life_toggle<=NOT cap_life_toggle;
            wait until cap_life_ack=cap_life_toggle;
        end if;
        if LIFECYCLE_STOP_BEFORE_TARGET then
            -- Present STOP so its synchronized lifecycle event lands on the
            -- same i_clk as the first empty-tag EOF. Lifecycle cancellation
            -- must win that legal coincidence.
            wait until native_vs_rise_soon='1';
            cap_life<=life_packet(4,0,3);
            cap_life_toggle<=NOT cap_life_toggle;
            wait until cap_life_ack=cap_life_toggle;
            -- STOP cancels the active transaction, but does not itself prove
            -- that the producer is quiescent. Publish the fresh IDLE barrier
            -- before expecting the hardware drain state to clear.
            wait until falling_edge(i_clk);
            cap_life<=life_packet(0,0,4);
            cap_life_toggle<=NOT cap_life_toggle;
            wait until cap_life_ack=cap_life_toggle;
            wait;
        elsif LIFECYCLE_ERROR_BEFORE_ARM or LIFECYCLE_UNKNOWN_BEFORE_ARM then
            wait;
        end if;
        for checkpoint in 1 to 17 loop
            -- Emit each interval token from the source raster's actual
            -- native-LVBL falling edge, not from a phase-offset timer.
            wait until falling_edge(native_lvbl);
            native_manifest(checkpoint)<=native_frame_id;
            wait until falling_edge(cap_tag_clk);
            cap_tag <= std_logic_vector(to_unsigned(checkpoint,15));
            cap_tag_valid<='1';
            wait until rising_edge(cap_tag_clk);
            cap_tag_valid<='0';
            native_tag_count<=checkpoint;
            report "native manifest checkpoint=" & integer'image(checkpoint) &
                   " source frame=" & integer'image(native_frame_id) severity note;
        end loop;
        if LIFECYCLE_DONE_ARM_RACE then
            if lifecycle_rearm_race_fire/='1' then wait until lifecycle_rearm_race_fire='1'; end if;
            wait until falling_edge(i_clk);
        end if;
        cap_life<=life_packet(3,0,17);
        cap_life_toggle<=NOT cap_life_toggle;
        wait until cap_life_ack=cap_life_toggle;
        if LIFECYCLE_DONE_ARM_RACE then lifecycle_rearm_done<='1'; end if;
        native_done<='1';
        report "native lifecycle DONE preserves final count=17" severity note;
        if RESET_READY_RESULT then
            if post_reset_arm_request/='1' then wait until post_reset_arm_request='1'; end if;
            cap_life<=life_packet(1,0,17);
            cap_life_toggle<=NOT cap_life_toggle;
            wait until cap_life_ack=cap_life_toggle;
            post_reset_life_done<='1';
        end if;
        if LIFECYCLE_ARMED_REARM then
            if lifecycle_rearm_request/='1' then wait until lifecycle_rearm_request='1'; end if;
            cap_life<=life_packet(0,0,4);
            cap_life_toggle<=NOT cap_life_toggle;
            wait until cap_life_ack=cap_life_toggle;
            cap_life<=life_packet(1,0,4);
            cap_life_toggle<=NOT cap_life_toggle;
            wait until cap_life_ack=cap_life_toggle;
            lifecycle_rearm_done<='1';
        end if;
        if LIFECYCLE_UNEXPECTED_REARM or LIFECYCLE_UNKNOWN_ACTIVE_REARM then
            if lifecycle_rearm_request/='1' then wait until lifecycle_rearm_request='1'; end if;
            if LIFECYCLE_UNKNOWN_ACTIVE_REARM then
                cap_life<=life_packet(5,0,17);
            else
                cap_life<=life_packet(1,0,17);
            end if;
            cap_life_toggle<=NOT cap_life_toggle;
            wait until cap_life_ack=cap_life_toggle;
            lifecycle_rearm_done<='1';
        end if;
        if LIFECYCLE_REARM_RACE then
            if lifecycle_rearm_race_fire/='1' then wait until lifecycle_rearm_race_fire='1'; end if;
            wait until falling_edge(i_clk);
            cap_life<=life_packet(1,0,17);
            cap_life_toggle<=NOT cap_life_toggle;
            wait until cap_life_ack=cap_life_toggle;
            lifecycle_rearm_done<='1';
        end if;
        wait;
    end process;
    end generate;

    HoldWriteAudit: process
    begin
        if CAPTURE_ENABLE and CAPTURE_ARM_CHECKPOINT>0 then
            wait until cap_state=x"02";
            wait until falling_edge(i_vs);
            -- The target's pending write pipeline has already been draining
            -- through the blanking interval. Snapshot before the next active
            -- raster begins; any leaked next-header write is included.
            wait for 2 us;
            held_write_snapshot<=committed_beats;
            held_write_snapshot_valid<='1';
        end if;
        wait;
    end process;

    CaptureStallControl: process
        variable drained_snapshot : unsigned(63 downto 0);
        variable expected_drain_beats : unsigned(63 downto 0);
        variable frame_id : integer := -1;
        variable row_byte,channel,value,xpix : natural;
        variable expected_byte : natural;
    begin
        if EXPECT_WRITE_COLLISION then
            IF COLLISION_STALL_HALF1 THEN
                -- The current raster issues half1 on its fourth image burst.
                -- Let the first three consume, then hold the first beat of the
                -- half1 descriptor while the source continues.
                wait until accepted_beats=to_unsigned(48,64);
                expected_drain_beats:=to_unsigned(80,64);
            ELSIF COLLISION_STALL_HALF0 THEN
                -- Let the first half1 image burst complete, then hold the
                -- first beat of the following half0 descriptor.
                wait until accepted_beats=to_unsigned(16,64);
                expected_drain_beats:=to_unsigned(32,64);
            ELSE
                wait until cap_state=x"01";
                expected_drain_beats:=to_unsigned(32,64);
            END IF;
            stall_all<='1';
            wait until cap_fault=x"08";
            assert cap_state=x"04"
                report "leased-half reuse did not fail closed" severity failure;
            -- Let the staged DPRAM write attempt and the Avalon prefetch
            -- cross their read latency while the first target beat remains
            -- backpressured. Without the production lease guard, the
            -- subsequently returned word must expose the overwrite.
            wait for 100 ns;
            stall_all<='0';
            IF accepted_beats/=expected_drain_beats OR pending_writes/=0 OR avl_write/='0' THEN
                wait until accepted_beats=expected_drain_beats AND
                           pending_writes=0 AND avl_write='0';
            end if;
            assert accepted_beats=committed_beats and model_fault='0'
                report "already-launched half writes did not drain cleanly after collision" severity failure;
            -- The first two in-flight pixel half writes cover the complete
            -- visible first row (including its 5-byte burst seam). Compare
            -- committed bytes to the independent moving-pattern source after
            -- both halves drain, so an overwritten pending half cannot pass.
            FOR word_index IN 0 TO 16 LOOP
                collision_observe_address<=std_logic_vector(to_unsigned(BASE_ADDRESS/16+16+word_index,28));
                wait until falling_edge(avl_clk);
                wait until falling_edge(avl_clk);
                ASSERT NOT is_x(observe_data)
                    REPORT "collision drain left unknown first-row pixels" SEVERITY failure;
                FOR lane IN 0 TO 15 LOOP
                    row_byte:=word_index*16+lane;
                    IF row_byte<261 THEN
                        channel:=row_byte MOD 3;
                        xpix:=4+row_byte/3;
                        value:=to_integer(unsigned(observe_data(lane*8+7 DOWNTO lane*8)));
                        IF row_byte=0 THEN
                            FOR f IN 0 TO 20 LOOP
                                IF value=(f*37 MOD 256) THEN frame_id:=f; END IF;
                            END LOOP;
                            ASSERT frame_id>=0 REPORT "collision row has no source-frame ID" SEVERITY failure;
                        END IF;
                        IF channel=0 THEN expected_byte:=frame_id*37 MOD 256;
                        ELSIF channel=1 THEN expected_byte:=xpix;
                        ELSE expected_byte:=52+frame_id;
                        END IF;
                        ASSERT value=expected_byte
                            REPORT "leased-half collision changed pixel byte " & integer'image(row_byte) &
                                " frame=" & integer'image(frame_id) & " got=" & integer'image(value) &
                                " expected=" & integer'image(expected_byte) SEVERITY failure;
                    END IF;
                END LOOP;
            END LOOP;
            drained_snapshot:=committed_beats;
            wait for 100 us;
            assert committed_beats=drained_snapshot
                report "writer continued mutating memory after fail-closed collision" severity failure;
            report "PASS capture staging collision failed closed with WRITE_OVERRUN" severity note;
            finish;
        elsif STALL_TWO_OUTSTANDING or STALL_TWO_ABORT then
            -- Stall the target's penultimate burst, so its final burst can
            -- also be issued before producer quiescence and drain.
            wait until native_tag_count>=CAPTURE_ARM_CHECKPOINT-1 and avl_write='1' and
                unsigned(avl_address)=to_unsigned(
                    (BASE_ADDRESS+2*RAMSIZE_BYTES+TEST_ACTIVE_HEIGHT*512-256)/16,28);
            stall_all<='1';
            if cap_state/=x"02" then wait until cap_state=x"02"; end if;
            two_stall_ready<='1';
            if STALL_TWO_ABORT then wait until cap_abort_toggle='1'; end if;
            wait for 200 ns;
            assert avl_write='1' and avl_waitrequest='1' and cap_fault=x"00" and cap_result_toggle='0' and
                   (not STALL_TWO_ABORT or cap_abort_ack='0')
                report "two-outstanding stall published an early result or fault" severity failure;
            stall_all<='0';
            report "PASS two target half bursts held before drain" severity note;
        elsif STALL_CAPTURE_FINAL then
            -- Begin stalling on the target's last pixel burst, before its
            -- final beat can be accepted and before the native EOF arrives.
            wait until native_tag_count>=CAPTURE_ARM_CHECKPOINT-1 and avl_write='1' and
                unsigned(avl_address)=to_unsigned(
                    (BASE_ADDRESS+2*RAMSIZE_BYTES+TEST_ACTIVE_HEIGHT*512)/16,28);
            stall_target_last<='1';
            report "STALL test enabled target final-beat backpressure" severity note;
            wait until avl_write='1' and avl_waitrequest='1';
            report "STALL test reached held Avalon write beat" severity note;
            if cap_state/=x"02" then wait until cap_state=x"02"; end if;
            wait for 100 ns;
            assert avl_write='1' and avl_waitrequest='1'
                report "Avalon final beat did not remain stalled" severity failure;
            assert cap_state=x"02" and cap_fault=x"00" and cap_result_toggle='0'
                report "final-beat stall published READY/result before ordered completion" severity failure;
            stall_target_last<='0';
            report "STALL test released final-beat backpressure" severity note;
            if pending_writes/=0 or avl_write/='0' then
                wait until pending_writes=0 and avl_write='0';
            end if;
            stall_release_seen<='1';
            report "STALL test drained and completed" severity note;
        end if;
        wait;
    end process;

    CoalesceAckClocks: process
    begin
        if COALESCE_TWO_ACKS then
            -- The two next half-descriptors are already staged by the first
            -- completion. Stop only the receiver clock, let the serialized
            -- Avalon writes complete, then resume with both toggle ACKs
            -- pending together. This directly exercises identity folding.
            wait until accepted_last='1';
            input_clock_enable<='0';
            wait until accepted_last='0';
            wait until accepted_last='1';
            wait for 1 ns;
            input_clock_enable<='1';
            coalesced_ack_test_passed<='1';
        end if;
        wait;
    end process;

    -- Preserve every known bit, but make unspecified padding deterministic
    -- for the memory model. Each unknown byte is classified using the actual
    -- accepted Avalon beat address. No unknown header word0, visible RGB byte,
    -- or later metadata/header is permitted.
    PaddingAdapter: process(all)
        variable clean_data : std_logic_vector(127 downto 0);
        variable byte_address,slot_base,image_base : unsigned(31 downto 0);
        variable offset_in_slot,row,row_byte,slot : natural;
        variable unknown_byte : std_logic_vector(7 downto 0);
        variable allowed : boolean;
    begin
        clean_data := avl_writedata;
        IF avl_write='1' THEN
            assert not is_x(avl_address)
                report "unknown Avalon address before padding classification" severity failure;
            FOR lane IN 0 TO 15 LOOP
                byte_address := (unsigned(avl_address) & "0000") +
                                to_unsigned(write_beat_index*16+lane,32);
                allowed := false;
                IF byte_address>=to_unsigned(BASE_ADDRESS,32) THEN
                    slot := to_integer((byte_address-to_unsigned(BASE_ADDRESS,32)) /
                                       to_unsigned(RAMSIZE_BYTES,32));
                    assert slot<3 report "padding adapter saw out-of-range slot" severity failure;
                    slot_base := to_unsigned(BASE_ADDRESS+slot*RAMSIZE_BYTES,32);
                    offset_in_slot := to_integer(byte_address-slot_base);
                    IF first_header_done='0' AND offset_in_slot>=16 AND offset_in_slot<256 THEN
                        allowed := true;
                    ELSE
                        image_base := slot_base + 256;
                        IF byte_address>=image_base THEN
                            row := to_integer((byte_address-image_base)/to_unsigned(512,32));
                            row_byte := to_integer((byte_address-image_base) mod to_unsigned(512,32));
                            IF row<TEST_ACTIVE_HEIGHT AND row_byte>=261 AND row_byte<512 THEN allowed := true; END IF;
                        END IF;
                    END IF;
                END IF;
                unknown_byte := clean_data(lane*8+7 DOWNTO lane*8);
                IF is_x(unknown_byte) THEN
                    IF allowed THEN
                        FOR bit_ix IN 0 TO 7 LOOP
                            IF is_x(clean_data(lane*8+bit_ix)) THEN
                                clean_data(lane*8+bit_ix) := PADDING_FILL(bit_ix);
                            END IF;
                        END LOOP;
                    END IF;
                END IF;
            END LOOP;
        END IF;
        model_writedata <= clean_data;
    END PROCESS;

    PaddingAudit: process(avl_clk)
        variable beat : natural range 0 to 15 := 0;
        variable first_done : std_logic := '0';
        variable bits_seen : natural := 0;
        variable first_a,last_a : unsigned(31 downto 0) := (others=>'0');
        variable byte_a : unsigned(31 downto 0);
        variable nbits : natural;
        variable slot_base,image_base,row,row_byte,slot,beat_unknown_bits : natural;
    begin
        if rising_edge(avl_clk) then
            if reset_na='0' then
                first_done := '0'; beat := 0; bits_seen := 0;
                first_a := (others=>'0'); last_a := (others=>'0');
            elsif avl_write='1' and avl_waitrequest='0' then
                assert not is_x(avl_address)
                    report "unknown accepted Avalon address before numeric conversion" severity failure;
                byte_a := (unsigned(avl_address) & "0000") + to_unsigned(beat*16,32);
                beat_unknown_bits := 0;
                slot := to_integer((byte_a-to_unsigned(BASE_ADDRESS,32))/to_unsigned(RAMSIZE_BYTES,32));
                assert slot<3 report "padding audit saw out-of-range framebuffer slot" severity failure;
                slot_base := BASE_ADDRESS + slot*RAMSIZE_BYTES;
                image_base := slot_base + 256;
                FOR lane IN 0 TO 15 LOOP
                    nbits := 0;
                    for bit_ix in 0 to 7 loop
                        if is_x(avl_writedata(lane*8+bit_ix)) then nbits := nbits+1; end if;
                    end loop;
                    if nbits>0 then
                        beat_unknown_bits := beat_unknown_bits + nbits;
                        row := 0; row_byte := 0;
                        if to_integer(byte_a)+lane>=image_base then
                            row := (to_integer(byte_a)+lane-image_base)/512;
                            row_byte := (to_integer(byte_a)+lane-image_base) mod 512;
                        end if;
                        assert (first_done='0' and to_integer(byte_a)+lane>=slot_base+16 and
                                to_integer(byte_a)+lane<slot_base+256) or
                               (to_integer(byte_a)+lane>=image_base and row<TEST_ACTIVE_HEIGHT and row_byte>=261)
                            report "unknown accepted write outside audited padding" severity failure;
                        if bits_seen=0 then first_a:=byte_a+to_unsigned(lane,32); end if;
                        last_a:=byte_a+to_unsigned(lane,32); bits_seen:=bits_seen+nbits;
                    end if;
                END LOOP;
                if beat_unknown_bits>0 then
                    report "padding fill x" & to_hstring(PADDING_FILL) &
                           " substituted " & integer'image(beat_unknown_bits) &
                           " unknown bits in accepted burst beat at " &
                           to_hstring(std_logic_vector(byte_a)) severity note;
                end if;
                if beat=15 then
                    beat := 0;
                    if to_integer(unsigned(avl_address)&"0000")=slot_base and first_done='0' then
                        first_done := '1';
                    end if;
                else
                    beat := beat+1;
                end if;
                first_header_done<=first_done;
                write_beat_index<=beat;
                pad_substituted_bits<=bits_seen;
                pad_first_address<=std_logic_vector(first_a);
                pad_last_address<=std_logic_vector(last_a);
                padding_unknown<='1' when bits_seen>0 else '0';
            end if;
        end if;
    end process;

    LegacyHeaderCounter: process(avl_clk)
        variable next_count : natural range 0 to 7 := 0;
        variable count_seen : natural := 0;
        variable byte_base : unsigned(31 downto 0);
        variable delta : natural;
    begin
        if rising_edge(avl_clk) and reset_na='1' and
           avl_write='1' and avl_waitrequest='0' and write_beat_index=0 and
           cap_state/=x"02" and cap_state/=x"03" and cap_state/=x"04" then
            byte_base := unsigned(avl_address) & "0000";
            if byte_base>=to_unsigned(BASE_ADDRESS,32) then
                delta := to_integer(byte_base-to_unsigned(BASE_ADDRESS,32));
                if delta mod RAMSIZE_BYTES=0 then
                    assert not is_x(avl_writedata(47 downto 45))
                        report "legacy header frame-counter bits are unknown" severity failure;
                    assert to_integer(unsigned(avl_writedata(47 downto 45)))=next_count
                        report "legacy header frame counter did not start at zero/wrap modulo8" severity failure;
                    next_count := (next_count+1) mod 8;
                    count_seen := count_seen+1;
                    header_count<=count_seen;
                end if;
            end if;
        end if;
    end process;

    Raster: process
        variable y : natural;
        variable slot_base,pixel_byte,row_byte,xpix,channel : natural;
        variable value : unsigned(7 downto 0);
        variable frame_id : integer;
        variable candidate : boolean;
        variable target_matches : natural := 0;
        variable target_slot : integer := -1;
        variable resumed_slot_matches : natural := 0;
    begin
        if LARGE_SCAN_TEST then wait until reset_na='1'; end if;
        -- Continue native video for three frames after CAB DONE so a clean
        -- release must resume at a real VS boundary without another CAB token.
        for f in 0 to TEST_FRAME_COUNT loop
            native_frame_id <= f;
            i_fl <= '1' when INTERLACED_SOURCE and (f mod 2)=1 else '0';
            -- Start in vertical blanking so the scaler sees a real frame
            -- boundary before the first active line.  Production starts at
            -- an arbitrary point in the raster, but capture is armed only
            -- after the normal scaler has acquired a valid frame.
            for row in 0 to TEST_VTOTAL-1 loop
                y := (row + TEST_VTOTAL-8) mod TEST_VTOTAL;
                for x in 0 to 127 loop
                    wait until falling_edge(i_clk);
                    native_vs_rise_soon <= '1' when x=127 and y=TEST_VTOTAL-9 else '0';
                    i_hs <= '1' when x>=100 and x<108 else '0';
                    i_vs <= '1' when y>=TEST_VTOTAL-8 and y<TEST_VTOTAL-4 else '0';
                    native_lvbl <= '1' when y>=4 and y<4+TEST_ACTIVE_HEIGHT else '0';
                    i_de <= '1' when x>=4 and x<91 and y>=4 and y<4+TEST_ACTIVE_HEIGHT else '0';
                    if x>=4 and x<91 and y>=4 and y<4+TEST_ACTIVE_HEIGHT then
                        i_r <= to_unsigned((f*37) mod 256,8);
                        i_g <= to_unsigned(x,8);
                        i_b <= to_unsigned((y*13+f) mod 256,8);
                    else
                        i_r <= (others=>'0');
                        i_g <= (others=>'0');
                        i_b <= (others=>'0');
                    end if;
                end loop;
            end loop;
        end loop;
        wait for 200 us;
        assert accepted_beats>0 report "no accepted ascal Avalon writes" severity failure;
        assert committed_beats=accepted_beats report "ascal writes remain pending" severity failure;
        assert pending_writes=0 report "ascal write queue did not drain" severity failure;
        assert returned_beats>0 report "ascal scaler issued no Avalon reads" severity failure;
        if not EXPECT_WRITE_COLLISION then
            assert slot_mask="111" report "progressive triple buffer did not visit all input slots" severity failure;
        end if;
        assert model_fault='0' report "Avalon model reported a protocol or bounds fault" severity failure;
        if TEST_IDLE_PROGRESS then
            assert cap_state=x"05" and cap_fault=x"00"
                report "idle progressive mode did not remain behind the quiescent startup drain barrier" severity failure;
        end if;
        if INTERLACED_SOURCE then
            assert not CAPTURE_ENABLE and not ARM_CAPTURE
                report "wrapper must leave capture tracking disabled for interlaced video" severity failure;
            assert cap_state=x"00" and cap_fault=x"00"
                report "unsupported idle interlaced mode was trapped by capture tracking" severity failure;
            report "PASS wrapper-disabled capture interlaced video remains unstopped" severity note;
            finish;
        end if;
        if CAPTURE_ARM_CHECKPOINT>0 and not EXPECT_WRITE_COLLISION and
           (LIFECYCLE_ERROR_BEFORE_ARM or LIFECYCLE_UNKNOWN_BEFORE_ARM or
            LIFECYCLE_STOP_BEFORE_TARGET or LIFECYCLE_UNEXPECTED_REARM or
            LIFECYCLE_UNKNOWN_ACTIVE_REARM or
            LIFECYCLE_REARM_RACE or ARMED_FAULT_WATCHDOG) then
            if LIFECYCLE_STOP_BEFORE_TARGET then
                assert cap_state=x"00" and release_test_done='1'
                    report "pre-target lifecycle STOP did not return to IDLE" severity failure;
            elsif ARMED_FAULT_WATCHDOG then
                assert cap_state=x"00" and cap_fault=x"06" and release_test_done='1'
                    report "ARMED fault watchdog did not safely return to IDLE" severity failure;
            elsif LIFECYCLE_UNEXPECTED_REARM or LIFECYCLE_UNKNOWN_ACTIVE_REARM then
                assert cap_state=x"05" and release_test_done='1'
                    report "unexpected lifecycle ARMED did not remain behind the fresh-IDLE barrier" severity failure;
            elsif LIFECYCLE_REARM_RACE then
                assert cap_state=x"05" and release_test_done='1'
                    report "same-edge lifecycle ARM race did not remain behind the fresh-IDLE barrier" severity failure;
            else
                assert cap_state=x"05" and release_test_done='1'
                    report "rejected lifecycle ARM did not remain behind the startup drain barrier" severity failure;
            end if;
            if LIFECYCLE_UNEXPECTED_REARM or LIFECYCLE_UNKNOWN_ACTIVE_REARM then
                assert cap_fault=x"05" report "unexpected/unknown lifecycle fault changed" severity failure;
            elsif LIFECYCLE_REARM_RACE then
                assert cap_fault=x"03" report "same-edge re-ARM request did not fail with BAD_STATE" severity failure;
            elsif LIFECYCLE_ERROR_BEFORE_ARM then
                assert cap_fault=x"03" report "errored lifecycle fault changed" severity failure;
            elsif LIFECYCLE_UNKNOWN_BEFORE_ARM then
                assert cap_fault=x"03" report "unknown lifecycle state fault changed" severity failure;
            else
                assert cap_fault=x"05" report "pre-target STOP first fault changed" severity failure;
            end if;
        elsif FENCE_CORRUPTION_TEST then
			assert fence_corrupt_drain_done='1' and cap_state=x"00" and
			       cap_fault=x"0A" and cap_result_toggle='0' and release_test_done='1'
				report "fence corruption did not fault, drain all beats, and clean up" severity failure;
		elsif CAPTURE_ARM_CHECKPOINT>0 and not EXPECT_WRITE_COLLISION and not ARMED_FAULT_WATCHDOG then
            report "capture checkpoint state=" & to_hstring(cap_state) &
                   " fault=" & to_hstring(cap_fault) &
                   " native tags=" & integer'image(native_tag_count) severity note;
			assert cap_state=x"00" and release_test_done='1'
				report "armed capture did not complete READY and clean release" severity failure;
            IF BAD_RELEASE_THEN_ABORT AND NOT REARM_AFTER_CLEANUP THEN
                ASSERT cap_fault=x"0C" REPORT "BAD_RELEASE did not remain sticky after cleanup" SEVERITY failure;
            ELSIF REARM_AFTER_CLEANUP THEN
                ASSERT cap_fault=x"00" REPORT "valid re-arm failed to clear sticky fault" SEVERITY failure;
            ELSIF EXPECT_WATCHDOG THEN
                ASSERT cap_fault=x"0B" REPORT "watchdog fault did not remain sticky after cleanup" SEVERITY failure;
            ELSIF ARMED_FAULT_WATCHDOG THEN
                ASSERT cap_fault=x"06" REPORT "ARMED watchdog did not retain the first unsupported-mode fault" SEVERITY failure;
            ELSE
                assert cap_fault=x"00" report "capture target path raised a fault" severity failure;
            END IF;
            if COALESCE_TWO_ACKS then
                assert coalesced_ack_test_passed='1'
                    report "two pending ACK toggles were not coalesced and resumed" severity failure;
            end if;
            if STALL_CAPTURE_FINAL then
                assert stall_release_seen='1'
                    report "stalled Avalon final beat was not released and drained" severity failure;
            end if;
            assert native_tag_count>=choose(LARGE_SCAN_TEST,10,3)
                report "native source stopped advancing while target was held" severity failure;
            assert native_manifest(CAPTURE_ARM_CHECKPOINT)>=0
                report "target checkpoint has no native raster manifest entry" severity failure;
            assert held_write_snapshot_valid='1'
                report "hold write audit did not reach the next active-image boundary" severity failure;
            assert release_test_done='1'
                report "capture target never completed READY and release" severity failure;
        elsif EXPECT_WATCHDOG then
            if REARM_AFTER_CLEANUP then
                assert cap_state=x"00" and cap_fault=x"00" and release_test_done='1'
                    report "watchdog cleanup/re-arm did not return to clean IDLE" severity failure;
            else
                assert cap_state=x"00" and cap_fault=x"0B" and release_test_done='1'
                    report "watchdog did not safely clean a forgotten capture hold" severity failure;
            end if;
        elsif ABORT_AFTER_ARM then
            assert cap_state=x"00" and release_test_done='1'
                report "matching abort did not return to safe IDLE" severity failure;
        end if;

        if not EXPECT_WRITE_COLLISION then
        for slot in 0 to 2 loop
            slot_base := BASE_ADDRESS + slot*RAMSIZE_BYTES;
            frame_id := -1;
            for row in 0 to 8 loop
                for word_index in 0 to 16 loop
                    pixel_byte := slot_base + 256 + row*512 + word_index*16;
                    observe_address <= std_logic_vector(to_unsigned(pixel_byte/16,28));
                    wait until falling_edge(avl_clk);
                    wait until falling_edge(avl_clk);
                    assert not is_x(observe_data)
                        report "unknown committed pixel word in slot" & integer'image(slot) &
                               " row" & integer'image(row) & " word" & integer'image(word_index)
                        severity failure;
                    for lane in 0 to 15 loop
                        row_byte := word_index*16+lane;
                        if row_byte<261 then
                            xpix := 4 + row_byte/3;
                            channel := row_byte mod 3;
                            value := unsigned(observe_data(lane*8+7 downto lane*8));
                            if row=0 and row_byte<3 then
                                if channel=0 then
                for f in 0 to TEST_FRAME_COUNT loop
                                        if to_integer(value)=((f*37) mod 256) then
                                            if frame_id/=-1 then
                                                assert frame_id=f report "ambiguous first pixel frame ID" severity failure;
                                            end if;
                                            frame_id:=f;
                                        end if;
                                    end loop;
                                elsif channel=1 then
                                    assert to_integer(value)=4 report "first pixel green byte mismatch" severity failure;
                                else
                                    assert frame_id>=0 and to_integer(value)=52+frame_id
                                        report "first pixel blue byte did not identify a frame" severity failure;
                                end if;
                            end if;
                            assert frame_id>=0 report "no independent frame ID in pixel slot" severity failure;
                            if channel=0 then
                                candidate := to_integer(value)=((frame_id*37) mod 256);
                            elsif channel=1 then
                                candidate := to_integer(value)=xpix;
                            else
                                candidate := to_integer(value)=((row+4)*13+frame_id) mod 256;
                            end if;
                            assert candidate
                                report "independent RGB byte mismatch in slot" & integer'image(slot) &
                                       " row" & integer'image(row) & " pixel" & integer'image(xpix) &
                                       " channel" & integer'image(channel)
                                severity failure;
                        end if;
                    end loop;
                end loop;
            end loop;
            assert frame_id>=0 report "slot has no recognized source frame" severity failure;
            report "slot" & integer'image(slot) & " independently matches input frame" &
                   integer'image(frame_id) severity note;
            if frame_id>TEST_FRAME_COUNT-3 then resumed_slot_matches:=resumed_slot_matches+1; end if;
            if CAPTURE_ARM_CHECKPOINT>0 and
               frame_id=native_manifest(CAPTURE_ARM_CHECKPOINT) then
                target_matches:=target_matches+1;
                target_slot:=slot;
            end if;
        end loop;
        if CAPTURE_ARM_CHECKPOINT>0 and release_test_done='0' then
            assert target_matches=1
                report "native target checkpoint did not leave exactly one matching input slot" severity failure;
            report "checkpoint " & integer'image(CAPTURE_ARM_CHECKPOINT) &
                   " source frame " & integer'image(native_manifest(CAPTURE_ARM_CHECKPOINT)) &
                   " remains in input slot " & integer'image(target_slot) severity note;
        elsif CAPTURE_ARM_CHECKPOINT>0 then
            assert resumed_slot_matches>0
                report "no post-DONE resumed input image reached the memory model" severity failure;
            report "PASS full input image continued after ownership cleanup; slots=" &
                   integer'image(resumed_slot_matches) severity note;
            IF LIFECYCLE_ERROR_BEFORE_ARM OR LIFECYCLE_UNKNOWN_BEFORE_ARM OR LIFECYCLE_STOP_BEFORE_TARGET THEN
                report "ordinary video remained live after lifecycle guard/cancellation" severity note;
            ELSIF BAD_RELEASE_THEN_ABORT THEN
                report "BAD_RELEASE remained sticky while ordinary input video resumed" severity note;
            ELSE
                report "checkpoint image remained immutable through READY; slot reuse passed after clean release"
                    severity note;
            END IF;
        end if;
        end if;
        report "PASS actual ascal input/Avalon model: writes=" & integer'image(to_integer(committed_beats)) severity note;
        report "Padding substitutions: bits=" & integer'image(pad_substituted_bits) &
               " first=" & to_hstring(pad_first_address) &
               " last=" & to_hstring(pad_last_address) &
               " fill=x" & to_hstring(PADDING_FILL) severity note;
        if CAPTURE_ARM_CHECKPOINT=0 then
            assert header_count>=9 report "did not observe the legacy header frame counter wrap" severity failure;
            report "Legacy header counter checked through " & integer'image(header_count) & " headers" severity note;
        end if;
        if EXPECT_WRITE_COLLISION then
            wait;
        else
            finish;
        end if;
    end process;

    SlotObserve: process
        variable a,delta,slot : natural;
    begin
        wait until falling_edge(avl_clk);
        if committed_write='1' then
            a := to_integer(unsigned(committed_address));
            if a>=BASE_ADDRESS then
                delta := a-BASE_ADDRESS;
                slot := delta/RAMSIZE_BYTES;
                if slot<3 then slot_mask(slot)<='1'; end if;
            end if;
        end if;
    end process;

    TargetPixelWriteAudit: process(avl_clk)
        variable a : natural;
        constant PIXEL_START : natural := BASE_ADDRESS + 2*RAMSIZE_BYTES + 256;
    begin
        if rising_edge(avl_clk) then
            if reset_na='0' then
                post_hold_target_pixel_writes<=0;
            elsif held_write_snapshot_valid='1' and committed_write='1' then
                a:=to_integer(unsigned(committed_address));
                if a>=PIXEL_START and a<PIXEL_START+TEST_SCAN_BURSTS*256 then
                    post_hold_target_pixel_writes<=post_hold_target_pixel_writes+1;
                end if;
            end if;
        end if;
    end process;

    u_mem : entity work.ascal_avalon_mem_model
        generic map (
            BASE_ADDRESS=>BASE_ADDRESS,
            RAMSIZE_BYTES=>RAMSIZE_BYTES,
            SLOT_FOOTPRINT_BYTES=>SLOT_FOOTPRINT_BYTES,
            SLOTS=>3,
            REORDER_CROSS_PAGE=>true,
            FENCE_CORRUPT_BEAT=>FENCE_CORRUPT_BEAT,
            STALL_CYCLES=>MEM_STALL_CYCLES
        )
        port map (
            clk=>avl_clk,
            waitrequest=>avl_waitrequest,
            readdata=>avl_readdata,
            readdatavalid=>avl_readdatavalid,
            burstcount=>avl_burstcount,
            writedata=>model_writedata,
            address=>avl_address,
            write=>avl_write,
            read=>avl_read,
            byteenable=>avl_byteenable,
            reset=>not reset_na,
            stall_all=>stall_all,
            observe_address=>model_observe_address,
            stall_target_last=>stall_target_last,
            observe_data=>observe_data,
            accepted_write_beats=>accepted_beats,
            committed_write_beats=>committed_beats,
            returned_read_beats=>returned_beats,
            pending_writes=>pending_writes,
            pending_reads=>pending_reads,
            accepted_write=>accepted_write,
            accepted_address=>accepted_address,
            accepted_last=>accepted_last,
            committed_write=>committed_write,
            committed_address=>committed_address,
            committed_last=>committed_last,
            returned_read=>returned_read,
            returned_address=>returned_address,
            returned_last=>returned_last,
            fence_corrupt_drain_done=>fence_corrupt_drain_done,
            fault=>model_fault
        );

    u_ascal : entity work.ascal
        generic map (
            RAMBASE=>to_unsigned(BASE_ADDRESS,32),
            RAMSIZE=>to_unsigned(RAMSIZE_BYTES,32),
            OHRES=>2304,
            IHRES=>128,
            N_DW=>128,
            N_AW=>28,
            FRAC=>4,
            CAPTURE=>CAPTURE_ENABLE,
            CAPTURE_WRITE_ID_SEED=>WRITE_ID_SEED,
            CAPTURE_CYCLES_PER_MS=>WATCHDOG_CYCLES_PER_MS,
            PALETTE=>false,
            PALETTE2=>false,
            ADAPTIVE=>false
        )
        port map (
            i_r=>i_r, i_g=>i_g, i_b=>i_b,
            i_hs=>i_hs, i_vs=>ascal_i_vs, i_fl=>i_fl, i_de=>i_de, i_ce=>i_ce_enable, i_clk=>i_clk,
            o_r=>video_r, o_g=>video_g, o_b=>video_b, o_hs=>video_hs, o_vs=>video_vs,
            o_de=>video_de, o_vbl=>open, o_brd=>open,
            o_ce=>'1', o_clk=>o_clk,
            gun_border_en=>'0', o_lltune=>open, i_hdmax=>open, i_vdmax=>open,
            run=>run, mode=>"01000", iauto=>TEST_IAUTO,
            himin=>0, himax=>86, vimin=>0, vimax=>TEST_ACTIVE_HEIGHT-1,
            freeze=>freeze_input,
            htotal=>128, hsstart=>100, hsend=>108, hdisp=>96, hmin=>0, hmax=>86,
            vtotal=>TEST_VTOTAL, vsstart=>TEST_VTOTAL-8, vsend=>TEST_VTOTAL-5,
            vdisp=>TEST_ACTIVE_HEIGHT, vmin=>0, vmax=>TEST_ACTIVE_HEIGHT-1,
            poly_clk=>i_clk, poly_dw=>(others=>'0'), poly_a=>(others=>'0'), poly_wr=>'0',
            avl_clk=>avl_clk, avl_waitrequest=>avl_waitrequest,
            avl_readdata=>avl_readdata, avl_readdatavalid=>avl_readdatavalid,
            avl_burstcount=>avl_burstcount, avl_writedata=>avl_writedata,
            avl_address=>avl_address, avl_write=>avl_write, avl_read=>avl_read,
            avl_byteenable=>avl_byteenable,
            reset_na=>reset_na,
            cap_io_clk=>cap_io_clk, cap_io_rst=>cap_io_rst,
            cap_req_toggle=>cap_req_toggle, cap_req=>cap_req, cap_req_ack_toggle=>cap_req_ack,
            cap_release_toggle=>cap_release_toggle, cap_release=>cap_release,
            cap_release_ack_toggle=>cap_release_ack,
            cap_abort_toggle=>cap_abort_toggle, cap_abort=>cap_abort,
            cap_abort_ack_toggle=>cap_abort_ack,
            cap_life_toggle=>cap_life_toggle, cap_life=>cap_life,
            cap_life_ack_toggle=>cap_life_ack,
            cap_tag_ready=>cap_tag_ready,
            cap_result_toggle=>cap_result_toggle, cap_result=>cap_result,
			cap_result_ack_toggle=>cap_result_ack,
			cap_tag_clk=>cap_tag_clk, cap_tag_valid=>cap_tag_valid, cap_tag=>cap_tag,
			cap_tag_error=>'0',
            cap_mode_supported=>cap_mode_supported,
            cap_state=>cap_state, cap_fault=>cap_fault,
            cap_tag_rst=>cap_tag_rst
        );
end architecture;
