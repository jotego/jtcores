# Horizontal retimer regression

Sweeps all 16 scale encodings, bypass, enable changes and scale changes. Each active line must contain all 512 source pixels in order, with the expected duration and horizontal centre. FIFO checks catch overwriting unread data and reads beyond the writer.

The regular profiles cover eight-, twelve- and sixteen-clock pixels. The interlaced profiles switch from native pixels to alternating 8/10-clock pixels (96 MHz video clock) or 4/5-clock pixels (48 MHz), sweep the alternate period, then return to the native rate. The synthetic horizontal porches leave enough room for the largest stretch so the full pixel sequence can be checked.

Run with `source setprj.sh` followed by `simunit.sh --run modules/jtframe/ver/video/hretime`.
