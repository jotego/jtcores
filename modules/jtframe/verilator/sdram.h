#ifndef JTFRAME_VERILATOR_SDRAM_H
#define JTFRAME_VERILATOR_SDRAM_H

class UUT;

class SDRAM {
    UUT& dut;
    char *banks[4];
    int rd_st[4], rd_left[4], ba_blen[4], ba_addr[4];
    char header[32];
    int burst_len, burst_mask, cas_latency;
    bool burst_full_page;

    int decode_burst_length(int mode);
    int read_offset( int region );
    int read_bank( char *bank, int addr );
    void write_bank16( char *bank,  int addr, int val, int dm );
    void change_burst();

public:
    SDRAM(UUT& _dut);
    ~SDRAM();
    void update();
    void dump();
};

#endif
