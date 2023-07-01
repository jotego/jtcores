# Credits Screen

Credits can be displayed using the module *JTFRAME_CREDITS*. This module needs the following files inside the patrons folder:

Input File | Output File    | Tool      | Function
-----------|----------------|-----------|--------------------------------------------
 msg       | msg.hex        | msg2hex   | text shown
 avatars   | avatar.hex     | avatar.py | avatar images. 4bpp indexed
 avatars   | avatar_pal.hex | avatar.py | avatar paletters
 lut       | lut.hex        | lut2hex   | avatar tiles location in 8-pixel multiples

**avatars** contains a line with the path from $JTROOT or $JTROOT/cores (if cores exists) to the PNG image.
There should be one line per image.

**lut** contains the object look-up table. Each line has four fields:

1. Tile code
2. x position
3. y position
4. Palette

* Line starting with # character are treated as comments
* A line can start with the scape code **\6,** which means that the following
  four fields should be expanded to a full 2x3 sprite, adjusting tile code
  and positions accordingly
* Another scape code is **\9,** and will expand to a full 3x3 sprite
* The table end is marked by an object with ID 255

avatar.py needs a .png image that complies with:

1. x-y sizes are multiples of 8
2. Maximum 16 colours in the image
3. Alpha channel present in the PNG
4. Image format is RGB (not indexed)

Once the three files msg, avatars and lut are available, jtcore will process them as part of the compilation.

## JTFRAME_CREDITS

Features 1-bpp text font and 4-bpp objects. Enable it with macro **JTFRAME_CREDITS**. By default there are three pages of memory reserved for this. If a different number is needed define the macro **JTFRAME_CREDITS_PAGES** with the right value. Avatars are enabled with **JTFRAME_AVATARS**

**JTFRAME_CREDITS** is also added by the script *jtcore* if the file patrons/msg exists.

If the same core plays horizontal and vertical games, jtframe_credits will rotate the credits. The credits text file must be designed to fit both scenarios. If the vertical case is not as important, the credits can set to always show in horizontal using **JTFRAME_CREDITS_NOROTATE** or to not show for vertical games **JTFRAME_CREDITS_HIDEVERT**.

## msg2hex
Converts from a text file (patrons/msg) to a hex file usable by *JTFRAME_CREDITS*.
Type text for ASCII conversion. Escape characters can be introduced by \ with the following meaning:

Escape              |  Meaning
--------------------|------------------------------
R                   | RED   palette (index 0)
G                   | GREEN palette (index 1)
B                   | BLUE  palette (index 2)
W                   | WHITE palette (index 3)