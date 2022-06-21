
---------------------------------------------package

local computer = computer
local component = component
local unicode = unicode

_G.component = nil
_G.computer = nil
_G.unicode = nil

do
    local package = {loaded = {}, path = false}
    package.loaded.package = package

    package.loaded.component = setmetatable(component, {__index = function(_, name)
        return component.proxy(component.list(name)() or "")
    end})
    package.loaded.computer = computer
    package.loaded.component = component

    function require(libname)
        return package.loaded[libname]
    end
end

---------------------------------------------gpu

local gpu = component.proxy(component.list("gpu")() or "")
gpu.bind(component.list("screen")() or "", true)

---------------------------------------------graphic

do
    local term = {}
    function term.write(str)
        
    end
    function print(...)
        for _, v in ipairs{...} do
            
        end
    end    
end

---------------------------------------------

local function setLabel()
    
end