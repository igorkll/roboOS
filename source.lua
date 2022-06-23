computer.setArchitecture("Lua 5.3")

local code = [[
--крайне извиняюсь за говнокод, так как этот код исначально предназначался для eeprom
--именно по этому ТАК всрато я старался уталкать это чудо в 4кб

---------------------------------------------init

local c, p = component, computer
local words = {"key_down", "/roboOS/autorun.cfg", "user management(useradd/userremove/userlist)", "unsupported char /"}

---------------------------------------------gpu
--.{<кол-во символов>}|.+

local gpu, eeprom = c.proxy(c.list"gpu"() or ""), c.proxy(c.list"eeprom"())
if gpu then
    if gpu.bind(c.list"screen"() or "", true) then
        gpu.setResolution(50, 16)
    else
        gpu = a
    end
end

---------------------------------------------eeprom

local function getDataPart(part)
    return split(eeprom.getData(), "\n")[part] or ""
end
_G.getDataPart = getDataPart

local function setDataPart(part, newdata)
    if getDataPart(part) == newdata then return end
    if newdata:find"\n" then error"\\n char" end
    local parts = split(eeprom.getData(), "\n")
    for i = part, 1, -1 do
        if not parts[i] then parts[i] = "" end
    end
    parts[part] = newdata
    eeprom.setData(table.concat(parts, "\n"))
end
_G.getDataPart = getDataPart

---------------------------------------------functions

local function split(str, sep)
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
_G.split = split

local function toParts(str, max)
    local strs = {}
    while #str > 0 do
        table.insert(strs, str:sub(1, max))
        str = str:sub(#strs[#strs] + 1)
    end
    return strs
end
_G.toParts = toParts

local function getFile(fs, file)
    local file, buffer = assert(fs.open(file, "rb")), ""

    while 1 do
        local data = fs.read(file, math.huge)
        if not data then break end
        buffer = buffer .. data
    end
    fs.close(file)

    return buffer
end
_G.getFile = getFile

local function saveFile(fs, file, data)
    local file = assert(fs.open(file, "wb"))
    fs.write(file, data)
    fs.close(file)
end
_G.saveFile = saveFile

local function bootToOS(fs, file)
    function p.getBootAddress()
        return fs.address
    end
    function p.getBootGpu()
        return gpu and gpu.address
    end
    function p.getBootScreen()
        return gpu and gpu.getScreen()
    end
    function p.getBootFile()
        return file
    end

    function p.setBootAddress()
    end
    function p.setBootScreen()
    end
    function p.setBootFile()
    end

    assert(load(getFile(fs, file), "=init"))()
    p.shutdown()
end

local function fs_path(path)
    local splited = split(path, "/")
    if splited[#splited] == "" then splited[#splited] = a end
    return table.concat({table.unpack(splited, 1, #splited - 1)}, "/")
end
_G.fs_path = fs_path

local function getInternetFile(url)--взято из mineOS efi от игорь тимофеев
    local handle, data, result, reason = c.proxy(c.list"internet"()).request(url), ""
    if handle then
        while 1 do
            result, reason = handle.read(math.huge)	
            if result then
                data = data .. result
            else
                handle.close()
                
                if reason then
                    return a, reason
                else
                    return data
                end
            end
        end
    else
        return a, "Unvalid Address"
    end
end
_G.getInternetFile = getInternetFile

---------------------------------------------gui

if gpu then
    gui = {}
    local rx, ry = gpu.getResolution()
    local label, docs, strs, docX = "", "", {}, math.floor((rx / 3) * 2)

    local function invert()
        gpu.setBackground(gpu.setForeground(gpu.getBackground()))
    end
    gui.invert = invert

    local function setText(str, posX, posY)
        gpu.set((posX or 0) + math.floor(((rx / 2) - ((unicode.len(str) - 1) / 2)) + 0.5), posY or math.floor((ry / 2) + 0.5), str)
    end
    gui.setText = setText

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
            local eventData = {p.pullSignal()}
            if eventData[1] == words[1] then
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
        gpu.fill(docX + 1, ry / 2, rx - docX, 1, "─")
        
        local function printDoc(doc, posY)
            local splitedDoc, tbl = split(doc or "not found", "\n"), {}
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
        gpu.set(docX + 1, (ry / 2) + 1, "menu point doc:")
        printDoc(docs[num], (ry / 2) + 2)
        
        for i, data in ipairs(strs) do
            local posY = i + 2
            posY = posY - scroll
            if posY >= 3 and posY <= (ry - 2) then
                if i == num then invert() end
                gpu.set(1, posY, data)
                if i == num then invert() end
            end
        end
    end

    function gui.menu(num, scroll)
        gui.draw(num, scroll)
        while 1 do
            local eventData = {p.pullSignal()}
            if eventData[1] == words[1] then
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

    function gui.warn(str)
        gpu.fill(8, 3, rx - 15, ry - 4, "▒")
        setText("▒▒▒▒▒▒█▒▒▒▒▒▒", a, 4)
        setText("▒▒▒▒▒███▒▒▒▒▒", a, 5)
        setText("▒▒▒▒██ ██▒▒▒▒", a, 6)
        setText("▒▒▒███ ███▒▒▒", a, 7)
        setText("▒▒█████████▒▒", a, 8)
        setText("▒█████ █████▒", a, 9)
        setText("█████████████", a, 10)
        setText(str, a, 12)
        setText("Press Enter To Continue", a, 13)

        p.beep(100, 0.2)

        while 1 do
            local eventData = {p.pullSignal()}
            if eventData[1] == words[1] and eventData[4] == 28 then
                break
            end
        end
    end

    function gui.status(str)
        gpu.fill(8, 3, rx - 15, ry - 4, "▒")
        setText(str, a, ry / 2)

        p.beep(1000, 0.1)
    end

    function gui.yesno(str)
        invert()
        gpu.fill((rx / 2) - 10, (ry / 2) - 1, 20, 5, "▒")
        setText(str, a, (ry / 2))

        p.beep(500, 0.01)
        p.beep(2000, 0.01)

        local selected = a

        while 1 do
            if selected then invert() end
            setText("yes", -5, (ry / 2) + 2)
            if selected then invert() end

            if not selected then invert() end
            setText("no", 5, (ry / 2) + 2)
            if not selected then invert() end

            local eventData = {p.pullSignal()}
            if eventData[1] == words[1] then
                if eventData[4] == 203 then
                    selected = 1
                elseif eventData[4] == 205 then
                    selected = a
                elseif eventData[4] == 28 then
                    invert()
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
    local num, scroll, strs, doc = 1, 0, {"white", "black", "exit"}, {[0] = "theme selector", "white theme", "black theme"}

    while 1 do
        gui.setData("theme selector", doc, strs)
        num, scroll = gui.menu(num, scroll)
        if num == 1 then
            setTheme(true)
        elseif num == 2 then
            setTheme(false)
        elseif num == 3 then
            break
        end
    end
end

local function usermenager()
    local num, scroll = 1, 0

    while 1 do
        local strs, removers, docs = {"add new user", "exit"}, {}, {[0] = words[3], "press enter to add new user"}

        for _, nikname in ipairs{p.users()} do
            table.insert(strs, 1, nikname)
            table.insert(removers, 1, function()
                if gui.yesno"remove user?" then
                    for i, v in ipairs(strs) do
                        if v == nikname then
                            table.remove(strs, i)
                            table.remove(removers, i)
                            p.removeUser(nikname)
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
            local nikname = gui.read"nikname"
            if nikname then
                local ok, err = p.addUser(nikname)
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
    local num, scroll, strs, doc = 1, 0, {"priority external", "priority internal", "only external", "only internal", "disable", "exit"}, {}

    local function getMode()
        if getDataPart(2) == "" then
            doc[0] = "autoruns settings" --нет тут не пропушена \n она тут ненужна и так будет автоперенос
            .. "currect mode:\npriority external"
        elseif getDataPart(2) == "i" then
            doc[0] = "autoruns settings" .. "currect mode:\npriority internal"
        elseif getDataPart(2) == "b" then
            doc[0] = "autoruns settings" .. "currect mode:\nonly external"
        elseif getDataPart(2) == "a" then
            doc[0] = "autoruns settings" .. "currect mode:\nonly internal"
        elseif getDataPart(2) == "d" then
            doc[0] = "autoruns settings" .. "currect mode:\ndisable"
        end
    end
    getMode()
    while 1 do
        gui.setData("autorun", doc, strs)
        num, scroll = gui.menu(num, scroll)
        if num == 1 then
            setDataPart(2, "") --priority external
        elseif num == 2 then
            setDataPart(2, "i") --priority internal
        elseif num == 3 then
            setDataPart(2, "b") --only external
        elseif num == 4 then
            setDataPart(2, "a") --only internal
        elseif num == 5 then
            setDataPart(2, "d") --disable
        elseif num == 6 then
            break
        end
        getMode()
    end
end

local function bootToExternalOS()
    while 1 do
        local num, scroll, strs, osList, docs = 1, 0, {"exit"}, {}, {[0] = "boot to:\nopenOS\nplan9k\nother..."}

        for address in c.list"filesystem" do
            local proxy = c.proxy(address)
            local function addFile(file)
                table.insert(strs, 1, (proxy.getLabel() or "noLabel") .. ":" .. address:sub(1, 6) .. ":" .. file)
                table.insert(osList, 1, function()
                    bootToOS(proxy, file)
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
                osList[num]()
            end
        end
    end
end

local function settings()
    local num, scroll, strs, doc = 1, 0, {"autorun", "usermenager", "theme", "exit"}, {"set autorun mode and autorun programm", words[3], "theme selector"}

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
    return 1
end

local function downloadApp()
    local internet = c.proxy(c.list"internet"() or "")
    if not internet then
        gui.warn"internet card is not found"
        return
    end
    local url = gui.read("url")
    if url then
        gui.status"downloading"
        local data, err = getInternetFile(url)
        if not data then
            gui.warn(err or "unknown")
            return
        end
        
        local strs, runs = {}, {}

        for address in c.list"filesystem" do
            local proxy = c.proxy(address)
            if not proxy.isReadOnly() then
                table.insert(runs, function()
                    local name = gui.read"name to save"
                    if name then
                        if name:find"%/" or name:find"%\\" then
                            gui.status(words[4])
                        else
                            local path = "/roboOS/programs/" .. name
                            if proxy.exists(path) then
                                gui.warn("this name used")
                                return
                            end
                            proxy.makeDirectory(path)
                            saveFile(proxy, path .. "/main.lua", data)
                            return 1
                        end
                    end
                end)
                table.insert(strs, (proxy.getLabel() or "noLabel") .. ":" .. address:sub(1, 6))
            end
        end
        table.insert(strs, "exit")

        gui.setData("select drive to save", {}, strs)

        local num, scroll = 1, 0
        while 1 do
            num, scroll = gui.menu(num, scroll)
            if not runs[num] then break end
            if runs[num]() then return 1 end
        end
    end
end

local deviceinfo = p.getDeviceInfo()
local autorunProxy, autorunFile
if getDataPart(2) ~= "d" then --is not disable
    local internal, external, lists = {}, {}, {}
    do
        for address in c.list"filesystem" do
            if address ~= p.tmpAddress() and (c.slot(address) < 0 or deviceinfo[address].clock == "20/20/20") then
                table.insert(external, address)
            else
                table.insert(internal, address)
            end
        end
    end
    if getDataPart(2) == "" then --priority external
        table.insert(lists, external)
        table.insert(lists, internal)
    elseif getDataPart(2) == "i" then --priority internal
        table.insert(lists, internal)
        table.insert(lists, external)
    elseif getDataPart(2) == "a" then --only internal
        table.insert(lists, internal)
    elseif getDataPart(2) == "b" then --only external
        table.insert(lists, external)
    end

    for _, list in ipairs(lists) do
        for _, address in ipairs(list) do
            local proxy = c.proxy(address)
            if proxy.exists(words[2]) then
                local data = getFile(proxy, words[2])
                if proxy.exists(data) then
                    autorunProxy = proxy
                    autorunFile = data
                    goto breaking
                end
            end
        end
    end
    ::breaking::
end

if autorunProxy then
    if gui then
        gui.status"press alt to skip autorun"
        local inTime = p.uptime()
        repeat
            local eventData = {p.pullSignal(0.1)}
            if eventData[1] == words[1] and eventData[4] == 56 then
                goto skipautorun
            end
        until p.uptime() - inTime > 1
    end
    runProgramm(autorunProxy, autorunFile)
    ::skipautorun::
end

if gui then
    local num, scroll = 1, 0
    while 1 do
        local strs, doc, runs = {"refresh", "shutdown", "reboot", "settings", "boot to external os", "download programm"}, {[0] = "navigation ↑↓\nok - enter", [5] = "boot to:\nopenOS\nplan9k\nother...", [6] = "download programm from internet used internet-card"}, {}

        for address in c.list"filesystem" do
            local proxy, programsPath = c.proxy(address), "/roboOS/programs/"
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
                        local function copy(clone)
                            local strs = {}
                            local addresses = {}
                            for address in c.list"filesystem" do
                                local proxy = c.proxy(address)
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
                            if gui.yesno"use new name?" then
                                gui.draw(num, scroll)
                                local newname = gui.read"new name"
                                if not newname then
                                    gui.warn"using new name canceled"
                                    gui.draw(num, scroll)
                                elseif name:find"%/" or name:find"%\\" then
                                    gui.warn(words[4])
                                    return 1
                                else
                                    name = newname
                                end
                            end

                            if not gui.yesno(clone and "move?" or "copy?") then
                                return 1
                            end
                            local targetProxy = c.proxy(addresses[num])
                            
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
                                gui.warn"this name used"
                                return 1
                            end
                            recurse(full_path, "/roboOS/programs/" .. name)
                        end

                        local num, scroll, refresh = 1, 0
                        while 1 do
                            gui.setData("programm " .. programmName, {[0] = doc[index]}, {"open", "set to autorun", "move", "copy", "remove", "rename", "back"})
                            num, scroll = gui.menu(num, scroll)
                            local old_full_path = full_path
                            local setAutorun = proxy.exists(words[2]) and getFile(proxy, words[2]) == (old_full_path .. "main.lua")
                            if num == 1 then
                                if not runProgramm(proxy, full_path .. "main.lua") then
                                    return 1
                                end
                            elseif num == 2 then
                                if gui.yesno("set autorun?") then
                                    saveFile(proxy, words[2], full_path .. "main.lua")
                                end
                            elseif num == 3 then
                                --move
                                if not copy(1) then
                                    proxy.remove(full_path)
                                    if setAutorun then
                                        proxy.remove(words[2])
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
                                if gui.yesno"remove?" then
                                    proxy.remove(full_path)
                                    if setAutorun then
                                        proxy.remove(words[2])
                                    end
                                    return 1
                                end
                            elseif num == 6 then
                                --rename
                                local data = gui.read"new name"
                                if data then
                                    if data:find"%/" or data:find"%\\" then
                                        gui.warn(words[4])
                                    else
                                        full_path = fs_path(old_full_path) .. "/" .. data
                                        proxy.rename(old_full_path, full_path)
                                        if setAutorun then
                                            saveFile(proxy, words[2], full_path .. "/main.lua")
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
        if num > #strs then
            num = 1
            scroll = 0
        end

        while 1 do
            gui.setData("roboOS", doc, strs)
            num, scroll = gui.menu(num, scroll)
            if num == 1 then
                break
            elseif num == 2 then
                p.shutdown()
            elseif num == 3 then
                p.shutdown(1)
            elseif num == 4 then
                settings()
            elseif num == 5 then
                bootToExternalOS()
            elseif num == 6 then
                if downloadApp() then
                    break
                end
            else
                if runs[num]() then
                    break
                end
            end
        end
    end
end
]]
assert(load(code, "=OS"))()