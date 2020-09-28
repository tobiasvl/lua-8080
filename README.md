lua-8080
========

An Intel 8080 emulator core written in Lua.

Requirements
------------

Either the `bit32` or [BitOp](http://bitop.luajit.org) module for bitwise operators.

Usage
-----

This emulator core is modular, like the early microcomputers. It should be able to emulate most 8080-based computers, but you need to "wire it up" yourself, just like the old days.

See `main.lua` for an example of how to use it in your own programs.

You can also look at these emulators that use this core:

* [Moon Invaders](https://github.com/tobiasvl/moon-invaders) (_Space Invaders_ emulator)
* [ALTAÏR](https://github.com/tobiasvl/altair) (Altair 8800 emulator)

Tests
-----

You can download one of the many [Intel 8080 test suites](https://github.com/superzazu/8080/tree/master/cpu_tests) and run them with the `main.lua` script.

Currently, it passes these tests:

- [x] `8080PRE.COM`: Preliminary test for 8080/8085 CPU Exerciser by Ian Bartholomew and Frank Cringles
- [x] `8080EXER.COM`: 8080/8085 CPU Exerciser by Ian Bartholomew and Frank Cringles
- [x] `TST8080.COM`: 8080/8085 CPU Diagnostic, version 1.0, by Microcosm Associates
- [x] `CPUTEST.COM`: 8080/Z80 CPU Diagnostic II, by SuperSoft Associates
