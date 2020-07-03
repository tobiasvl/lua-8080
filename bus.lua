local bit = bit or require('bit32')

local bus = setmetatable({
    memory_map = {},
    --breakpoint = {
    --    address = nil,
    --    read = false,
    --    write = false
    --},
    connect = function(self, startAddress, module)
        local tbl = { startAddress = startAddress, module = module }
        for i = startAddress, startAddress + module.size do
            self.memory_map[i] = tbl
        end
    end
}, {
    __index = function(self, address)
        address = bit.band(address, 0xFFFF)
        --if address == self.breakpoint.address and self.breakpoint.read then
        --    self.cpu.pause = true
        --end
        local tbl = self.memory_map[address]
        if tbl then
            return tbl.module[address - tbl.startAddress]
        end
        print("Attempted read at unmapped address " .. string.format("%04X", address))
        return 0
    end,
    __newindex = function(self, address, newValue)
        --if address == self.breakpoint.address and self.breakpoint.write then
        --    self.cpu.pause = true
        --end
        local tbl = self.memory_map[address]
        if tbl then
            tbl.module[address - tbl.startAddress] = newValue
            return
        end
        print("Attempted write at unmapped address " .. string.format("%04X", address) .. " with value " .. newValue)
    end
})

return bus
