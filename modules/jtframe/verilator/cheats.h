#ifndef JTFRAME_VERILATOR_CHEATS_H
#define JTFRAME_VERILATOR_CHEATS_H

#include <cstddef>
#include <map>
#include <string>
#include <vector>

struct CheatWrite {
    unsigned bank, offset, byte_mask, data;
};

class CheatDatabase {
public:
    explicit CheatDatabase(const std::string& filename);

    std::size_t definition_count() const;
    std::size_t target_count() const;
    bool has_target(const std::string& target) const;
    const std::vector<CheatWrite>* find(const std::string& target, const std::string& name) const;

private:
    std::map<std::string, std::map<std::string, std::vector<CheatWrite>>> cheats;
};

#endif
