# MCU handshake

Runs a synthetic 68705 program through `jtframe_6805mcu`. It reads and
acknowledges host commands, returns their complement, and keeps PB2 low
while the host consumes the response. Checks that the full flag clears and
does not return until a new response is strobed.

Repeats the exchanges using Tiger-Heli's inverted MCU-side PC0/PC1 status
inputs. Host-side status keeps the same polarity, and the Slap Fight MCU
scroll strobes are disabled for Tiger-Heli.

Run `simunit-all.sh --only jtslap_mcu` after sourcing `setprj.sh`.
