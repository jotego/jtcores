#include <cctype>
#include <cstdlib>
#include <stdexcept>

#include "sim_utils.h"

using namespace std;

string trim(const string& text) {
    const auto first = text.find_first_not_of(" \t\r\n");
    if( first == string::npos ) return "";
    return text.substr(first, text.find_last_not_of(" \t\r\n") - first + 1);
}

string lower(const string& text) {
    string result = text;
    for( auto& c : result ) c = tolower(static_cast<unsigned char>(c));
    return result;
}

// C23 strtol accepts 0b prefixes but older C libraries do not: reject them everywhere
bool binary_number(const string& text) {
    const size_t start = !text.empty() && (text[0] == '+' || text[0] == '-') ? 1 : 0;
    return text.size() > start + 1 && text[start] == '0' && (text[start + 1] == 'b' || text[start + 1] == 'B');
}

unsigned parse_number(const string& text, const string& what) {
    char *end;
    const string value = trim(text);
    if( value.empty() || value[0] == '-' ) throw runtime_error(what + " must be a non-negative number");
    if( binary_number(value) ) throw runtime_error("cannot parse " + what + ": " + value);
    const unsigned long parsed = strtoul(value.c_str(), &end, 0);
    if( *end != 0 || parsed > 0xffffffffUL ) throw runtime_error("cannot parse " + what + ": " + value);
    return static_cast<unsigned>(parsed);
}

unsigned parse_hex(const string& text, const string& what) {
    char *end;
    const string value = trim(text);
    if( value.empty() || value[0] == '-' ) throw runtime_error(what + " must be a non-negative hexadecimal number");
    const unsigned long parsed = strtoul(value.c_str(), &end, 16);
    if( *end != 0 || parsed > 0xffffffffUL ) throw runtime_error("cannot parse " + what + ": " + value);
    return static_cast<unsigned>(parsed);
}

bool valid_identifier(const string& text) {
    return !text.empty() && text.find_first_not_of(
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-") == string::npos;
}
