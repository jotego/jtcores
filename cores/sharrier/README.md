# JTSHARRIER

You can show your appreciation through
* Patreon: https://patreon.com/jotego
* Paypal: https://paypal.me/topapate
* Github: https://github.com/sponsors/jotego

This core runs **Space Harrier** on SEGA's Hang-On hardware.

Hang-On and Enduro Racer are the same board but are **not supported**: Hang-On's
sprite ROMs do not group into 32-bit words, so its sprite format is not
implemented, and Enduro Racer needs the FD1089 decryption and a YM2151 that are
not wired here. Both are skipped by the MRA generator until the HDL can run them.

Super Hang-On conversions run on this hardware too but are covered by the
JTOUTRUN core, so they are not supported here either.

# Licensing

Contact the author for special licensing needs. Otherwise follow the GPLv3
license attached.
