---------------------------------------------gpu

local gpu = component.proxy(component.list("gpu")() or "")
if gpu.bind(component.list("screen")() or "", true) then
    gpu.setResolution(50, 16)
else
    gpu = nil
end

---------------------------------------------graphic

do
    local px, py = 1, 1

    local term = {}
    function term.write(str)
        local strs = {}

    end
    function term.setCursor(x, y)
        px, py = x, y
    end
    function term.getCursor(x, y)
        return px, py
    end
    function print(...)
        for _, v in ipairs{...} do
            
        end
    end
end

---------------------------------------------eeprom

local eeprom = component.proxy(component.list("eeprom")())

function split(str, sep)
    local parts, count, i = {}, 1, 1
    while 1 do
        if i > #str then break end
        local char = str:sub(i, #sep + (i - 1))
        if not parts[count] then parts[count] = "" end
        if char == sep then
            count = count + 1
            i = i + #sep
        else
            parts[count] = parts[count] .. str:sub(i, i)
            i = i + 1
        end
    end
    if str:sub(#str - (#sep - 1), #str) == sep then table.insert(parts, "") end
    return parts
end

function getDataPart(part)
    return split(eeprom.getData(), "\n")[part] or ""
end

function setDataPart(part, newdata)
    if getDataPart(part) == newdata then return end
    if newdata:find("\n") then error("\\n char") end
    local parts = split(eeprom.getData(), "\n")
    for i = part, 1, -1 do
        if not parts[i] then parts[i] = "" end
    end
    parts[part] = newdata
    eeprom.setData(table.concat(parts, "\n"))
end

---------------------------------------------functions

local function bootToOS(address, file)
    function computer.getBootAddress()
        return address
    end
    function computer.getBootGpu()
        return gpu and gpu.address
    end
    function computer.getBootScreen()
        return gpu and gpu.getScreen()
    end
    function computer.getBootFile()
        return file
    end

    function computer.setBootAddress()
    end
    function computer.setBootScreen()
    end
    function computer.setBootFile()
    end

    local fs = component.proxy(address)
    local file = assert(fs.open(file, "rb"))

    local buffer = ""
    while 1 do
        local data = fs.read(file, math.huge)
        if not data then break end
        buffer = buffer .. data
    end
    fs.close(file)

    assert(load(buffer, "=init"))()
    computer.shutdown()
end

---------------------------------------------

if gpu then
    gui = {}
    gui.label = ""
    gui.doc = ""

    function gui.invert()
        gpu.setBackground(gpu.setForeground(gpu.getBackground()))
    end

    function gui.draw()
        local rx, ry = gpu.getResolution()
        gpu.fill(1, 1, rx, ry, " ")
        gpu.set(1, 1, gui.label)
        gpu.fill(1, 2, rx, 1, "─")
        gpu.fill(1, ry - 1, rx, 1, "─")
        gpu.fill(math.floor((rx / 3) * 2), 3, 1, ry - 2, "│")
    end
end