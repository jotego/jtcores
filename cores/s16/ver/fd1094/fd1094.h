// This code has ben adapted from MAME

#ifndef MAME_MACHINE_FD1094_H
#define MAME_MACHINE_FD1094_H

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

void fd1094_init();
uint16_t decrypt_one(offs_t address, uint16_t val, const uint8_t *main_key,
                     uint8_t state, bool vector_fetch);

#endif // MAME_MACHINE_FD1094_H
