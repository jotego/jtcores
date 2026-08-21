# External interrupt regression

This wrapper-level test programs `IE` through the 8751 PROM interface, drives
the `INT0` pin, executes the vector at 0003h, and checks both the port result
and stack restoration after `RETI`.

It also models Body Slam's `JB P3.2,$` VINT polling loop.  An INT0 request
arriving after the opcode fetch must wait for that three-byte instruction to
finish; the saved return PC is the instruction following `JB`.

Finally, it raises a low-priority INT0 and a high-priority Timer0 request
together.  Timer0 must receive vector 000Bh first, clear only TF0, and return
before the still-pending INT0 receives vector 0003h.  This covers priority
arbitration, source-specific acknowledgement, and priority-service recovery.
