# Bionic Commando P3.6 regression

The Bionic Commando 8751 uses P3.6 as a sound-write strobe after loading P1.
This is distinct from MOVX external-memory writes. The real Biocom wrapper is
instantiated and the test asserts that this port pulse never asserts the
shared main-RAM write enable.
