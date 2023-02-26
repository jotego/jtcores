// This code has ben adapted from MAME file fd1089.h

#ifndef MAME_MACHINE_FD1089_H
#define MAME_MACHINE_FD1089_H

#include <cstdint>
#include <type_traits>

//using std::uint16_t;
using offs_t = int;

#pragma once


template <typename T, typename U> constexpr T make_bitmask(U n)
{
        return T((n < (8 * sizeof(T)) ? (std::make_unsigned_t<T>(1) << n) : std::make_unsigned_t<T>(0))
- 1);
}
template <typename T, typename U> constexpr T BIT(T x, U n) noexcept { return (x >> n) & T(1); }
template <typename T, typename U, typename V> constexpr T BIT(T x, U n, V w)
{
        return (x >> n) & make_bitmask<T>(w);
}
template <typename T, typename U> constexpr T bitswap(T val, U b) noexcept { return BIT(val, b) << 0U; }

template <typename T, typename U, typename... V> constexpr T bitswap(T val, U b, V... c) noexcept
{
        return (BIT(val, b) << sizeof...(c)) | bitswap(val, c...);
}

template <unsigned B, typename T, typename... U> T bitswap(T val, U... b) noexcept
{
        static_assert(sizeof...(b) == B, "wrong number of bits");
        static_assert((sizeof(std::remove_reference_t<T>) * 8) >= B, "return type too small for result");
        return bitswap(val, b...);
}

// base device, shared implementation between A and B variants
class fd1089_base_device
{
public:
    uint16_t decrypt_one(offs_t addr, uint16_t val, const uint8_t *key, bool opcode);
    static const uint8_t s_basetable_fd1089[0x100];
    int unshuffled_key, luta, lut2_a, preval, last_in;
    uint8_t family, xorval;
protected:

    // internal helpers
    uint8_t rearrange_key(uint8_t table, bool opcode);
    virtual uint8_t decode(uint8_t val, uint8_t key, bool opcode) = 0;

    // internal types
    struct decrypt_parameters
    {
        uint8_t xorval;
        uint8_t s7,s6,s5,s4,s3,s2,s1,s0;
    };

    // static tables
    static const decrypt_parameters s_addr_params[16];
    static const decrypt_parameters s_data_params_a[16];
};


// ======================> fd1089a_device

// FD1089A variant
class fd1089a_device : public fd1089_base_device
{
protected:
    virtual uint8_t decode(uint8_t val, uint8_t key, bool opcode) override;
};


// ======================> fd1089b_device

// FD1089B variant
class fd1089b_device : public fd1089_base_device
{
protected:
    virtual uint8_t decode(uint8_t val, uint8_t key, bool opcode) override;
};


#endif // MAME_MACHINE_FD1089_H
