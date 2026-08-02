#include <fstream>
#include <map>
#include <stdexcept>

#include "cheats.h"
#include "sim_utils.h"

using namespace std;

static string unquote(string value) {
    value = trim(value);
    if( value.size() >= 2 && ((value.front() == '"' && value.back() == '"') ||
                              (value.front() == '\'' && value.back() == '\''))) {
        value = value.substr(1, value.size() - 2);
    }
    return value;
}

static map<string, string> fields(const string& text, int line_no) {
    string body = trim(text);
    if( body.size() < 2 || body.front() != '{' || body.back() != '}' ) {
        throw runtime_error("invalid SDRAM cheat write at line " + to_string(line_no));
    }
    body = body.substr(1, body.size() - 2);
    map<string, string> result;
    size_t start = 0;
    while( start <= body.size() ) {
        const size_t comma = body.find(',', start);
        const string field = trim(body.substr(start, comma == string::npos ? string::npos : comma - start));
        const size_t colon = field.find(':');
        if( colon == string::npos || field.find(':', colon + 1) != string::npos ) {
            throw runtime_error("invalid SDRAM cheat write at line " + to_string(line_no));
        }
        const string key = trim(field.substr(0, colon));
        const string value = unquote(field.substr(colon + 1));
        if( key.empty() || value.empty() || !result.emplace(key, value).second ) {
            throw runtime_error("invalid SDRAM cheat write at line " + to_string(line_no));
        }
        if( comma == string::npos ) break;
        start = comma + 1;
    }
    return result;
}

static string value_after(const string& text, const string& key, int line_no) {
    const string prefix = key + ":";
    if( text.rfind(prefix, 0) != 0 ) throw runtime_error("invalid cheat entry at line " + to_string(line_no));
    return unquote(text.substr(prefix.size()));
}

CheatDatabase::CheatDatabase(const string& filename) {
    ifstream input(filename);
    if( !input ) throw runtime_error("could not open cheat file " + filename);

    string line, target, name;
    bool in_sdram = false;
    int line_no = 0;
    while( getline(input, line) ) {
        line_no++;
        const auto comment = line.find('#');
        if( comment != string::npos ) line.resize(comment);
        const string text = trim(line);
        if( text.empty() ) continue;
        const size_t indent = line.find_first_not_of(" \t");
        if( indent == 0 ) {
            if( text.back() != ':' ) throw runtime_error("invalid cheat target at line " + to_string(line_no));
            target = trim(text.substr(0, text.size() - 1));
            if( !valid_identifier(target) ) throw runtime_error("invalid cheat target at line " + to_string(line_no));
            if( !cheats.emplace(target, map<string, vector<CheatWrite>>()).second ) {
                throw runtime_error("duplicate cheat target '" + target + "'");
            }
            name.clear();
            in_sdram = false;
            continue;
        }
        if( target.empty() ) throw runtime_error("cheat entry without a target at line " + to_string(line_no));
        if( text.rfind("- name:", 0) == 0 ) {
            name = value_after(text.substr(2), "name", line_no);
            if( !valid_identifier(name) ) throw runtime_error("invalid cheat name in " + filename + " at line " + to_string(line_no));
            if( !cheats[target].emplace(name, vector<CheatWrite>()).second ) {
                throw runtime_error("duplicate cheat name '" + name + "' for target '" + target + "'");
            }
            in_sdram = false;
            continue;
        }
        if( name.empty() ) throw runtime_error("cheat entry without a name at line " + to_string(line_no));
        if( text.rfind("mame:", 0) == 0 ) {
            value_after(text, "mame", line_no);
            continue;
        }
        if( text == "sdram:" ) {
            in_sdram = true;
            continue;
        }
        if( !in_sdram || text.rfind("-", 0) != 0 ) {
            throw runtime_error("invalid cheat entry at line " + to_string(line_no));
        }
        const map<string, string> write_fields = fields(trim(text.substr(1)), line_no);
        const auto bank = write_fields.find("bank");
        const auto offset = write_fields.find("offset");
        const auto byte_mask = write_fields.find("byte-mask");
        const auto data = write_fields.find("data");
        if( write_fields.size() != 4 || bank == write_fields.end() || offset == write_fields.end() ||
            byte_mask == write_fields.end() || data == write_fields.end() ) {
            throw runtime_error("incomplete SDRAM cheat write at line " + to_string(line_no));
        }
        const CheatWrite write = {
            parse_number(bank->second, "cheat bank"),
            parse_number(offset->second, "cheat offset"),
            parse_number(byte_mask->second, "cheat byte-mask"),
            parse_number(data->second, "cheat data")
        };
        if( write.bank > 3 || write.byte_mask == 0 || write.byte_mask > 3 || write.data > 0xffff ) {
            throw runtime_error("invalid SDRAM cheat write at line " + to_string(line_no));
        }
        cheats[target][name].push_back(write);
    }

    for( const auto& target_entry : cheats ) {
        for( const auto& cheat_entry : target_entry.second ) {
            if( cheat_entry.second.empty() ) {
                throw runtime_error("cheat '" + cheat_entry.first + "' for target '" + target_entry.first + "' has no SDRAM writes");
            }
        }
    }
}

size_t CheatDatabase::definition_count() const {
    size_t count = 0;
    for( const auto& target : cheats ) count += target.second.size();
    return count;
}

size_t CheatDatabase::target_count() const {
    return cheats.size();
}

bool CheatDatabase::has_target(const string& target) const {
    return cheats.find(target) != cheats.end();
}

const vector<CheatWrite>* CheatDatabase::find(const string& target, const string& name) const {
    const auto target_entry = cheats.find(target);
    if( target_entry == cheats.end() ) return nullptr;
    const auto cheat_entry = target_entry->second.find(name);
    return cheat_entry == target_entry->second.end() ? nullptr : &cheat_entry->second;
}
