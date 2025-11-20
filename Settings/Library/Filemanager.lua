local _readfile = readfile or (debug and debug.readfile)
local _listfiles = listfiles or (debug and debug.listfiles)
local _writefile = writefile or (debug and debug.writefile)
local _makefolder = makefolder or (debug and debug.makefolder)
local _appendfile = appendfile or (debug and debug.appendfile)
local _isfolder = isfolder or (debug and debug.isfolder)
local _delfolder = delfolder or (debug and debug.delfolder)
local _delfile = delfile or (debug and debug.delfile)
local _loadfile = loadfile or (debug and debug.loadfile)
local _dofile = dofile or (debug and debug.dofile)
local _isfile = isfile or (debug and debug.isfile)

local function no_op(...) end
_readfile = _readfile or no_op
_listfiles = _listfiles or function() return {} end
_writefile = _writefile or no_op
_makefolder = _makefolder or no_op
_appendfile = _appendfile or no_op
_isfolder = _isfolder or function() return false end
_delfolder = _delfolder or no_op
_delfile = _delfile or no_op
_loadfile = _loadfile or no_op
_dofile = _dofile or no_op
_isfile = _isfile or function() return false end

local HttpService = game:GetService("HttpService")

local FileManager = {}

function FileManager:GetFolder(VAL)
    local self = self
    if not _isfolder(VAL) then
        _makefolder(VAL)
    end
end

function FileManager:DeleteFolder(VAL)
    local self = self
    if _isfolder(VAL) then
        _delfolder(VAL)
    end
end

function FileManager:GetFile(VAL, data)
    local self = self
    if not _isfile(VAL) then
        if type(data) == "table" then
            _writefile(VAL, HttpService:JSONEncode(data))
        else
            _writefile(VAL, tostring(data or ""))
        end
    end
end

function FileManager:WriteFile(VAL, data)
    local self = self
    if type(data) == "table" then
        _writefile(VAL, HttpService:JSONEncode(data))
    else
        _writefile(VAL, tostring(data or ""))
    end
end

function FileManager:DeleteFile(VAL)
    local self = self
    if _isfile(VAL) then
        _delfile(VAL)
    end
end

function FileManager:ReadFile(VAL, format)
    local self = self
    if _isfile(VAL) then
        local content = _readfile(VAL)
        if format == "table" then
            local success, decoded = pcall(HttpService.JSONDecode, HttpService, content)
            if success then
                return decoded
            else
                return nil
            end
        else
            return content
        end
    end
    return nil
end

function FileManager:ListFiles(VAL, format)
    local self = self
    local fileList = {}
    
    if not _isfolder(VAL) then
        return fileList
    end

    for _, filePath in _listfiles(VAL) do
        local name = filePath:match("[^/\\]+$")
        if name then
            local include = true
            if format == "json" then
                if name:match("%.json$") then
                    name = name:sub(1, -6)
                else
                    include = false
                end
            elseif format == "lua" then
                if name:match("%.lua$") then
                    name = name:sub(1, -5)
                else
                    include = false
                end
            end
            
            if include then
                table.insert(fileList, name)
            end
        end
    end
    return fileList
end

return FileManager
