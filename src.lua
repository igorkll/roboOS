---------------------------------------------gpu

local gpu = component.proxy(component.list("gpu")() or "")
if gpu then
    if gpu.bind(component.list("screen")() or "", true) then
        gpu.setResolution(50, 16)
    else
        gpu = a
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
    local label, docs, strs, docX = "", "", {}

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
            gpu.set(1, ry, str .. " ")
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

    function gui.draw(num, scroll)
        gpu.fill(1, 1, rx, ry, " ")
        gpu.set(1, 1, label)
        gpu.fill(1, 2, rx, 1, "─")
        gpu.fill(1, ry - 1, rx, 1, "─")        
        gpu.fill(docX, 3, 1, ry - 4, "│")
        
        local splitedDoc = split(docs[num] or docs[0] or "", "\n")
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
            local posY = i + 2
            posY = posY - scroll
            if posY >= 3 and posY <= (ry - 2) then
                if i == num then gui.invert() end
                gpu.set(1, posY, data)
                if i == num then gui.invert() end
            end
        end
    end

    function gui.menu(num, scroll)
        gui.draw(num, scroll)
        while 1 do
            local eventData = {computer.pullSignal()}
            if eventData[1] == "key_down" then
                if eventData[4] == 28 then
                    return num, scroll
                elseif eventData[4] == 200 then
                    if num > 1 then
                        num = num - 1
                        if ((num + 2) - scroll) < 3 then
                            scroll = scroll - 1
                        end
                        gui.draw(num, scroll)
                    end
                elseif eventData[4] == 208 then
                    if num < #strs then
                        num = num + 1
                        if ((num + 2) - scroll) > (ry - 2) then
                            scroll = scroll + 1
                        end
                        gui.draw(num, scroll)
                    end
                end
            end
        end
    end

    function gui.setData(label2, docs2, strs2)
        label, docs = label2, type(docs2) == "string" and {[0] = docs2} or docs2
        strs = {}
        for i, v in ipairs(strs2) do
            local str = v:sub(1, docX - 1)
            while #str < (docX - 1) do
                str = str .. " "
            end
            table.insert(strs, str)
        end
    end

    function gui.setText(str, posX, posY)
        gpu.set((posX or 0) + math.floor(((rx / 2) - ((#str - 1) / 2)) + 0.5), posY or math.floor((ry / 2) + 0.5), str)
    end

    function gui.warn(str)
        gpu.fill(8, 4, rx - 15, ry - 4, "▒")
        local logoPos = math.ceil((rx / 2) - (13 / 2))
        gpu.set(logoPos, 5,  "▒▒▒▒▒▒█▒▒▒▒▒▒")
        gpu.set(logoPos, 6,  "▒▒▒▒▒███▒▒▒▒▒")
        gpu.set(logoPos, 7,  "▒▒▒▒██ ██▒▒▒▒")
        gpu.set(logoPos, 8,  "▒▒▒███████▒▒▒")
        gpu.set(logoPos, 9,  "▒▒████ ████▒▒")
        gpu.set(logoPos, 10, "▒█████ █████▒")
        gpu.set(logoPos, 11, "█████████████")
        gui.setText(str, nil, 13)
        gui.setText("Press Enter To Continue", nil, 14)

        computer.beep(100, 0.2)

        while true do
            local eventData = {computer.pullSignal()}
            if eventData[1] == "key_down" and eventData[4] == 28 then
                break
            end
        end
    end

    function gui.yesno(str)
        gui.invert()
        gpu.fill((rx / 2) - 10, (ry / 2) - 1, 20, 5, "▒")
        gui.setText(str, nil, (ry / 2))

        computer.beep(2000, 0.1)

        local selected = false

        while true do
            if selected then gui.invert() end
            gpu.set((rx / 2) - 9, (ry / 2) + 1, "yes")
            if selected then gui.invert() end

            if not selected then gui.invert() end
            gpu.set((rx / 2) + 7, (ry / 2) + 1, "no")
            if not selected then gui.invert() end

            local eventData = {computer.pullSignal()}
            if eventData[1] == "key_down" then
                if eventData[4] == 203 then
                    selected = true
                elseif eventData[4] == 205 then
                    selected = false
                elseif eventData[4] == 28 then
                    gui.invert()
                    return selected
                end
            end
        end
    end
end

---------------------------------------------test

local function usermenager()
    local num, scroll = 1, 0
    local strs = {"add new user", "exit"}
    local removers = {}

    for _, nikname in ipairs({computer.users()}) do
        table.insert(strs, 1, nikname)
        table.insert(removers, 1, function()
            if gui.yesno("remove user?") then
                for i, v in ipairs(strs) do
                    if v == nikname then
                        table.remove(strs, i)
                        table.remove(removers, i)
                        computer.removeUser(nikname)
                        break
                    end
                end
            end
        end)
    end

    while 1 do
        gui.setData("usermenager", {[0] = "user management(useradd/userremove/userlist)"}, strs)
        num, scroll = gui.menu(num, scroll)
        if num == #strs then
            break
        elseif num == (#strs - 1) then
            local nikname = gui.read("nikname")
            if nikname then
                local ok, err = computer.addUser(nikname)
                if not ok then
                    gui.warn(err)
                end
            end
        else
            removers[num]()
        end
    end
end

local function autorunSettings()
    
end

local function bootToExternalOS()
    local num, scroll = 1, 0
    local strs = {"exit"}
    local osList = {}

    for address in component.list("filesystem") do
        local proxy = component.proxy(address)
        local function addFile(file)
            table.insert(strs, 1, (proxy.getLabel() or "noLabel") .. ":" .. address:sub(1, 6) .. ":" .. file)
            table.insert(osList, 1, function()
                bootToOS(address, file)
            end)
        end
        if proxy.exists("/init.lua") then
            addFile("/init.lua")
        end
        for _, file in ipairs(proxy.list("/boot/kernel") or {}) do
            addFile("/boot/kernel/" .. file)
        end
    end

    while 1 do
        gui.setData("boot to external os", {[0] = "boot to an external OS for example openOS"}, strs)
        num, scroll = gui.menu(num, scroll)
        if num == #strs then
            break
        else
            osList[num]()
        end
    end
end

local function settings()
    local num, scroll = 1, 0
    local strs = {"autorun", "usermenager", "exit"}
    local doc = {"set autorun mode and autorun programm", "user management(useradd/userremove/userlist)"}
    while 1 do
        gui.setData("settings", doc, strs)
        num, scroll = gui.menu(num, scroll)
        if num == 1 then
            autorunSettings()
        elseif num == 2 then
            usermenager()
        elseif num == 3 then
            break
        end
    end
end

local num, scroll = 1, 0
local strs = {"shutdown", "reboot", "settings", "boot to external os"}
local doc = {[0] = "main doc:\nnavigation ↑↓\nok - enter", [4] = "boot to an external OS for example openOS"}
while 1 do
    gui.setData("roboOS", doc, strs)
    num, scroll = gui.menu(num, scroll)
    if num == 1 then
        computer.shutdown()
    elseif num == 2 then
        computer.shutdown(1)
    elseif num == 3 then
        settings()
    elseif num == 4 then
        bootToExternalOS()
    end
end