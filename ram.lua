return function(length, initial_value)
    local self = {
        size = length,
        --memory = {},
        --initialized = setmetatable({}, {
        --    __index = function() return false end
        --}),
        --set_uninitialized_value = function(self, initial_value)
        --    self.uninitialized_random = not initial_value
        --    for i = 0, length - 1 do
        --        if not self.initialized[i] then
        --            self.memory[i] = initial_value or math.random(0, 255)
        --        end
        --    end
        --end
    }
    --self:set_uninitialized_value(initial_value)
    for i = 0, length - 1 do
        self[i] = 0
    end
    --return setmetatable(self, {
    --    __index = self.memory,
    --    __newindex = function(self, address, value)
    --        self.memory[address] = value
    --        drawflag = true
    --        --self.initialized[address] = true
    --    end
    --})
    return self
end
