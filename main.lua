-- Test program

if not arg[1] then
    print("Intel 8080 emulator written in Lua. Supports LuaJIT.")
    print("Copyright (c) 2020 Tobias V. Langhoff, MIT license")
    print()
    print("Usage:")
    print("lua main.lua testprogram [debug]")
    print()
    print("  testprogram: A binary CP/M program to run. Examples: TEST.COM, CPUTEST.COM, 8080")
    print("  debug:       Prints CPU status before each instruction.")
    os.exit()
end

local bit = bit or require "bit32"
local cpu = require "cpu"
local bus = require "bus"
local ram = require "ram"

local profi
if arg[2] == "profile" or arg[3] == "profile" then
    profi = require "profi"
    profi:start()
end

local cycles = 0

-- Allocate 0xFFFF bytes of RAM
local wram = ram(0x10000, 0)
bus:connect(0, wram)

-- Load test "ROM" into RAM
local file = io.open(arg[1], "r")
local rom = {}
local address = 0
repeat
    local b = file:read(1)
    if b then
        bus[0x100 + address] = b:byte()
    end
    address = address + 1
until not b
file:close()

local debug_file, disassembler
if arg[2] == "debug" or arg[3] == "debug" then
    disassembler = require "disassembler"
    disassembler:disassemble(bus)
    debug_file = io.open("debug.log", "w")
end

-- CP/M API functions:
-- When 0x0005 is called, print a string to serial output (the terminal).
function cpm_print()
    if cpu.registers.c == 9 then
        -- Print the $-terminated string at the memory location in DE
        local address = cpu.registers.de
        local char = string.char(bus[address])
        while char ~= "$" do
            io.write(char)
            address = address + 1
            char = string.char(bus[address])
        end
    elseif cpu.registers.c == 2 or cpu.registers.c == 5 then
        -- Print the single character in E
        io.write(string.char(cpu.registers.e))
    end

    return 0xFF
end

-- inject "out 1,a" at 0x0000 (signal to stop the test)
bus[0x0000] = 0xD3;
bus[0x0001] = 0x01;

-- inject "in a,0" at 0x0005 (signal to output some characters)
bus[0x0005] = 0xDB;
bus[0x0006] = 0x00;
bus[0x0007] = 0xC9;

cpu:init(bus)
cpu.registers.pc = 0x100

function cpm_exit()
    if debug_file then debug_file:close() end
    if profi then
        profi:stop()
        profi:writeReport('report.log')
    end
    os.exit()
end

cpu.ports.internal.output[1] = cpm_exit
cpu.ports.internal.input[0] = cpm_print

while true do
    if debug_file then
        -- Print debug output to terminal. Format inspired by superzazu's emulator,
        -- for easy diffing. https://github.com/superzazu/8080
        debug_file:write(
            string.format("PC: %04X, AF: %04X, BC: %04X, DE: %04X, HL: %04X, SP: %04X, CYC: %-6d (%02X %02X %02X %02X) - %s\n",
                cpu.registers.pc,
                cpu.registers.psw,
                cpu.registers.bc,
                cpu.registers.de,
                cpu.registers.hl,
                cpu.registers.sp,
                cycles,
                bus[cpu.registers.pc],
                bus[cpu.registers.pc+1],
                bus[cpu.registers.pc+2],
                bus[cpu.registers.pc+3],
                disassembler.memory[cpu.registers.pc]
            )
        )
    end

    cycles = cycles + cpu:cycle()
end
