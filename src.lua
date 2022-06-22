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

function getFile(fs, file)
    local file = assert(fs.open(file, "rb"))

    local buffer = ""
    while 1 do
        local data = fs.read(file, math.huge)
        if not data then break end
        buffer = buffer .. data
    end
    fs.close(file)

    return buffer
end

function saveFile(fs, file, data)
    local file = assert(fs.open(file, "wb"))
    fs.write(file, data)
    fs.close(file)
end

function bootToOS(fs, file)
    function computer.getBootAddress()
        return fs.address
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

    assert(load(getFile(fs, file), "=init"))()
    computer.shutdown()
end

function fs_path(path)
    local splited = split(path, "/")
    if splited[#splited] == "" then splited[#splited] = a end
    return table.concat({table.unpack(splited, 1, #splited - 1)}, "/")
end

---------------------------------------------gui

if gpu then
    gui = {}
    local rx, ry = gpu.getResolution()
    local label, docs, strs, docX = "", "", {}, math.floor((rx / 3) * 2)

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
        gpu.fill(docX + 1, ry // 2, rx - docX, 1, "─")
        
        local function printDoc(doc, posY)
            local splitedDoc = split(doc or "not found", "\n")
            local tbl = {}
            for i, v in ipairs(splitedDoc) do
                local tempTbl = toParts(v, rx - docX)
                for i, v in ipairs(tempTbl) do
                    table.insert(tbl, v)
                end
            end
            for i, data in ipairs(tbl) do
                gpu.set(docX + 1, (i + posY) - 1, data)
            end
        end
        gpu.set(docX + 1, 3, "menu doc:")
        printDoc(docs[0], 4)
        gpu.set(docX + 1, (ry // 2) + 1, "menu point doc:")
        printDoc(docs[num], (ry // 2) + 2)
        
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
        gpu.set((posX or 0) + math.floor(((rx / 2) - ((unicode.len(str) - 1) / 2)) + 0.5), posY or math.floor((ry / 2) + 0.5), str)
    end

    function gui.warn(str)
        gpu.fill(8, 3, rx - 15, ry - 4, "▒")
        gui.setText("▒▒▒▒▒▒█▒▒▒▒▒▒", a, 4)
        gui.setText("▒▒▒▒▒███▒▒▒▒▒", a, 5)
        gui.setText("▒▒▒▒██ ██▒▒▒▒", a, 6)
        gui.setText("▒▒▒███████▒▒▒", a, 7)
        gui.setText("▒▒████ ████▒▒", a, 8)
        gui.setText("▒█████ █████▒", a, 9)
        gui.setText("█████████████", a, 10)
        gui.setText(str, a, 12)
        gui.setText("Press Enter To Continue", a, 13)

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
        gui.setText(str, a, (ry / 2))

        computer.beep(2000, 0.1)

        local selected = a

        while true do
            if selected then gui.invert() end
            gui.setText("yes", -5, (ry / 2) + 2)
            if selected then gui.invert() end

            if not selected then gui.invert() end
            gui.setText("no", 5, (ry / 2) + 2)
            if not selected then gui.invert() end

            local eventData = {computer.pullSignal()}
            if eventData[1] == "key_down" then
                if eventData[4] == 203 then
                    selected = true
                elseif eventData[4] == 205 then
                    selected = a
                elseif eventData[4] == 28 then
                    gui.invert()
                    return selected
                end
            end
        end
    end
end

---------------------------------------------main

local setTheme
if gui then
    local currentTheme = getDataPart(1) == "1"
    if currentTheme then
        gui.invert()
    end
    function setTheme(new)
        if new ~= currentTheme then
            gui.invert()
            setDataPart(1, new and "1" or "")
            currentTheme = new
        end
    end
end

local function themes()
    local num, scroll = 1, 0
    local strs = {"white", "black", "exit"}
    local doc = {[0] = "theme selector", "white theme", "black theme"}
    while 1 do
        gui.setData("settings", doc, strs)
        num, scroll = gui.menu(num, scroll)
        if num == 1 then
            setTheme(1)
        elseif num == 2 then
            setTheme()
        elseif num == 3 then
            break
        end
    end
end

local function usermenager()
    local num, scroll = 1, 0

    while 1 do
        local strs = {"add new user", "exit"}
        local removers = {}
        local docs = {[0] = "user management(useradd/userremove/userlist)", "press enter to add new user"}
    
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
            table.insert(docs, 1, "press enter to remove this user")
        end

        gui.setData("usermenager", docs, strs)
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
    while 1 do
        local strs = {"exit"}
        local osList = {}
        local docs = {[0] = "boot to:\nopenOS\nplan9k\nother..."}

        for address in component.list"filesystem" do
            local proxy = component.proxy(address)
            local function addFile(file)
                table.insert(strs, 1, (proxy.getLabel() or "noLabel") .. ":" .. address:sub(1, 6) .. ":" .. file)
                table.insert(osList, 1, function()
                    local ok, exists = pcall(proxy.exists, file)
                    if ok and exists then
                        bootToOS(proxy, file)
                    else
                        gui.warn"Operation System Is Not Found"
                        return true
                    end
                end)
                table.insert(docs, 1, "label: " .. (proxy.getLabel() or "noLabel") .. "\naddress: " .. address:sub(1, 6) .. "\nfile: " .. file)
            end
            if proxy.exists"/init.lua" then
                addFile"/init.lua"
            end
            for _, file in ipairs(proxy.list"/boot/kernel" or {}) do
                addFile("/boot/kernel/" .. file)
            end
        end

        while 1 do
            gui.setData("boot to external os", docs, strs)
            num, scroll = gui.menu(num, scroll)
            if num == #strs then
                return
            else
                if osList[num]() then break end
            end
        end
    end
end

local function settings()
    local num, scroll = 1, 0
    local strs = {"autorun", "usermenager", "theme", "exit"}
    local doc = {"set autorun mode and autorun programm", "user management(useradd/userremove/userlist)", "theme selector"}
    while 1 do
        gui.setData("settings", doc, strs)
        num, scroll = gui.menu(num, scroll)
        if num == 1 then
            autorunSettings()
        elseif num == 2 then
            usermenager()
        elseif num == 3 then
            themes()
        elseif num == 4 then
            break
        end
    end
end

local function runProgramm(fs, file)
    local ok, data = pcall(getFile, fs, file)
    if not ok or not data then
        local msg = "err to get programm"
        --local msg = "err to get programm: " .. (data or "unknown")
        if gui then gui.warn(msg) end
        return a, msg
    end
    local code, err = load(data, "=programm")
    if not code then
        if gui then gui.warn("err to load programm: " .. err) end
        return a, err
    end
    local ok, err = pcall(code, {file = file, fs = fs})
    if not ok then
        if gui then gui.warn("err to run programm: " .. (err or "unknown")) end
        return a, (err or "unknown")
    end
    return true
end

if gui then
    while 1 do
        local num, scroll = 1, 0

        local strs = {"refresh", "shutdown", "reboot", "settings", "boot to external os"}
        local doc = {[0] = "navigation ↑↓\nok - enter", [5] = "boot to:\nopenOS\nplan9k\nother..."}
        local runs = {}
        for address in component.list"filesystem" do
            local proxy = component.proxy(address)
            local programsPath = "/roboOS/programs/"
            for _, file in ipairs(proxy.list(programsPath) or {}) do
                local full_path = programsPath .. file
                if proxy.isDirectory(full_path) and proxy.exists(full_path .. "main.lua") then
                    local programmName = file:sub(1, #file - 1)
                    table.insert(strs, programmName)
                    local index = #strs
                    doc[index] = "address: " .. address:sub(1, 6) .. "\nlabel: " .. (proxy.getLabel() or "noLabel") .. "\n"
                    if proxy.exists(full_path .. "doc.txt") then
                        doc[index] = doc[index] .. getFile(proxy, full_path .. "doc.txt")
                    end
                    runs[index] = function()
                        local function check()
                            local ok, exists = pcall(proxy.exists, full_path .. "main.lua")
                            if not ok or not exists then
                                gui.warn("programm is not found")
                                return 1
                            end
                        end
                        if check() then return 1 end

                        local function copy(clone)
                            local strs = {}
                            local addresses = {}
                            for address in component.list"filesystem" do
                                local proxy = component.proxy(address)
                                if not proxy.isReadOnly() then
                                    table.insert(strs, (proxy.getLabel() or "noLabel") .. ":" .. address:sub(1, 6))
                                    table.insert(addresses, address)
                                end
                            end
                            table.insert(strs, "exit")

                            gui.setData("select target to " .. (clone and "move " or "copy ") .. programmName, {}, strs)
                            local num, scroll = gui.menu(1, 0)
                            if not addresses[num] then
                                return 1
                            end

                            local name = programmName
                            if gui.yesno("use new name?") then
                                gui.draw(num, scroll)
                                local newname = gui.read("new name")
                                if newname then
                                    name = newname
                                elseif name:find("%/") or name:find("%\\") then
                                    gui.warn("unsupported char /")
                                    return 1
                                else
                                    gui.warn("using new name canceled")
                                    gui.draw(num, scroll)
                                end
                            end

                            if not gui.yesno(clone and "move?" or "copy?") then
                                return 1
                            end
                            local targetProxy = component.proxy(addresses[num])
                            
                            local function recurse(path, toPath)
                                for _, file in ipairs(proxy.list(path)) do
                                    local local_full_path = path .. file
                                    local rePath = toPath .. "/" .. file
                                    if proxy.isDirectory(local_full_path) then
                                        recurse(local_full_path, rePath)
                                    else
                                        --gui.warn("dir: " .. fs_path(rePath))
                                        --gui.warn("old: " .. local_full_path)
                                        --gui.warn("new: " .. rePath)
                                        targetProxy.makeDirectory(fs_path(rePath))
                                        saveFile(targetProxy, rePath, getFile(proxy, local_full_path))
                                    end
                                end
                            end
                            if targetProxy.exists("/roboOS/programs/" .. name) then
                                gui.warn("this name used")
                                return 1
                            end
                            recurse(full_path, "/roboOS/programs/" .. name)
                        end

                        local num, scroll, refresh = 1, 0
                        while 1 do
                            gui.setData("programm " .. programmName, {[0] = doc[index]}, {"open", "set to autorun", "move", "copy", "remove", "rename", "back"})
                            num, scroll = gui.menu(num, scroll)
                            if check() then return 1 end
                            local old_full_path = full_path
                            local setAutorun = proxy.exists("/roboOS/autorun.cfg") and getFile(proxy, "/roboOS/autorun.cfg") == (old_full_path .. "main.lua")
                            if num == 1 then
                                if not runProgramm(proxy, full_path .. "main.lua") then
                                    return 1
                                end
                            elseif num == 2 then
                                saveFile(proxy, "/roboOS/autorun.cfg", full_path .. "main.lua")
                            elseif num == 3 then
                                --move
                                if not copy(1) then
                                    proxy.remove(full_path)
                                    if setAutorun then
                                        proxy.remove("/roboOS/autorun.cfg")
                                    end
                                    return 1
                                end
                            elseif num == 4 then
                                --copy
                                if not copy() then
                                    refresh = 1
                                end
                            elseif num == 5 then
                                --remove
                                if gui.yesno("remove?") then
                                    if check() then return 1 end
                                    proxy.remove(full_path)
                                    if setAutorun then
                                        proxy.remove("/roboOS/autorun.cfg")
                                    end
                                    return 1
                                end
                            elseif num == 6 then
                                --rename
                                local data = gui.read("new name")
                                if data then
                                    if data:find("%/") or data:find("%\\") then
                                        gui.warn("unsupported char /")
                                    else
                                        if check() then return 1 end
                                        full_path = fs_path(old_full_path) .. "/" .. data
                                        proxy.rename(old_full_path, full_path)
                                        if setAutorun then
                                            saveFile(proxy, "/roboOS/autorun.cfg", full_path .. "/main.lua")
                                        end
                                        return 1
                                    end
                                end
                            else
                                return refresh
                            end
                        end
                    end
                end
            end
        end

        while 1 do
            gui.setData("roboOS", doc, strs)
            num, scroll = gui.menu(num, scroll)
            if num == 1 then
                break
            elseif num == 2 then
                computer.shutdown()
            elseif num == 3 then
                computer.shutdown(1)
            elseif num == 4 then
                settings()
            elseif num == 5 then
                bootToExternalOS()
            else
                if runs[num]() then
                    break
                end
            end
        end
    end
end