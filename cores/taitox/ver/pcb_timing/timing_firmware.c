/* Frame-paced matched-loop suite for the Superman P0-039A. */
typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned long u32;

#define RUN_COUNT 35u
#define SAMPLES_PER_RUN 1u
#define INTERVALS_PER_RUN (SAMPLES_PER_RUN + 1u)
#define TOTAL_SAMPLES (RUN_COUNT * SAMPLES_PER_RUN)
#define DATA_FRAME_COUNT ((TOTAL_SAMPLES + 3u) / 4u)
#define RAM_DATA 0x00f02000UL
#define ROM_DATA 0x00010000UL  /* A10/A5 physical 0x8000: lower 64 KiB only */
#define OBJ_DATA 0x00e03ffeUL
#define Y_DATA 0x00d003feUL
#define OBJ_SOURCE_CODE 0x00e003feUL
#define OBJ_ACTIVE_CODE 0x00e023feUL
#define PICO_ACTIVE (*(volatile u8 *)0x0001b808UL)
#define PICO_IN_SEQ (*(volatile u8 *)0x0001b818UL)
#define PICO_RX_DATA (*(volatile u8 *)0x0001bc00UL)
#define PICO_TX_BASE 0x0001be00UL

extern void timing_start_first(void);
extern void timing_fixed_suite(void);
extern char timing_baseline, timing_read1, timing_read2, timing_read4;
extern char timing_write1, timing_write2, timing_write4, timing_idle;
extern volatile u32 timing_image_crc32, timing_suite_crc32;

volatile u32 timing_next_pc;
volatile u32 timing_next_data;
volatile u32 timing_irq_count;
volatile u32 timing_irq2_count;
volatile u32 timing_irq4_count;
volatile u32 timing_irq6_count;
volatile u16 timing_irq_level;
volatile u16 timing_run_index;
volatile u16 timing_sample_index;
volatile u16 timing_armed;
volatile u16 timing_done;
volatile u16 timing_redirect;
volatile u16 timing_clear_d0;
volatile u16 timing_host_seq;
volatile u32 timing_samples[RUN_COUNT][INTERVALS_PER_RUN];

static void send_results(void);

#define YRAM        ((volatile u16 *)0x00d00000UL)
#define OBJECT_SRC  ((volatile u16 *)0x00e00000UL)
#define OBJECT_XSRC ((volatile u16 *)0x00e00400UL)
#define OBJECT_CODE ((volatile u16 *)0x00e02000UL)
#define OBJECT_X    ((volatile u16 *)0x00e02400UL)
#define PALETTE     ((volatile u16 *)0x00b00000UL)
#define BACKDROP    (PALETTE[0x01f0])
#define WATCHDOG    (*(volatile u16 *)0x00400000UL)

static void palette_group(u16 index, u16 color) {
    u16 i;
    for (i = 0; i < 16; ++i) PALETTE[index + i] = color;
}

/* Proven boot-v4 X1-001 setup: colored two-row object strip over blue. */
static void timing_video_init(void) {
    static const u16 colors[8] = {
        0x7c00, 0x03e0, 0x001f, 0x7fff,
        0x4210, 0x03ff, 0x7c1f, 0x7fe0
    };
    u16 i;
    for (i = 0; i < 512; ++i) {
        YRAM[i] = 0x0080;
        if ((i & 0xff) == 0xff) WATCHDOG = 0x0010;
    }
    for (i = 0; i < 256; ++i) {
        YRAM[512 + i] = 0;
        if ((i & 0x7f) == 0x7f) WATCHDOG = 0x0010;
    }
    for (i = 0; i < 8192; ++i) {
        OBJECT_SRC[i] = 0;
        if ((i & 0xff) == 0xff) WATCHDOG = 0x0010;
    }
    for (i = 0; i < 512; ++i) {
        OBJECT_X[i] = 0x01f0;
        OBJECT_XSRC[i] = 0x01f0;
        if ((i & 0xff) == 0xff) WATCHDOG = 0x0010;
    }
    for (i = 0; i < 512; ++i) {
        PALETTE[i] = 0;
        if ((i & 0xff) == 0xff) WATCHDOG = 0x0010;
    }
    for (i = 0; i < 8; ++i) palette_group((u16)((i + 1) * 16), colors[i]);
    BACKDROP = 0x001f;

    for (i = 0; i < 32; ++i) {
        u16 x = (u16)(8 + (i & 15) * 16);
        u16 y = (u16)(0x009e + (i >> 4) * 0x10);
        u16 group = (u16)(1 + (i & 7));
        u16 attr = (u16)((group << 11) | x);
        OBJECT_X[i] = attr;
        OBJECT_XSRC[i] = attr;
        OBJECT_CODE[i] = (u16)(i + 1);
        OBJECT_SRC[i] = (u16)(i + 1);
        YRAM[i] = y;
    }
    *(volatile u16 *)0x00d00600UL = 0x0010;
    *(volatile u16 *)0x00d00602UL = 0;
    *(volatile u16 *)0x00d00604UL = 0;
    *(volatile u16 *)0x00d00606UL = 0;
}

static u32 data_for(u16 run) {
    if (run <= 3) return ROM_DATA;
    if (run <= 9) return RAM_DATA;
    if (run <= 15) return OBJ_DATA;
    if (run <= 21) return Y_DATA;
    if (run <= 27) return OBJ_SOURCE_CODE;
    if (run <= 33) return OBJ_ACTIVE_CODE;
    return RAM_DATA;
}

static u32 select_kernel(u16 run) {
    u16 count;
    if (run == 0 || run == 34) return (u32)&timing_baseline;
    count = (u16)(run - 1);
    while (count >= 3) count = (u16)(count - 3);
    ++count;
    if (run <= 3) return count == 1 ? (u32)&timing_read1 :
                           count == 2 ? (u32)&timing_read2 : (u32)&timing_read4;
    if (run <= 6 || (run >= 10 && run <= 12) || (run >= 16 && run <= 18) ||
        (run >= 22 && run <= 24) || (run >= 28 && run <= 30))
        return count == 1 ? (u32)&timing_read1 :
               count == 2 ? (u32)&timing_read2 : (u32)&timing_read4;
    return count == 1 ? (u32)&timing_write1 :
           count == 2 ? (u32)&timing_write2 : (u32)&timing_write4;
}

static void select_run(u16 run) {
    timing_next_data = data_for(run);
    timing_next_pc = select_kernel(run);
}

static void zero_samples(void) {
    volatile u32 *p = (volatile u32 *)timing_samples;
    u16 i;
    for (i = 0; i < RUN_COUNT * INTERVALS_PER_RUN; ++i) p[i] = 0;
}

void timing_main(void) {
    zero_samples();
    timing_irq_count = 0;
    timing_irq2_count = 0;
    timing_irq4_count = 0;
    timing_irq6_count = 0;
    timing_irq_level = 0;
    timing_run_index = 0;
    timing_sample_index = 0;
    timing_armed = 0;
    timing_done = 0;
    timing_redirect = 0;
    timing_clear_d0 = 0;
    timing_host_seq = 0;
    timing_next_pc = (u32)&timing_idle;
    timing_next_data = RAM_DATA;
    timing_video_init();
    {
        volatile u16 watchdog_spin = 0;
        *(volatile u16 *)0x00400000UL = 0x0010;
        *(volatile u16 *)0x00600000UL = 0x0010; /* clear stale VBL latch */
        *(volatile u16 *)0x00300000UL = 0x0010; /* clear stale C-chip latch */
        __asm__ volatile ("move.b (0x0001be22).l,%%d7" ::: "d7", "memory");
        __asm__ volatile ("move.w #0x2000,%%sr" ::: "memory");
        while (!timing_irq_level) {
            if (++watchdog_spin == 0) *(volatile u16 *)0x00400000UL = 0x0010;
        }
    }
    __asm__ volatile ("move.w #0x2700,%%sr" ::: "memory");
    *(volatile u16 *)0x00e003feUL = 0x01f0;
    *(volatile u16 *)0x00e007feUL = 0x01f0;
    *(volatile u16 *)0x00e023feUL = 0x01f0;
    *(volatile u16 *)0x00e027feUL = 0x01f0;
    *(volatile u16 *)0x00d003feUL = 0x01f0;
    *(volatile u16 *)0x00d00602UL = 0;
    select_run(0);
    timing_armed = 1;
    timing_redirect = 1;
    timing_start_first();
}

/* Called by the shared IRQ2/IRQ6 assembly entry with D0 and exception IPL. */
void timing_irq_tick(u32 loops, u32 level) {
    u16 run, sample;
    ++timing_irq_count;
    if (level == 2) ++timing_irq2_count;
    if (level == 4) ++timing_irq4_count;
    if (level == 6) ++timing_irq6_count;
    if (level == 4) {
        if (!timing_irq_level && timing_irq4_count == 1) BACKDROP = 0x03ff;
        return;                        /* C-chip IRQ is not a VBlank sample */
    }
    if (!timing_irq_level) {
        timing_irq_level = (u16)level;
        BACKDROP = level == 2 ? 0x03e0 : 0x7c00;
    }
    if (level != timing_irq_level) return;
    if (!timing_armed) return;
    timing_redirect = 1;
    if (timing_done) {
        if (PICO_ACTIVE == 1 && PICO_IN_SEQ != (u8)timing_host_seq) {
            u8 seq = PICO_IN_SEQ;
            if (seq == (u8)(timing_host_seq + 1)) {
                u8 command = PICO_RX_DATA;
                timing_host_seq = seq;
                if (command == 0x47) {
                    __asm__ volatile ("move.w #0x2700,%%sr" ::: "memory");
                    send_results();
                }
            }
        }
        return;
    }
    timing_clear_d0 = 1;
    run = timing_run_index;
    sample = timing_sample_index;
    /* Slot zero is the transition interval. It uses the same store path so
       the next interval starts after the same handler work as later samples. */
    timing_samples[run][sample] = loops;
    ++timing_sample_index;
    if (sample + 1 != INTERVALS_PER_RUN) return;
    timing_sample_index = 0;
    ++run;
    if (run == RUN_COUNT) {
        timing_next_pc = (u32)&timing_idle;
        timing_fixed_suite();
        timing_done = 1;
        BACKDROP = 0x7fff;
        __asm__ volatile ("move.b (0x0001be24).l,%%d7" ::: "d7");
        return;
    }
    timing_run_index = run;
    select_run(run);                  /* all A0/setup work is outside kernel */
}

static u16 crc16_ccitt(const u8 *data, u8 length) {
    u16 crc = 0xffff;
    u8 i, bit;
    for (i = 0; i < length; ++i) {
        crc ^= (u16)data[i] << 8;
        for (bit = 0; bit < 8; ++bit)
            crc = (crc & 0x8000) ? (u16)((crc << 1) ^ 0x1021) : (u16)(crc << 1);
    }
    return crc;
}

static u32 exported_sample(u16 index) {
    u16 run = (u16)(index / SAMPLES_PER_RUN);
    u16 sample = (u16)(index % SAMPLES_PER_RUN + 1u);
    return timing_samples[run][sample];
}

static u32 crc32_samples(void) {
    u32 crc = 0xffffffffUL;
    u16 index;
    u8 byte, bit;
    for (index = 0; index < TOTAL_SAMPLES; ++index) {
        u32 value = exported_sample(index);
        for (byte = 0; byte < 4; ++byte) {
            crc ^= (u8)(value >> (24 - byte * 8));
            for (bit = 0; bit < 8; ++bit)
                crc = (crc & 1) ? (crc >> 1) ^ 0xedb88320UL : crc >> 1;
        }
    }
    return ~crc;
}

static void put_be16(u8 *out, u16 value) {
    out[0] = (u8)(value >> 8); out[1] = (u8)value;
}
static void put_be32(u8 *out, u32 value) {
    out[0] = (u8)(value >> 24); out[1] = (u8)(value >> 16);
    out[2] = (u8)(value >> 8); out[3] = (u8)value;
}

static u8 send_frame(u8 flags, const u8 *payload, u16 *sequence) {
    u8 packet[28] __attribute__((aligned(4))), i;  /* 68000: no odd long/word stores */
    u32 timeout;
    volatile u16 watchdog_spin = 0;
    u16 crc;
    u8 ack;
    packet[0] = 0xa5; packet[1] = 0x5a; packet[2] = 2;
    packet[3] = 0x23; packet[4] = 0x03;
    packet[5] = (u8)(*sequence >> 8); packet[6] = (u8)*sequence;
    packet[7] = 16; packet[8] = flags;
    for (i = 0; i < 16; ++i) packet[9 + i] = payload[i];
    crc = crc16_ccitt(packet, 25);
    packet[25] = (u8)(crc >> 8); packet[26] = (u8)crc;
    for (i = 0; i < 27; ++i) {
        volatile u8 sent = *(volatile u8 *)(PICO_TX_BASE + ((u32)packet[i] << 1));
        (void)sent;
    }
    timeout = 0x00100000UL;
    while (timeout--) {
        if (++watchdog_spin == 0) *(volatile u16 *)0x00400000UL = 0x0010;
        if (PICO_ACTIVE != 1) return 0;
        if (PICO_IN_SEQ == (u8)(timing_host_seq + 1)) {
            ack = PICO_RX_DATA;
            if (ack != (u8)*sequence) return 0;
            timing_host_seq = PICO_IN_SEQ;
            ++*sequence;
            return 1;
        }
    }
    return 0;
}

static void send_results(void) {
    u8 payload[16] __attribute__((aligned(4)));
    u16 sequence = 0, i, j, index;
    u32 crc = crc32_samples();
    u32 run_id = timing_image_crc32 ^ timing_suite_crc32 ^ crc;
    put_be32(&payload[0], timing_image_crc32);
    put_be32(&payload[4], timing_suite_crc32);
    put_be32(&payload[8], run_id);
    payload[12] = RUN_COUNT; payload[13] = SAMPLES_PER_RUN;
    put_be16(&payload[14], TOTAL_SAMPLES);
    if (!send_frame(0x01, payload, &sequence)) return;
    put_be32(&payload[0], crc);
    put_be32(&payload[4], (u32)timing_samples);
    put_be32(&payload[8], (u32)timing_samples + RUN_COUNT * INTERVALS_PER_RUN * 4u);
    put_be16(&payload[12], TOTAL_SAMPLES * 4u);
    put_be16(&payload[14], DATA_FRAME_COUNT);
    if (!send_frame(0x02, payload, &sequence)) return;
    put_be32(&payload[0], timing_irq2_count);
    put_be32(&payload[4], timing_irq4_count);
    put_be32(&payload[8], timing_irq6_count);
    put_be32(&payload[12], timing_irq_level);
    if (!send_frame(0x04, payload, &sequence)) return;
    index = 0;
    for (i = 0; i < DATA_FRAME_COUNT; ++i) {
        for (j = 0; j < 4; ++j) {
            u32 value = index < TOTAL_SAMPLES ? exported_sample(index) : 0;
            put_be32(&payload[j * 4], value);
            ++index;
        }
        if (!send_frame(0x10, payload, &sequence)) return;
    }
    put_be32(&payload[0], crc);
    put_be16(&payload[4], TOTAL_SAMPLES);
    put_be16(&payload[6], DATA_FRAME_COUNT);
    for (i = 8; i < 16; ++i) payload[i] = 0;
    (void)send_frame(0x20, payload, &sequence);
}
