local bit = bit or require('bit32')

local bus = setmetatable({
    memory_map = {},
    breakpoint = {
        address = nil,
        read = false,
        write = false
    },
    connect = function(self, startAddress, module)
        self.memory_map[{
            startAddress,
            module.size
        }] = module
    end
}, {
    __index = function(self, address)
        address = bit.band(address, 0xFFFF)
        if address == self.breakpoint.address and self.breakpoint.read then
            self.cpu.pause = true
        end
        for addresses, module in pairs(self.memory_map) do
            if address >= addresses[1] and address < addresses[1] + addresses[2] then
                return module[address - addresses[1]]
            end
        end
        print("Attempted read at unmapped address " .. string.format("%04X", address))
        return 0
    end,
    __newindex = function(self, address, newValue)
        if address == self.breakpoint.address and self.breakpoint.write then
            self.cpu.pause = true
        end
        for addresses, module in pairs(self.memory_map) do
            if address >= addresses[1] and address < addresses[1] + addresses[2] then
                module[address - addresses[1]] = newValue
                return
            end
        end
        print("Attempted write at unmapped address " .. string.format("%04X", address) .. " with value " .. newValue)
    end,
    __len = function(self) return self.eprom.startAddress + self.eprom.size end -- LuaJIT doesn't support this? :(
})

return bus