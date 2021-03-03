--- === NamedSpacesMenu ===
---
--- Menubar menu for naming and switching macOS spaces.

local spaces =     require("hs._asm.undocumented.spaces")
local inspect =    require("hs.inspect")
local settings =   require("hs.settings")
local dialog =     require("hs.dialog")
local menubar =    require("hs.menubar")
local styledtext = require("hs.styledtext")
local console =    require("hs.console")
local eventtap =   require("hs.eventtap")
local mouse =      require("hs.mouse")

local obj={}
obj.__index = obj

-- Metadata
obj.name = "NamedSpacesMenu"
obj.version = "0.0"
obj.author = "B Viefhues"
obj.homepage = "https://github.com/bviefhues/NamedSpacesMenu.spoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"


-- Variables --

--- NamedSpacesMenu.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set 
--- the default log level for the messages coming from the Spoon.
obj.log = hs.logger.new("NamedSpacesMenu")

-- Internal: NamedSpacesMenu.spaces
-- Variable
-- Contains the mapping from space number to space name to space id.
obj.spaces = nil

-- Internal: NamedSpacesMenu.menubar
-- Variable
-- Contains the Spoons hs.menubar. 
obj.menubar = nil

-- Internal: NamedSpacesMenu.spacesWatcher
-- Variable
-- Contains a hs.spaces.watcher for the Spoon to get notified on
-- macOS space changes.
obj.spacesWatcher = nil

-- Internal: NamedSpacesMenu.shortcuts
-- Variable
-- Shortcuts for the Spoons menuTable.
-- TODO: make configurable
obj.shortcuts = {
    [1]="1", [2]="2", [3]="3", [4]="4", 
    [5]="5", [6]="6", [7]="7", [8]="8", 
    [9]="9", [10]="0", [11]="a", [12]="b", 
    [13]="c", [14]="d", [15]="e", [16]="f",
} -- macOS supports max 16 spaces

-- Internal: NamedSpacesMenu.hotkeyShowMenu
-- Variable
-- Contains the hotkey callback to show the menubar menu
obj.hotkeyShowMenu = nil


-- State persistence --

-- Internal: Save spaces names to keep them across hammerspoon reloads
function obj.saveSettings()
    obj.log.d("> saveSettings")
    local names = {}
    for i, space in pairs(obj.spaces) do
        table.insert(names, space.name)
    end
    hs.settings.set("NamedSpacesBar", names)
    obj.log.d("< saveSettings")
end

-- Internal: Load spaces names
function obj.loadSettings()
    obj.log.d("> loadSettings")
    local names = hs.settings.get("NamedSpacesBar")
    obj.log.d("< loadSettings ->", inspect.inspect(names))
    return names
end


-- State Update

-- Internal: Initialize the obj.spaces table 
-- Maps loadSettings() names to current spaces
function obj.initSpaces()
    obj.log.d("> initSpaces")
    local names = obj.loadSettings()

    obj.spaces = {} -- we will re-build this now
    
    local screen = spaces.mainScreenUUID()
    for space_number, space_id in ipairs(spaces.layout()[screen]) do
        local name = "Space " .. tostring(space_number) -- default name
        if names and names[space_number] then
            name = names[space_number]
        end
        local space = {
            number = space_number,
            id = space_id,
            name = name,
        }
        table.insert(obj.spaces, space)
    end
    obj.log.d("< initSpaces")
end

-- Internal: Updates obj.spaces table, in case Mission Control has 
-- changed the spaces configuration:
--  * New space added
--  * Space deleted
--  * Space order changed
-- Maps space names to spaces order as returned by spaces module
function obj.updateSpaces()
    obj.log.d("> updateSpaces")
    -- keep mapping of space id's to names
    local names_id = {}
    for space_number, space in ipairs(obj.spaces) do
        names_id[space.id] = space.title
    end

    obj.spaces = {} -- we will re-build this now
    
    local screen = spaces.mainScreenUUID()
    for space_number, space_id in pairs(spaces.layout()[screen]) do
        local name = names_id[space_id]
        if name == nil then
            name = "Space " .. tostring(space_number) -- default name
        end
        local space = {
            number = space_number,
            id = space_id,
            name = name,
        }
        table.insert(obj.spaces, space)
    end
    obj.log.d("< updateSpaces")
end


-- Space Switching --

-- Internal: Callback for hs.spaces.watcher, is triggered when 
-- user switches to another space, updates menu
function obj.switchedToSpace(number)
    obj.log.d("> switchedToSpace", number)
    obj.updateSpaces() -- in case spaces configuration has changed
    obj.updateMenu()
    obj.log.d("< switchedToSpace")
end

-- Internal: menuTable callback
-- click: switch to space
-- ctrl-click: move focused window to space and then switch to space
function obj.switchToSpace(modifiers, space)
    obj.log.d("> switchToSpace", inspect.inspect(modifiers), 
        inspect.inspect(space))
    
    if modifiers.ctrl == true then
        hs.window.focusedWindow():spacesMoveTo(space.id)
    end

    -- spaces.changeToSpace() un-minimizes windows, therefore simulate 
    -- keystroke for space numbers <=10. Requires enabling mission control
    -- space changes in system preferences' keyboard settings.
    if space.number < 10 then
        eventtap.keyStroke({"ctrl"}, tostring(space.number))        
    elseif space.number == 10 then
        eventtap.keyStroke({"ctrl"}, "0")        
    else
        spaces.changeToSpace(space.id)
    end

    -- we don't update anything here, since the space change triggers the
    -- switchedToSpace() watcher. This one will do the updates.
    obj.log.d("< switchToSpace")
end


-- Menubar --

-- Internal: Utility function, returns
--  * Name
--  * number (order as seen in Mission Control)
--  * id (as maintained by spaces module)
-- for current space
function obj.currentSpace()
    obj.log.d("> currentSpace")
    local id = spaces.activeSpace()
    local name, number
    for i, space in ipairs(obj.spaces) do
        if space.id == id then
            name = space.name
            number = space.number
            break
        end
    end
    obj.log.d("< currentSpace ->", name, number, id)
    return name, number, id
end

-- Internal: Updates the menu bar, with current space name and number,
-- as well as menu
function obj.updateMenu()
    obj.log.d("> updateMenu")
    local name, number, id = obj.currentSpace()
    -- use styledtext to add a grey background to the space number
    local styledName = hs.styledtext.new(" " .. name .. " ")
    local styledNumber = hs.styledtext.new(
        " " ..  tostring(number) .. "  ", 
        { backgroundColor = { white = 0.5, alpha = 0.5 } }
    )
    local title = styledName .. styledNumber

    obj.menubar:setTitle(title)
    obj.menubar:setMenu(obj.menuTable())
    obj.log.d("< updateMenu")
end

-- Internal: Generates the menu table for the menu bar
function obj.menuTable()
    obj.log.d("> menuTable")
    local name, number, id = obj.currentSpace()
    local menuTable = {}
    for i, space in ipairs(obj.spaces) do
        space.title = space.name
        if space.id == id then space.checked = true end
        space.shortcut = obj.shortcuts[space.number]
        space.fn = obj.switchToSpace
        table.insert(menuTable, space)
    end
    table.insert(menuTable, { title = "-" })
    table.insert(menuTable, { title = "Rename current space",
        fn = obj.renameCurrentSpace })
    -- obj.log.d("< menuTable ->", inspect.inspect(menuTable))
    obj.log.d("< menuTable ->", "(...)")
    return menuTable
end

-- Internal: Callback to display dialog for renaming current space and 
-- updates obj.spaces accordingly
function obj.renameCurrentSpace()
    obj.log.d("> renameCurrentSpace")
    local name, number, id = obj.currentSpace()
    -- TODO: showing the dialog box makes macOS switch to the space
    -- showing the Hammerspoon console. Fix by minimizing console if
    -- needed.
    local button, new_name = hs.dialog.textPrompt(
        'Rename current space', 
        'Enter new name for current space:', 
        name,
        "OK", "Cancel")
    if button == "OK" then
        obj.spaces[number].name = new_name
        obj.saveSettings()
        obj.updateMenu()
    end
    obj.log.d("< renameCurrentSpace")
end

-- Internal: Callback for hs.hotkey to show the menubar menu
function obj.showMenu()
    obj.log.d("> showMenu")
    -- save mouse pointer position, to restore after clicking
    local mousePoint = hs.mouse.getAbsolutePosition()
    local rect = obj.menubar:frame()
    local menuPoint = { x=rect._x, y=rect._y }
    hs.eventtap.leftClick(menuPoint)
    hs.mouse.setAbsolutePosition(mousePoint)
    obj.log.d("< showMenu")
end


-- Public Functions --

--- NamedSpacesMenu:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for NamedSpacesMenu
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for 
--     the following items:
---   * showmenu - this will show the menubar menu
---
--- Returns:
---  * The NamedSpacesMenu object
function obj:bindHotkeys(mapping)
    obj.log.d("> bindHotkeys", inspect(mapping))
    local showMenuMods = mapping["showmenu"][1]
    local showMenuKey = mapping["showmenu"][2]
    self.hotkeyShowMenu = hs.hotkey.bind(showMenuMods, showMenuKey,
        obj.showMenu)
    obj.log.d("< bindHotkeys")
    return self
end

--- NamedSpacesMenu:start()
--- Method
--- Starts NamedSpacesMenu
---
--- Parameters:
---  * None
---
--- Returns:
---  * The NamedSpacesMenu object
function obj:start()
    obj.log.d("> start")
    obj.initSpaces()
    obj.menubar = hs.menubar.new()
    obj.updateMenu()
    obj.spacesWatcher = hs.spaces.watcher.new(obj.switchedToSpace):start()
    obj.log.d("< start")
    return self
end

--- NamedSpacesMenu:stop()
--- Method
--- Stops NamedSpacesMenu
---
--- Parameters:
---  * None
---
--- Returns:
---  * The NamedSpacesMenu object
function obj:stop()
    obj.log.d("> stop")
    obj.menubar:delete()
    obj.spacesWatcher:stop()
    obj.log.d("< stop")
    return self
end

--- NamedSpacesMenu:setLogLevel()
--- Method
--- Set the log level of theNamedSpacesMenu logger.
---
--- Parameters:
---  * Log level 
---
--- Returns:
---  * The NamedSpacesMenu object
function obj:setLogLevel(level)
    obj.log.d("> setLogLevel")
    obj.log.setLogLevel(level)
    obj.log.d("< setLogLevel")
    return self
end

return obj
