/* Configuration file should be placed in the core's firmware directory.
   Each core will have different requirements of the firmware, and by avoiding
   the parts not needed the ROM size can be kept to a minimum */

#ifndef CONFIG_H
#define CONFIG_H

/* Do we need access to the SD card filesystem? (Defined in the negative
   so that filesystem support is built by default) */

#undef CONFIG_WITHOUT_FILESYSTEM

/* PS/2 Mouse support */
#undef PS2_MOUSE
#undef PS2_MOUSE_WHEEL /* Attempt to initialise the mouse in 4-byte (wheel) mode */
#undef PS2_MOUSE_USERIO /* Do we need to send the mouse data to the core (not needed if the core can interpret PS/2 wires directly. */
#undef PS2_WRITE /* Needed to initialise the mouse and put it in wheel mode */

/* CDROM support - used by the TurboGrafx core */
#undef CONFIG_CD

/* Disk Image support - used for Save RAM on consoles as well as the
more obvious application of disk images on computer cores.  If not defined
here, the number of units defaults to 4. */
#undef CONFIG_DISKIMG
#undef CONFIG_DISKIMG_UNITS 2

/* IDE emulation */
#undef CONFIG_IDE
#undef CONFIG_IDE_UNITS 2

/* Speed up file operations by "bookmarking" the file.
   (Undef to disable, or set to the number of desired bookmarks - a reasonable
   range would be between 4 and 16 */
#undef CONFIG_FILEBOOKMARKS 6

/* If the core has initialised the keyboard to use scan set 1 the OSD will
   need to use set 1 as well. */
#undef CONFIG_KEYBOARD_SET1

/* Keyboard-based Joystick emulation */
#undef CONFIG_JOYKEYS

/* Send key events via the mist_io block. If the core can support
   a PS/2 keyboard directly then that's probably a better option. */
#define CONFIG_SENDKEYS

/* Send joystick events using the "new" extended joystick protocol.
   This could support more buttons (if DeMiSTify itself supported them,
   which it currently doesn't) - but some cores still use the older protocol. */
#define CONFIG_EXTJOYSTICK

/* Do we require an autoboot ROM, and thus should we notify the user if it's not found? */
#undef ROM_REQUIRED

/* ROM name will default to "BOOT    ROM" if not defined here... */ 
#undef ROM_FILENAME "CORE    ROM"

/* Do we support settings files */

#undef CONFIG_SETTINGS_FILENAME "CORE    CFG"
#undef CONFIG_SETTINGS

/* Do we support the Real Time Clock (if available)? */
#undef CONFIG_RTC

/* Support for 64-bit status word.  Adds around 200 bytes to the firmware size. */
#undef CONFIG_STATUSWORD_64BIT

/* Automatically close OSD on toggle menu items (generally reset) */
#undef CONFIG_AUTOCLOSE_OSD

/* Is this an arcade core with .ARC file support? */
#define CONFIG_ARCFILE
/* If the core doesn't have its own ROM loading menu item, use this to add a selector for .ARC files. */
#undef CONFIG_ARCFILE_SELECTOR


/* If this is defined, DeMiSTify will look for a file called "15KHZ.CFG", and if found,
disable the scandoubler. */
#define CONFIG_AUTOSCANDOUBLER

#endif

