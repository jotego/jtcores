#ifndef JTFRAME_VERILATOR_CABINET_H
#define JTFRAME_VERILATOR_CABINET_H

#include <cstddef>
#include <cstdint>
#include <istream>
#include <stdexcept>
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

// Parse error that names the cabinet line where it was found
class CabinetError : public std::runtime_error {
public:
    CabinetError(const std::string& message, int line) : std::runtime_error(message), line_no(line) {}
    int line() const { return line_no; }
private:
    int line_no;
};

class CabinetScript {
public:
    static constexpr std::uint64_t CAPTURE_PERIOD = 100;
    explicit CabinetScript(const char *filename);
    CabinetScript(std::istream& input, const std::string& source_name);

    bool done() const;
    const CabinetFrame& next();
    CabinetRun next_run(); // Consume the remainder of a compact run, without frame expansion.
    std::uint64_t frame_count() const;
    bool has_capture() const;
    std::uint64_t capture_first() const; // first frame to capture, then every CAPTURE_PERIOD frames

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
    bool capture_set = false;
    std::uint64_t capture = 0;

    void parse(std::istream& input, const std::string& source_name);
    void parse_capture(const std::vector<std::string>& tokens, bool statements, int line_no);
    void advance_run();
};

#endif
