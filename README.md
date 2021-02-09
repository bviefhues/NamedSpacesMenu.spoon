# NamedSpacesMenu

Menubar menu for naming and switching macOS spaces. 

This maps user-defined space names to macOS spaces. macOS does not allow changing the names of spaces. The names maintained in this spoon are visible in the spoon only. 

## Installation

* Install [Hammerspoon](https://www.hammerspoon.org/)

* Install [\_asm.undocumented.spaces](https://github.com/asmagill/hs._asm.undocumented.spaces) module

* Install `NamedSpacesMenu.spoon` (this repository) by downloading or cloning it to `~/.hammerspoon/Spoons/`

* Load and configure the Spoon from `~/.hammerspoon/init.lua`:

```
hs.loadSpoon("NamedSpacesMenu"):start()
```

* Reload Hammerspoon


## Usage

* Open menubar menu.

* To change to space: Click on space name.

* To move window to space and change to space: Ctrl-click on space name

* To rename a space: Click "Rename current space"

