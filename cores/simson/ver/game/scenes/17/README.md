Bug: curtains are big sprites that should cover other sprites underneath,
particularly the white fusuma (Japanese slide doors) should not be visible

The full sprite LUT is not parsed within the line interval. If the writting
overruns the line buffer switch, the fusuma is written on the next line and
will not be overwritten because old sprites take priority in this game

It is hard to make the logic go faster because the pixel draw process requires
two clock cycles, precisely because of the old-sprite priority setting.

There are 8us of margin in simulation since the end of