# Configuration String

MiST derived FPGA platforms, including MiSTer, send core configuration from the FPGA to the microcontroller through a string called *configuration string*. This string is stored in a text template called `cfgstr` in each target folder. For instance, `$JTFRAME/mister/cfgstr` contains MiSTer's config string. The `jtframe cfgstr` command will parse this text template and integrate it into the core build.

`jtframe cfgstr` is also the generic tool for macro parsing and converts core macro definitions to *bash*, *Quartus TCL* and *C++* formats to be used in other tools.

# Macro Definition

Macros are expected in the file *cores/corename/cfg/macros.def*. From there, other files can be included. The *macros.def* file accepts target-specific macros. Check for examples in JT cores, such as [kicker](https://github.com/jotego/jtkicker).

Macros can also be defined when invoking *jtcore* or *jtframe* command-line tools. Macros are available for verilog files and also verilator C++ files. For C++, the macro name is added an initial underscore, so `ABC` becomes `_ABC`

Macros in *macros.def* can have different values for a given target platform, using the following syntax:

```
# defines FOO as 4
FOO=4
[sidi]
# but in the sidi platform, it will become 6
FOO=6
[mist*]
# and in mist/mister platforms, it will be 7
FOO=7
[*]
# matches all targets
```

The glob matching pattern (using * and ? as in the command line) is supported for target platform name comparisons.

Macro files can include other macro files with `include <path-to-def-file>`. Note that the path is relative to the current .def file being parsed.

Macro declarations starting with `debug` are not parsed for release compilations:

```
[*]
debug SHOWINFO
ABC
```

Will ignore SHOWINFO when JTFRAME_RELEASE is defined. ABC will always be defined.

Macros can be removed by preceding them with a minus sign:

```
ABC
[mist]
-ABC
```

Will remove the ABC macro for the MiST target.

There is a simple macro concatenation possible by using `+=` instead of `=` for macro definition. This will simply concatenate new text after the previously defined content:

```
TEXT=abc
TEXT+=def
```

Will produce a `TEXT` macro whose content is `abcdef`.

The same technique will work with integers, which can be expressed in decimal, octal (0), hexadecimal (0x) or binary (0b):

```
NUMBER=0b1001
NUMBER+=0b0110
```

Will produce a `NUMBER` macro with a value of 15 (i.e. 0b1111)

Note that the syntax does not go any further. `ADD=2+3` will be parsed as a string, not as the value 5. The only way to perform a macro based operation is the `+=` assignment operator.

# System Name

There are two macros that define the core name the FPGA will use when communicating with the rest of the target platform. This is the name that MiST(er) display in the side of the OSD menu under some circumstances. It is also the name used for compilation files and the RBF file name. If undefined, the core folder name will be used. CORENAME is a way of using a different name for the core folder and the core itself.

The core's game module that connects to the target top module is set by GAMETOP. If undefined, it will default to $CORENAME_game (or $CORENAME_game_sdram when cfg/mem.yaml exists). $CORENAME is used in lower case for the GAMETOP.

A macro for the core folder name in capitals is always defined and can be used in `ifdef` statements when a file is common to several cores.

Macro         |  Usage                  | Default Value
--------------|-------------------------|------------------
CORENAME      | Core name               | Core's folder name
GAMETOP       | Core's game module name | $CORENAME_game(_sdram)

# JTFRAME Macros

The macros that configure a core or the overall JTFRAME framework are listed in [macros.md]. Type `jtmacros` in the terminal to display them.

