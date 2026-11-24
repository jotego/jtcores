#include "case_table.h"

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned long u32;

void start_measurement(void);
void configure_case(u32 case_id);
void fatal(void);
void measured_loop(void);
void enter_hot_reload(void);
extern char kernel_rom_start, kernel_rom_end;
extern char kernel_ram_start, kernel_ram_end;
extern char kernel_rom_w0, kernel_rom_w1, kernel_rom_w2, kernel_rom_w4;
extern char kernel_rom_0, kernel_rom_1, kernel_rom_2, kernel_rom_4;
extern volatile const u32 firmware_image_crc32;
extern volatile const u32 firmware_suite_crc32;

#define REG16(a) (*(volatile u16 *)(a))
#define RAM16(a) (*(volatile u16 *)(a))
#define RAM32(a) (*(volatile u32 *)(a))
#define SAMPLES ((volatile u32 *)0x00ff0100)
#define SAMPLE_END (0x00ff0100UL + TOTAL_SAMPLES * 4UL)
#define SUMMARY_PAGES 9
#define PAGE_COUNT (SUMMARY_PAGES + CASE_COUNT)
#define CASE_INDEX RAM16(0x00ff0020)
#define SAMPLE_INDEX RAM16(0x00ff0022)
#define SAMPLE_PTR RAM32(0x00ff0024)
#define NEXT_KERNEL RAM32(0x00ff0030)
#define NEXT_DATA RAM32(0x00ff0034)
#define CURRENT_OBJECT_END RAM16(0x00ff0038)
#define NEXT_MMR_WRITE_ADDRESS RAM32(0x00ff0048)
#define NEXT_MMR_WRITE_VALUE RAM16(0x00ff004c)
#define MEASURE_ARMED RAM16(0x00ff003a)
#define FRAME_TICK RAM16(0x00ff003e)
#define HOST_SESSION RAM16(0x00ff0040)
#define HOST_RX_EXPECTED RAM16(0x00ff0042)
#define HOST_RESTART_PENDING RAM16(0x00ff0044)
#define REQUESTED_PAGE (*(volatile u8 *)0x00ff002a)
#define ACTIVE_PAGE (*(volatile u8 *)0x00ff002b)
#define DISPLAY_ROW (*(volatile u8 *)0x00ff002c)
#define INPUT_SYS REG16(0x00800018)
#define VRAM ((volatile u16 *)0x00900000)
#define RAM_KERNEL_BASE 0x00ffe000UL
#define ROM_DATA_ADDRESS 0x00020000UL
#define RAM_DATA_ADDRESS 0x00ff4000UL
#define VRAM_DATA_ADDRESS 0x0091f000UL
#define OBJ_ATTR_ADDRESS(entry) (0x00920006UL + ((u32)(entry) * 8UL))
#define PICO_ACTIVE (*(volatile u8 *)0x0003b808)
#define PICO_IN_SEQ (*(volatile u8 *)0x0003b818)
#define PICO_RX_DATA (*(volatile u8 *)0x0003bc00)
#define PICO_TX_BASE 0x0003be00UL
#define HOT_GO_PREFIX ((volatile u8 *)0x00ff7010)

static u16 glyph_top(u8 c) {
    return (u16)(0x4c00 + ((c & 0xf0) << 1) + (c & 0x0f));
}

static void put_char(u8 row, u8 col, u8 c, u8 colour) {
    u16 index = (u16)((((u16)col + 8) << 5) + (u16)row * 2 + 2);
    u16 word = (u16)(index * 2);
    u16 code = glyph_top(c);
    VRAM[word] = code;
    VRAM[word + 1] = colour;
    VRAM[word + 2] = (u16)(code + 0x10);
    VRAM[word + 3] = colour;
}

static void put_text(u8 row, u8 col, const char *s, u8 colour) {
    while (*s && col < 48) put_char(row, col++, (u8)*s++, colour);
}

static u32 divide_by_10(u32 value, u8 *remainder) {
    u32 quotient = 0;
    u16 rem = 0;
    u8 i;
    for (i = 0; i < 32; ++i) {
        u8 bit = (u8)(31 - i);
        rem = (u16)((rem << 1) | ((value >> bit) & 1));
        if (rem >= 10) {
            rem -= 10;
            quotient |= (u32)1 << bit;
        }
    }
    *remainder = (u8)rem;
    return quotient;
}

static u8 put_decimal(u8 row, u8 col, u32 value) {
    char digits[10];
    u8 count = 0;
    u8 remainder;
    do {
        value = divide_by_10(value, &remainder);
        digits[count++] = (char)('0' + remainder);
    } while (value);
    {
        u8 length = count;
        while (count) put_char(row, col++, (u8)digits[--count], 0);
        return length;
    }
}

static u32 percent_of(u32 value, u32 baseline) {
    u32 numerator = value * 100, quotient = 0, remainder = 0;
    u8 bit;
    if (!baseline) return 0;
    for (bit = 0; bit < 32; ++bit) {
        u8 shift = (u8)(31 - bit);
        remainder = (remainder << 1) | ((numerator >> shift) & 1);
        if (remainder >= baseline) {
            remainder -= baseline;
            quotient |= (u32)1 << shift;
        }
    }
    return quotient;
}

static void put_percent(u8 row, u8 col, u32 value) {
    u16 number = (u16)value;
    u8 digits;
    if (number > 999) number = 999;
    digits = put_decimal(row, col, number);
    put_char(row, (u8)(col + digits), '%', 0);
}

static void clear_screen(void) {
    u8 row, col;
    for (row = 0; row < 14; ++row)
        for (col = 0; col < 48; ++col)
            put_char(row, col, ' ', 0);
}

static void clear_row(u8 row) {
    u8 col;
    for (col = 0; col < 48; ++col) put_char(row, col, ' ', 0);
}

static void init_palette(void) {
    static const u16 colours[5] = { 0xffff, 0xff00, 0xf0f0, 0xf00f, 0xf888 };
    volatile u16 *p = (volatile u16 *)0x00914400;
    u8 group, pen;
    for (group = 0; group < 5; ++group)
        for (pen = 0; pen < 16; ++pen)
            p[group * 16 + pen] = colours[group];
    REG16(0x0080014a) = 0x003f;
    REG16(0x0080010a) = 0x9140; /* palette transfer trigger */
}

static void restore_display_palette(void) {
    /* Stock SF2EB service CHARACTER > SCROLL1 viewer color 08, captured
       while it displays tiles 0x4c81/0x4c91 with attribute group 8. */
    static const u16 text_palette[16] = {
        0xf000, 0xf500, 0xf700, 0xf900,
        0xfa00, 0xfc00, 0xff50, 0xff73,
        0xff93, 0xfea4, 0xfec6, 0xfed9,
        0xfeea, 0xfefb, 0xfefc, 0xf000
    };
    volatile u16 *p = (volatile u16 *)0x00914000;
    u16 i;
    /* Six palette pages black, with the stock viewer group 0 on page 1. */
    for (i = 0; i < 0x0c00; ++i) p[i] = 0;
    for (i = 0; i < 16; ++i) p[0x0200 + i] = text_palette[i];
    p[0x0bff] = 0; /* backdrop pen at 0x9157fe */
    REG16(0x0080014a) = 0x003f;
    REG16(0x0080010a) = 0x9140; /* full palette transfer trigger */
}

static void init_video(void) {
    volatile u16 *vram = (volatile u16 *)0x00900000;
    volatile u16 *objects = (volatile u16 *)0x00920000;
    u32 i;
    /* Match the known boot state on MAME and physical VRAM. */
    for (i = 0; i < 0x18000; ++i) vram[i] = 0;
    /* Entries before each test terminator are active; park them offscreen. */
    for (i = 0; i < 256; ++i) {
        objects[i * 4] = 0x01ff;
        objects[i * 4 + 1] = 0x01ff;
        objects[i * 4 + 2] = 0;
        objects[i * 4 + 3] = 0;
    }
    REG16(0x00800100) = 0x9200; /* object table */
    REG16(0x00800102) = 0x9000; /* scroll 1 text tilemap */
    REG16(0x00800104) = 0x9040;
    REG16(0x00800106) = 0x9080;
    REG16(0x00800108) = 0x9100;
    REG16(0x0080010a) = 0x9140;
    REG16(0x0080010c) = 0;
    REG16(0x0080010e) = 0;
    REG16(0x00800110) = 0;
    REG16(0x00800112) = 0;
    REG16(0x00800114) = 0;
    REG16(0x00800116) = 0;
    REG16(0x00800118) = 0;
    REG16(0x0080011a) = 0;
    REG16(0x0080011c) = 0;
    REG16(0x0080011e) = 0;
    REG16(0x00800120) = 0;
    REG16(0x00800122) = 0x0000; /* scroll-DMA controls off in baseline */
    REG16(0x00800154) = 0x3900; /* SF2EB CPS-B17, scroll layers off */
    REG16(0x00920006) = 0xff00; /* empty object-table terminator */
    /* Distinct source values make page and control-mask copies observable. */
    {
        volatile u16 *palette = (volatile u16 *)0x00914000;
        u16 i;
        for (i = 0; i < 0x0c00; ++i)
            palette[i] = (u16)(0xf000 | ((i * 37u) & 0x0fff));
    }
    init_palette();
    clear_screen();
}

static void init_benchmark_data(void) {
    volatile u16 *ram = (volatile u16 *)RAM_DATA_ADDRESS;
    volatile u16 *vram = (volatile u16 *)VRAM_DATA_ADDRESS;
    u16 i;
    for (i = 0; i < 64; ++i) {
        ram[i] = (u16)(0x5100 + i);
        vram[i] = (u16)(0x6300 + i);
    }
    if (ram[0] != 0x5100 || vram[0] != 0x6300 ||
        *(volatile u16 *)ROM_DATA_ADDRESS != 0xffff) {
        fatal();
    }
}

static void copy_ram_kernels(void) {
    volatile u8 *dest = (volatile u8 *)RAM_KERNEL_BASE;
    u32 size = (u32)(&kernel_ram_end - &kernel_ram_start);
    const u8 *source = (const u8 *)&kernel_ram_start;
    u32 i;
    if (size != 96 || RAM_KERNEL_BASE < 0x00ff8000UL ||
        RAM_KERNEL_BASE + size > 0x01000000UL) fatal();
    for (i = 0; i < size; ++i) dest[i] = source[i];
    for (i = 0; i < size; ++i) if (dest[i] != source[i]) fatal();
}

void configure_case(u32 case_id) {
    const CaseSpec *spec;
    u32 kernel;
    u32 data_address;
    u8 slot = 0;
    if (case_id >= CASE_COUNT) fatal();
    spec = &CASES[case_id];
    REG16(0x00800122) = spec->video_control;
    REG16(0x00800154) = spec->layer_control;
    if (spec->family_id == 3 || spec->family_id == 4 ||
        spec->family_id == 5 || spec->family_id == 10) {
        REG16(0x0080010e) = spec->vpos1;
        REG16(0x00800112) = spec->vpos2;
        REG16(0x00800116) = spec->vpos3;
    }
    if (spec->video_control & 1) REG16(0x00800108) = spec->row_base;
    REG16(0x00800120) = spec->row_scroll;
    if (spec->palette_case) {
        REG16(0x0080014a) = spec->palette_control;
        if (spec->palette_trigger) {
            NEXT_MMR_WRITE_ADDRESS = 0x0080010aUL;
            NEXT_MMR_WRITE_VALUE = 0x9140;
        } else {
            /* A scroll-1 Y write is harmless with all scroll layers disabled;
               any write to 0x80010a triggers palette DMA, including value 0. */
            NEXT_MMR_WRITE_ADDRESS = 0x0080010eUL;
            NEXT_MMR_WRITE_VALUE = 0;
        }
    } else if (spec->object_base_each_vblank) {
        NEXT_MMR_WRITE_ADDRESS = 0x00800100UL;
        NEXT_MMR_WRITE_VALUE = 0x9200;
    } else {
        NEXT_MMR_WRITE_ADDRESS = 0x00800104UL;
        NEXT_MMR_WRITE_VALUE = 0x9040;
    }

    if (CURRENT_OBJECT_END != spec->object_end_entry) {
        REG16(OBJ_ATTR_ADDRESS(CURRENT_OBJECT_END)) = 0;
        REG16(OBJ_ATTR_ADDRESS(spec->object_end_entry)) = 0xff00;
        CURRENT_OBJECT_END = spec->object_end_entry;
    }
    if (spec->family_id == 9) {
        volatile u16 *objects = (volatile u16 *)0x00920000;
        u16 entry;
        for (entry = 0; entry < spec->object_payload_entries; ++entry) {
            objects[entry * 4] = 0x01ff;
            objects[entry * 4 + 1] = 0x01ff;
            objects[entry * 4 + 2] = (u16)(0x0100 + entry);
            objects[entry * 4 + 3] = (u16)(entry & 7);
        }
    }

    data_address = spec->data_address;
    if (spec->reads == 1 || spec->writes == 1) slot = 1;
    else if (spec->reads == 2 || spec->writes == 2) slot = 2;
    else if (spec->reads == 4 || spec->writes == 4) slot = 3;

    if (spec->family_id == 0 || spec->family_id == 3 || spec->family_id == 4 ||
        spec->family_id == 5 || spec->family_id == 6 ||
        spec->family_id == 9 || spec->family_id == 10) {
        kernel = (u32)measured_loop;
    } else if (spec->write_mode) {
        kernel = (u32)&kernel_rom_w0 + (u32)slot * 12;
    } else if (spec->fetch_ram) {
        kernel = RAM_KERNEL_BASE + (u32)slot * 12;
    } else if (slot == 0) {
        kernel = (u32)&kernel_rom_0;
    } else if (slot == 1) {
        kernel = (u32)&kernel_rom_1;
    } else if (slot == 2) {
        kernel = (u32)&kernel_rom_2;
    } else {
        kernel = (u32)&kernel_rom_4;
    }
    NEXT_KERNEL = kernel;
    NEXT_DATA = data_address;
}

static u16 crc16_ccitt(const volatile u8 *data, u8 length) {
    u16 crc = 0xffff;
    u8 i, bit;
    for (i = 0; i < length; ++i) {
        crc ^= (u16)data[i] << 8;
        for (bit = 0; bit < 8; ++bit) {
            if (crc & 0x8000) crc = (u16)((crc << 1) ^ 0x1021);
            else crc = (u16)(crc << 1);
        }
    }
    return crc;
}

static u32 crc32_samples(void) {
    const volatile u8 *data = (const volatile u8 *)SAMPLES;
    u32 crc = 0xffffffffUL;
    u16 i;
    u8 bit;
    for (i = 0; i < TOTAL_SAMPLES * 4; ++i) {
        crc ^= data[i];
        for (bit = 0; bit < 8; ++bit) {
            if (crc & 1) crc = (crc >> 1) ^ 0xedb88320UL;
            else crc >>= 1;
        }
    }
    return ~crc;
}

static void put_be16(volatile u8 *out, u16 value) {
    out[0] = (u8)(value >> 8);
    out[1] = (u8)value;
}

static void put_be32(u8 *out, u32 value) {
    out[0] = (u8)(value >> 24);
    out[1] = (u8)(value >> 16);
    out[2] = (u8)(value >> 8);
    out[3] = (u8)value;
}

static u8 picorom_magic(void) {
    return *(volatile u8 *)0x0003b800 == 'P' &&
           *(volatile u8 *)0x0003b802 == 'I' &&
           *(volatile u8 *)0x0003b804 == 'C' &&
           *(volatile u8 *)0x0003b806 == 'O';
}

static void wait_vblank_tick(void) {
    u16 tick = FRAME_TICK;
    while (FRAME_TICK == tick) { }
}

static u8 read_host_raw_byte(u8 *received) {
    u16 timeout = 120;
    while (timeout--) {
        u8 sequence;
        wait_vblank_tick();
        if (PICO_ACTIVE != 1) return 0;
        sequence = PICO_IN_SEQ;
        if (sequence == (u8)HOST_RX_EXPECTED) continue;
        if (sequence != (u8)(HOST_RX_EXPECTED + 1)) return 0;
        HOST_RX_EXPECTED = sequence;
        *received = PICO_RX_DATA;
        return 1;
    }
    return 0;
}

static u8 wait_host_byte(u8 expected_value, u8 *received) {
    u16 timeout = 120;
    while (timeout--) {
        u8 sequence;
        wait_vblank_tick();
        if (PICO_ACTIVE != 1) {
            HOST_SESSION = 0;
            return 0;
        }
        sequence = PICO_IN_SEQ;
        if (sequence == (u8)HOST_RX_EXPECTED) continue;
        if (sequence != (u8)(HOST_RX_EXPECTED + 1)) return 0;
        HOST_RX_EXPECTED = sequence;
        *received = PICO_RX_DATA;
        if (*received == expected_value) return 1;
        if (*received == 0x47) HOST_RESTART_PENDING = 1;
        return 0;
    }
    HOST_SESSION = 0;
    return 0;
}

static u8 send_frame(u8 flags, const u8 *payload, u16 *sequence) {
    volatile u8 packet[27];
    u16 crc;
    u8 i, received;
    packet[0] = 0xa5;
    packet[1] = 0x5a;
    packet[2] = 2;
    packet[3] = (u8)(FW_BUILD_ID >> 8);
    packet[4] = (u8)FW_BUILD_ID;
    packet[5] = (u8)(*sequence >> 8);
    packet[6] = (u8)*sequence;
    packet[7] = 16;
    packet[8] = flags;
    for (i = 0; i < 16; ++i) packet[9 + i] = payload[i];
    crc = crc16_ccitt(packet, 25);
    packet[25] = (u8)(crc >> 8);
    packet[26] = (u8)crc;
    for (i = 0; i < 27; ++i) {
        /* PicoROM sends the byte encoded by this even/high-lane address. */
        volatile u8 sent = *(volatile u8 *)(PICO_TX_BASE + ((u32)packet[i] << 1));
        (void)sent;
    }
    if (!wait_host_byte((u8)*sequence, &received)) return 0;
    ++*sequence;
    return 1;
}

static u8 send_results(void) {
    u8 payload[16];
    u16 sequence = 0;
    u16 index;
    u32 results_crc = crc32_samples();
    u32 image_crc = firmware_image_crc32;
    u32 suite_crc = firmware_suite_crc32;
    u32 run_id = image_crc ^ suite_crc ^ results_crc;

    /* Narrow DATA values are exact only while every retained count fits u16. */
    for (index = 0; index < TOTAL_SAMPLES; ++index) {
        if (SAMPLES[index] > 0xffffUL) {
            u8 i;
            for (i = 0; i < sizeof(payload); ++i) payload[i] = 0;
            payload[0] = 'C'; payload[1] = 'N'; payload[2] = 'T'; payload[3] = 'O';
            payload[4] = 'V'; payload[5] = 'F'; payload[6] = 'L'; payload[7] = 'W';
            put_be16(&payload[8], index);
            put_be32(&payload[10], SAMPLES[index]);
            return send_frame(0x80, payload, &sequence);
        }
    }

    put_be32(&payload[0], image_crc);
    put_be32(&payload[4], suite_crc);
    put_be32(&payload[8], run_id);
    payload[12] = CASE_COUNT;
    payload[13] = SAMPLES_PER_CASE;
    put_be16(&payload[14], TOTAL_SAMPLES);
    if (!send_frame(0x01, payload, &sequence)) return 0;

    put_be32(&payload[0], results_crc);
    put_be32(&payload[4], 0x00ff0100UL);
    put_be32(&payload[8], SAMPLE_END);
    put_be16(&payload[12], TOTAL_SAMPLES * 4);
    put_be16(&payload[14], DATA_FRAME_COUNT);
    if (!send_frame(0x02, payload, &sequence)) return 0;

    for (index = 0; index < TOTAL_SAMPLES; index += DATA_SAMPLES_PER_FRAME) {
        u8 value;
        for (value = 0; value < DATA_SAMPLES_PER_FRAME; ++value) {
            u16 sample_index = index + value;
            u16 sample = sample_index < TOTAL_SAMPLES ? (u16)SAMPLES[sample_index] : 0;
            put_be16(&payload[value * 2], sample);
        }
        if (!send_frame(0x10, payload, &sequence)) return 0;
    }

    put_be32(&payload[0], results_crc);
    put_be16(&payload[4], TOTAL_SAMPLES);
    put_be16(&payload[6], DATA_FRAME_COUNT);
    payload[8] = 0;
    for (index = 8; index < 16; ++index) payload[index] = 0;
    return send_frame(0x20, payload, &sequence);
}

static void poll_results_host(void) {
    u8 active, sequence, command;
    active = PICO_ACTIVE;
    if (active != 1) {
        HOST_SESSION = 0;
        HOST_RX_EXPECTED = 0;
        return;
    }
    if (!HOST_SESSION) {
        if (!picorom_magic()) return;
        HOST_SESSION = 1;
        HOST_RX_EXPECTED = 0;
    }
    sequence = PICO_IN_SEQ;
    if (sequence == (u8)HOST_RX_EXPECTED) return;
    if (sequence != (u8)(HOST_RX_EXPECTED + 1)) return;
    HOST_RX_EXPECTED = sequence;
    command = PICO_RX_DATA;
    if (command == 0x47) {
        do {
            HOST_RESTART_PENDING = 0;
        } while (!send_results() && HOST_RESTART_PENDING);
    } else if (command == 0x48) {
        volatile u8 *prefix = HOT_GO_PREFIX;
        u8 index, received;
        prefix[0] = 0x47;
        for (index = 0; index < 8; ++index) {
            if (!read_host_raw_byte(&received)) return;
            prefix[index + 1] = received;
        }
        enter_hot_reload();
    }
}

static u32 median3(const volatile u32 *data, u16 first) {
    u32 sorted[8];
    u8 i, j;
    for (i = 0; i < 8; ++i) sorted[i] = data[first + i];
    for (i = 1; i < 8; ++i) {
        u32 value = sorted[i];
        j = i;
        while (j && sorted[j - 1] > value) {
            sorted[j] = sorted[j - 1];
            --j;
        }
        sorted[j] = value;
    }
    return sorted[3];
}

static u32 case_median(u8 case_id) {
    return median3(SAMPLES, (u16)(case_id * SAMPLES_PER_CASE + 1));
}

static void draw_case_line(u8 row, u8 case_id, u8 baseline_case) {
    u32 first = SAMPLES[(u16)case_id * SAMPLES_PER_CASE];
    u32 median = case_median(case_id);
    u32 minimum = SAMPLES[(u16)case_id * SAMPLES_PER_CASE + 1];
    u32 maximum = minimum;
    u8 i;
    for (i = 2; i < SAMPLES_PER_CASE; ++i) {
        u32 value = SAMPLES[(u16)case_id * SAMPLES_PER_CASE + i];
        if (value < minimum) minimum = value;
        if (value > maximum) maximum = value;
    }
    put_text(row, 0, CASES[case_id].label, 0);
    put_decimal(row, 11, first);
    put_decimal(row, 18, minimum);
    put_decimal(row, 25, median);
    put_decimal(row, 32, maximum);
    put_percent(row, 40, percent_of(median, case_median(CASES[case_id].reference_case_id)));
}

static void draw_summary_row(u8 row) {
    switch (row) {
        case 0: put_text(row, 0, "PAGE 1 DMA / OBJECT TESTS V14", 0); break;
        case 1: put_text(row, 0, "DEC LOOPS/FRAME; REL% VS CASE BASELINE", 0); break;
        case 2:
            put_text(row, 0, "CASE", 0);
            put_text(row, 11, "FIRST", 0);
            put_text(row, 18, "MIN", 0);
            put_text(row, 25, "MED", 0);
            put_text(row, 32, "MAX", 0);
            put_text(row, 40, "REL", 0);
            break;
        case 3: draw_case_line(row, 0, 0); break;
        case 4: draw_case_line(row, 1, 0); break;
        case 5: draw_case_line(row, 2, 0); break;
        case 6: draw_case_line(row, 3, 0); break;
        case 7: draw_case_line(row, 24, 4); break;
        case 8: draw_case_line(row, 25, 4); break;
        case 9: draw_case_line(row, 26, 4); break;
        case 10: draw_case_line(row, 27, 4); break;
        case 11: put_text(row, 0, "OBJ HOLD/TRIG A/B; SAME TABLE, WRITE COST", 0); break;
        case 12: put_text(row, 0, "OBJ REL REF=ROMF-NONE; FIRST=TRANSITION", 0); break;
        case 13: put_text(row, 0, "COIN: ROM FETCH PAGE", 0); break;
        default: break;
    }
}

static void draw_phase_page(u8 row) {
    if (row == 0) put_text(row, 0, "PAGE 4 SCROLL VPOS PHASE A/B PAIRS", 0);
    else if (row == 1) put_text(row, 0, "DEC LOOPS/FRAME; REL% VS VPOS0 A", 0);
    else if (row == 2) {
        put_text(row, 0, "CASE", 0);
        put_text(row, 11, "FIRST", 0);
        put_text(row, 18, "MIN", 0);
        put_text(row, 25, "MED", 0);
        put_text(row, 32, "MAX", 0);
        put_text(row, 40, "REL", 0);
    } else if (row >= 3 && row <= 10) {
        u8 case_id = (u8)(28 + row - 3);
        draw_case_line(row, case_id, case_id < 32 ? 28 : 32);
    } else if (row == 11) put_text(row, 0, "S1 VPOS 0/1; S2 VPOS 0/3", 0);
    else if (row == 12) put_text(row, 0, "ABBA ORDER; FIRST=TRANSITION", 0);
    else if (row == 13) put_text(row, 0, "COIN: RAW FRAME COUNTS", 0);
}

static void draw_memory_page(u8 row, u8 first_case, const char *title) {
    if (row == 0) put_text(row, 0, title, 0);
    else if (row == 1) put_text(row, 0, "DEC LOOPS/FRAME; REL% VS CASE REFERENCE", 0);
    else if (row == 2) {
        put_text(row, 0, "CASE", 0);
        put_text(row, 11, "FIRST", 0);
        put_text(row, 18, "MIN", 0);
        put_text(row, 25, "MED", 0);
        put_text(row, 32, "MAX", 0);
        put_text(row, 40, "REL", 0);
    } else if (row >= 3 && row <= 12) {
        u8 case_id = (u8)(first_case + row - 3);
        if (case_id < CASE_COUNT)
            draw_case_line(row, case_id, CASES[case_id].reference_case_id);
    } else if (row == 13) put_text(row, 0, "COIN: NEXT RESULT PAGE", 0);
}

static void draw_extended_summary(u8 row, u8 page) {
    static const u8 rows[5][10] = {
        {36,37,38,39,40,75,76,0,0,0},
        {41,42,43,44,45,46,47,48,49,50},
        {51,52,53,54,55,56,57,58,59,60},
        {61,62,63,64,65,66,67,68,0,0},
        {69,70,71,72,73,74,0,0,0,0}
    };
    static const u8 counts[5] = {7,10,10,8,6};
    static const char *titles[5] = {
        "PAGE 5 S3 / ROW / COMBOS", "PAGE 6 PALETTE MASKS 0-A",
        "PAGE 7 PALETTE 3F / WRITE LADDERS", "PAGE 8 OBJECT SOURCE R/W",
        "PAGE 9 OBJECT PAYLOAD LENGTHS"
    };
    u8 which = (u8)(page - 4);
    if (which >= 5) return;
    if (row == 0) put_text(row, 0, titles[which], 0);
    else if (row == 1) put_text(row, 0, "DEC LOOPS/FRAME; REL% VS CASE REFERENCE", 0);
    else if (row == 2) {
        put_text(row, 0, "CASE", 0);
        put_text(row, 11, "FIRST", 0);
        put_text(row, 18, "MIN", 0);
        put_text(row, 25, "MED", 0);
        put_text(row, 32, "MAX", 0);
        put_text(row, 40, "REL", 0);
    } else if (row >= 3 && row <= 12) {
        u8 index = (u8)(row - 3);
        if (index < counts[which]) {
            u8 case_id = rows[which][index];
            draw_case_line(row, case_id, CASES[case_id].reference_case_id);
        }
    } else if (row == 13) put_text(row, 0, "COIN: NEXT RESULT PAGE", 0);
}

static void draw_raw_case_page(u8 row, u8 page) {
    u8 case_id = (u8)(page - SUMMARY_PAGES);
    u16 first;
    if (row == 0) {
        put_text(row, 0, "PAGE ", 0);
        put_decimal(row, 5, (u32)page + 1);
        put_text(row, 7, " RAW ", 0);
        put_text(row, 12, CASES[case_id].label, 0);
    } else if (row == 1) {
        if (case_id == 0)
            put_text(row, 0, "DEC LOOPS/FRAME; 0=WARMUP; 1-8=STEADY", 0);
        else
            put_text(row, 0, "DEC LOOPS/FRAME; 0=TRANSITION; 1-8=STEADY", 0);
    } else if (row >= 2 && row <= 4) {
        first = (u16)case_id * SAMPLES_PER_CASE + (row - 2) * 3;
        put_text(row, 0, (row == 2) ? "SAMPLES 0-2" : (row == 3) ? "SAMPLES 3-5" : "SAMPLES 6-8", 0);
        put_decimal(row, 13, SAMPLES[first]);
        put_decimal(row, 25, SAMPLES[first + 1]);
        put_decimal(row, 37, SAMPLES[first + 2]);
    } else if (row == 5) {
        put_text(row, 0, "THREE CONSECUTIVE FRAME COUNTS PER ROW", 0);
    } else if (row == 13) {
        put_text(row, 0, "COIN: NEXT CASE / SUMMARY", 0);
    }
}

static void intro_screen(void) {
    clear_screen();
    put_text(1, 4, "JTCORES CPS1 DIAGNOSTIC V14", 0);
    put_text(3, 5, "SF2 90629B-3 / CPS-B17", 0);
    put_text(6, 4, "DMA / PALETTE / ACCESS TESTS", 0);
    put_text(8, 7, "RUNNING EXTENDED SUITE", 0);
    put_text(11, 0, "RED", 1);
    put_text(11, 5, "GREEN", 2);
    put_text(11, 12, "BLUE", 3);
    put_text(11, 18, "WHITE", 0);
    put_text(11, 26, "GRAY", 4);
}

void display_main(void) {
    u8 page = 0;
    u16 last_tick = FRAME_TICK;
    /* The write ladders must leave only the known parked values behind. */
    if (*(volatile u16 *)RAM_DATA_ADDRESS != 0x01ff ||
        *(volatile u16 *)VRAM_DATA_ADDRESS != 0x01ff ||
        *(volatile u16 *)0x00920000UL != 0x01ff) fatal();
    NEXT_MMR_WRITE_ADDRESS = 0x00800100UL;
    NEXT_MMR_WRITE_VALUE = 0x9200;
    REG16(0x00800122) = 0x0000;
    REG16(0x00800154) = 0x1540; /* text selector, layers temporarily disabled */
    REG16(0x00800102) = 0x9000;
    REG16(0x0080010c) = 0;
    REG16(0x0080010e) = 0;
    if (CURRENT_OBJECT_END != 0) {
        REG16(OBJ_ATTR_ADDRESS(CURRENT_OBJECT_END)) = 0;
        REG16(OBJ_ATTR_ADDRESS(0)) = 0xff00;
        CURRENT_OBJECT_END = 0;
    }
    restore_display_palette();
    /* Retrigger after replacing the final test marker; let the object buffer
       consume the clean table for two VBlanks before restoring the text. */
    REG16(0x00800100) = 0x9200;
    wait_vblank_tick();
    wait_vblank_tick();
    REG16(0x00800122) = 0x0002;
    REG16(0x00800154) = 0x1548; /* text only, selected in all four priority slots */
    REQUESTED_PAGE = 0;
    ACTIVE_PAGE = 0xff;
    DISPLAY_ROW = 0;
    for (;;) {
        if (FRAME_TICK != last_tick) {
            last_tick = FRAME_TICK;
            poll_results_host();
        }
        if ((INPUT_SYS & 0x0100) == 0) {
            while ((INPUT_SYS & 0x0100) == 0) { }
            if (++page >= PAGE_COUNT) page = 0;
            REQUESTED_PAGE = page;
        }
    }
}

void display_tick(void) {
    u8 row;
    if (ACTIVE_PAGE != REQUESTED_PAGE) {
        ACTIVE_PAGE = REQUESTED_PAGE;
        DISPLAY_ROW = 0;
    }
    row = DISPLAY_ROW;
    if (row >= 14) return;
    clear_row(row);
    if (ACTIVE_PAGE == 0) draw_summary_row(row);
    else if (ACTIVE_PAGE == 1) draw_memory_page(row, 4, "PAGE 2 ROM FETCH / DATA READS");
    else if (ACTIVE_PAGE == 2) draw_memory_page(row, 14, "PAGE 3 RAM FETCH / DATA READS");
    else if (ACTIVE_PAGE == 3) draw_phase_page(row);
    else if (ACTIVE_PAGE >= 4 && ACTIVE_PAGE < SUMMARY_PAGES)
        draw_extended_summary(row, ACTIVE_PAGE);
    else draw_raw_case_page(row, ACTIVE_PAGE);
    DISPLAY_ROW = (u8)(row + 1);
}

void firmware_main(void) {
    u16 page;
    for (page = 0; page < TOTAL_SAMPLES; ++page) SAMPLES[page] = 0;
    CASE_INDEX = 0;
    SAMPLE_INDEX = 0;
    SAMPLE_PTR = (u32)SAMPLES;
    REQUESTED_PAGE = ACTIVE_PAGE = DISPLAY_ROW = 0;
    init_video();
    init_benchmark_data();
    copy_ram_kernels();
    CURRENT_OBJECT_END = 0;
    MEASURE_ARMED = 0;
    FRAME_TICK = 0;
    HOST_SESSION = 0;
    HOST_RX_EXPECTED = 0;
    HOST_RESTART_PENDING = 0;
    configure_case(0);
    intro_screen();
    __asm__ volatile ("move.b (0x0003be22).l,%%d7" ::: "d7"); /* PicoROM marker 11 */
    start_measurement();
    for (;;) { }
}
