# Capture SPI and synchronous RAM integration test

This simunit connects the real `user_io`, capture controller, and dual-clock
pixel RAM, then drives the physical SPI pins. It checks coherent INFO bytes,
empty reads, ordered rows from both banks, a 24 MHz SCK against the 48 MHz
system clock with independent phase, partial-CS retry without consuming a row,
full payload bytes, final-bit consumption, and ABORT. It also stops SCK after
BEGIN while rows publish to verify the mailbox does not discard data when its
clock resumes.
