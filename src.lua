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

function toParts(str, max)
    local strs = {}
    local temp = ""
    for i = 1, #str do
        local char = str:sub(i, i)
        temp = temp .. char
        if #temp >= max then
            table.insert(strs, temp)
            temp = ""
        end
    end
    table.insert(strs, temp)
    if #strs[#strs] == 0 then table.remove(strs, #strs) end
    return strs
end

function bootToOS(address, file)
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

---------------------------------------------gui

if gpu then
    gui = {}
    local label, doc, strs, docX = "", "", {}

    local rx, ry = gpu.getResolution()

    function gui.setResolution(x, y)
        gpu.setResolution(x, y)
        rx, ry = x, y
        docX = math.floor((x / 3) * 2)
    end
    gui.setResolution(gpu.getResolution())

    function gui.invert()
        gpu.setBackground(gpu.setForeground(gpu.getBackground()))
    end

    function gui.read(str)
        local buffer = ""
        
        local function redraw()
            local str = str .. ": " .. buffer .. "_"
            while #str > rx do
                str = str:sub(2, #str)
            end
            gpu.set(1, ry, str)
        end
        redraw()

        local function exit()
            gpu.fill(1, ry, rx, 1, " ")
        end

        while 1 do
            local eventData = {computer.pullSignal()}
            if eventData[1] == "key_down" then
                if eventData[4] == 28 then
                    exit()
                    return buffer
                elseif eventData[3] >= 32 and eventData[3] <= 126 then
                    buffer = buffer .. string.char(eventData[3])
                    redraw()
                elseif eventData[4] == 14 then
                    if #buffer > 0 then
                        buffer = buffer:sub(1, #buffer - 1)
                        redraw()
                    end
                elseif eventData[4] == 46 then
                    exit()
                    break --exit ctrl + c
                end
            elseif eventData[1] == "clipboard" then
                buffer = buffer .. eventData[3]
                redraw()
                if buffer:byte(#buffer) == 13 then exit() return buffer end
            end
        end
    end

    function gui.draw()
        gpu.fill(1, 1, rx, ry, " ")
        gpu.set(1, 1, label)
        gpu.fill(1, 2, rx, 1, "─")
        gpu.fill(1, ry - 1, rx, 1, "─")        
        gpu.fill(docX, 3, 1, ry - 2, "│")
        
        local splitedDoc = split(doc, "\n")
        local tbl = {}
        for i, v in ipairs(splitedDoc) do
            local tempTbl = toParts(v, rx - docX)
            for i, v in ipairs(tempTbl) do
                table.insert(tbl, v)
            end
        end

        for i, data in ipairs(tbl) do
            gpu.set(docX + 1, i + 2, data)
        end
        for i, data in ipairs(strs) do
            gpu.set(1, i + 2, data)
        end
    end

    function gui.setStrColor(num, invert)
        if invert then gui.invert() end
        gpu.set(1, num + 2, strs[num])
        if invert then gui.invert() end
    end

    function gui.menu(num)
        gui.setStrColor(num, 1)
        while 1 do
            local eventData = {computer.pullSignal()}
            if eventData[1] == "key_down" then
                if eventData[4] == 28 then
                    gui.setStrColor(num)
                    return num
                elseif eventData[4] == 200 then
                    gui.setStrColor(num)
                    if num > 1 then num = num - 1 end
                    gui.setStrColor(num, 1)
                elseif eventData[4] == 208 then
                    gui.setStrColor(num)
                    if num < #strs then num = num + 1 end
                    gui.setStrColor(num, 1)
                end
            end
        end
    end

    function gui.setData(label2, doc2, strs2)
        label, doc = label2, doc2
        strs = {}
        for i, v in ipairs(strs2) do
            local str = v:sub(1, docX - 1)
            while #str < (docX - 1) do
                str = str .. " "
            end
            table.insert(strs, str)
        end
    end
end

---------------------------------------------test

local num = 1
local strs = {"input"}
while 1 do
    gui.setData("test menu", "doc test1\ndoc text2\ndoc text3\n1234567890abcdefghi1234567890abcdefghi1234567890abcdefghi", strs)
    gui.draw()
    num = gui.menu(num)
    if num == 1 then
        local data = gui.read("input")
        if data then
            table.insert(strs, data)
        end
    else
        computer.beep()
    end
end