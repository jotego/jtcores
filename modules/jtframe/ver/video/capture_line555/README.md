# RGB555 scanline encoder test

Checks exact 15-bit literals and repeats, including opposite channel LSBs,
the length-two raw tie, long repeat encoding, 1024-byte raw fallback, and both
physical BRAM banks. Decoding checks every source pixel against an independent
RGB555 oracle.
