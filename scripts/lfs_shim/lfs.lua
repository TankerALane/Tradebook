-- Minimal pure-Lua stand-in for LuaFileSystem, so luacheck runs locally on Windows
-- without a C compiler. Only supports what luacheck needs for explicit file lists.
-- CI uses the real luafilesystem.
local lfs = { _VERSION = "LuaFileSystem 0.0-shim" }

function lfs.currentdir()
    local p = io.popen("cd")
    local dir = p and p:read("*l") or "."
    if p then p:close() end
    return dir
end

function lfs.attributes(path, field)
    local f = io.open(path, "r")
    if not f then return nil, "cannot open " .. tostring(path) end
    local ok = f:read(0)
    f:close()
    local attrs = { mode = (ok == nil and "directory" or "file"), modification = 0, size = 0 }
    if field then return attrs[field] end
    return attrs
end

function lfs.dir()
    error("lfs shim: directory listing not supported; pass explicit files")
end

function lfs.mkdir() return nil, "unsupported" end

return lfs
