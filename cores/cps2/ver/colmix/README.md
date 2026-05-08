# CPS2 Color Mixer Regression

This test checks the CPS2 sprite-vs-scroll priority rule used in the SFA2 high-score bug:

- transparent scroll pixels still block priority-0 sprites
- higher-priority sprites remain visible over transparent pixels
- equal-priority sprites stay behind non-transparent scroll pixels
- higher-priority sprites appear over those scroll pixels
