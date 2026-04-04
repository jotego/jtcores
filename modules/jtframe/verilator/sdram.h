#ifndef JTFRAME_VERILATOR_SDRAM_H
#define JTFRAME_VERILATOR_SDRAM_H

#include <array>
#include <cstddef>
#include <cstdint>
#include <vector>

class UUT;

struct SDRAMPins {
    bool cke = true;
    bool ncs = true;
    bool nras = true;
    bool ncas = true;
    bool nwe = true;
    uint8_t ba = 0;
    uint8_t dqm = 0;
    uint16_t a = 0;
    uint16_t din = 0;
};

struct SDRAMOutputs {
    bool dq_drive = false;
    uint16_t dq = 0;
};

class SDRAMModel {
public:
    explicit SDRAMModel(int colw, bool verbose = false);

    void reset();
    void set_verbose(bool enable);

    int colw() const;
    int bank_word_len() const;
    int bank_byte_len() const;
    int word_mask() const;
    bool bank_active(int bank) const;
    int bank_row_base(int bank) const;
    int active_burst_kind() const;
    int active_burst_bank() const;

    uint16_t read_word(int bank, int addr) const;
    void write_word(int bank, int addr, uint16_t val, uint8_t dqm = 0);
    void clear_bank(int bank);
    void load_bank_bytes(int bank, const uint8_t* data, std::size_t len, bool swap_bytes = true);
    void dump_bank_bytes(int bank, uint8_t* data, std::size_t len, bool swap_bytes = true) const;

    SDRAMOutputs tick(const SDRAMPins& pins);

private:
    enum BurstKind {
        BURST_NONE,
        BURST_READ,
        BURST_WRITE
    };

    struct BankState {
        bool active = false;
        int row_base = 0;
    };

    struct BurstState {
        BurstKind kind = BURST_NONE;
        int bank = 0;
        int row_base = 0;
        int start_col = 0;
        int beat = 0;
        int burst_len = 1;
        int read_wait = 0;
        int read_stop = 0;
        bool full_page = false;
        bool interleaved = false;
        bool auto_precharge = false;
        bool write_single = false;
    };

    int colw_;
    int bank_word_len_;
    int bank_byte_len_;
    int word_mask_;
    int colmask_;
    bool verbose_;

    int burst_len_;
    int cas_latency_;
    bool burst_full_page_;
    bool burst_interleaved_;
    bool write_burst_single_;

    std::array<uint8_t, 2> read_dqm_;
    std::array<BankState, 4> banks_state_;
    std::array<std::vector<uint16_t>, 4> banks_;
    BurstState burst_;

    int decode_burst_length(int mode) const;
    int effective_write_length() const;
    int burst_limit(const BurstState& burst) const;
    int column_for_beat(const BurstState& burst, int beat) const;
    uint16_t apply_read_dqm(uint16_t value, uint8_t dqm) const;
    void change_mode(int mode);
    void terminate_burst(bool close_bank);
    void precharge_bank(int bank);
    void precharge_all();
    void start_read(int bank, int column, bool auto_precharge);
    void start_write(int bank, int column, bool auto_precharge);
    void accept_write_beat(uint16_t value, uint8_t dqm);
    SDRAMOutputs advance_read(uint8_t read_dqm);
};

class SDRAM {
    UUT& dut;
    SDRAMModel model;
    bool last_clk;

public:
    explicit SDRAM(UUT& _dut);
    ~SDRAM();
    void update();
    void dump();
};

#endif
