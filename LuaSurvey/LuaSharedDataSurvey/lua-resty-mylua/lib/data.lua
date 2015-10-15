-- mydata.lua
local _M = {}

local data = {
    dog = 3,
    cat = 4,
    pig = 5,
}

function _M.get_age(name)
    return data[name]
end

function _M.set_age(name, age)
    if data[name] ~= nil then
	data[name] = age
    else 
        return false, "pet " .. name .. " is not exist"
    end	
end

return _M
