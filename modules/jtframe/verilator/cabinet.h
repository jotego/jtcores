#ifndef JTFRAME_VERILATOR_CABINET_H
#define JTFRAME_VERILATOR_CABINET_H

#include <cstddef>
#include <cstdint>
#include <istream>
#include <string>
#include <vector>

struct CabinetFrame {
    unsigned inputs = 0;
    std::vector<std::string> cheats;
    bool has_dipsw = false;
    bool tracing_on = false;
    bool dump = false;
    unsigned dipsw = 0;
};

struct CabinetRun {
    CabinetFrame frame;
    std::uint64_t count;
};

class CabinetScript {
public:
    explicit CabinetScript(const char *filename);
    CabinetScript(std::istream& input, const std::string& source_name);

    bool done() const;
    const CabinetFrame& next();
    std::uint64_t frame_count() const;

private:
    struct Segment {
        std::vector<CabinetRun> runs;
        std::uint64_t repeats;
    };

    std::vector<Segment> segments;
    std::uint64_t frames = 0;
    std::size_t segment_position = 0;
    std::uint64_t segment_repeat = 0;
    std::size_t run_position = 0;
    std::uint64_t run_remaining = 0;

    void parse(std::istream& input, const std::string& source_name);
};

#endif
