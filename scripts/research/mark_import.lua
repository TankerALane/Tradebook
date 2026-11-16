-- scripts/research/mark_import.lua
-- Last step of "import npc data": write dev/TradebookDev/LastImport.lua with the import time, so
-- Tradebook Dev's "since the last import" count (heard notifications, /tbdev count) starts again
-- after the next /reload. Local only (.gitignore); the dev addon is linked into AddOns.
--
-- usage: luajit scripts/research/mark_import.lua
local f = assert(io.open("dev/TradebookDev/LastImport.lua", "wb"))
f:write("-- Written by scripts/research/mark_import.lua: when the maintainer last imported in-game data.\n")
f:write(("TradebookDevLastImport = %d\n"):format(os.time()))
f:close()
io.stderr:write(("import marked at %s\n"):format(os.date("%Y-%m-%d %H:%M")))
