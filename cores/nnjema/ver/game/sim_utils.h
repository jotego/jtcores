#ifndef JTFRAME_VERILATOR_SIM_UTILS_H
#define JTFRAME_VERILATOR_SIM_UTILS_H

#include <string>

std::string trim(const std::string& text);
std::string lower(const std::string& text);
unsigned parse_number(const std::string& text, const std::string& what);
unsigned parse_hex(const std::string& text, const std::string& what);
bool valid_identifier(const std::string& text);

#endif
