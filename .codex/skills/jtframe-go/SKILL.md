---
name: edit jtframe or jtutil commands
description: Modify Go programming to introduce new behavior or modify the existing one in the jtframe and jtutil commands
---

# Source Files

The source files are in $JTFRAME/src/jtframe for the jtframe utility and
$JTFRAME/src/jtutil for jtutil.

# Coding Style

- Avoid blank lines within function bodies
- Use snake_names for private functions and variables
- Define functions in the order in which they are called in the file, so the
call always comes before the definition
- Try to reuse the existing functions and framework
- Create objects to solve complex functions and use internal member properties
instead of passing data across function calls where possible

When checking for errors in Go, follow this structure:

```Go
// function_call returns an error type
e := function_call(); if e!=nil { return e }
```

Where everything is in the same line for readability.

If it makes sense to add context to the error, do it like this

```Go
// function_call returns an error type
e := function_call(); if e!=nil { return fmt.Errorf("While doing xxx: %w",e) }
```

Only if the context makes the line too long (longer than 80 characters), move
the `if` statement to its own line and follow regular Go formatting
