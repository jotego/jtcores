# K5293 graphics mask regression

This test drives the real K5293 priority chip and its registered tile/object
priority inputs. It compares an unmasked reference instance with the game-side
visibility gates over every 6-bit priority pattern, tile opacity pair, object
color, and tile/object visibility mask. It checks bit-exact all-enabled
behavior and checks that a forced priority winner cannot leak RGB when its
layer is disabled.
