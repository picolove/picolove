-- compatfs v0.0.1 -
-- (incomplete) LÖVE 0.10.2 filesystem compatibility layer for LöVE 11

-- https://github.com/picolove/picolove
-- ZLIB LICENSE


-- Missing functions:
-- love.filesystem.isSymlink
-- love.filesystem.getLastModified
-- love.filesystem.getSize

local compatfs = {}

local fs = love.filesystem

function compatfs.isDirectory(path)
	local info = fs.getInfo(path)
	return info and info.type == "directory"
end

function compatfs.isFile(path)
    local info = fs.getInfo(path)
    return info and info.type == "file"
end

function compatfs.exists(path)
    local info = fs.getInfo(path)
    return info ~= nil
end

-- patch LÖVE functions
function compatfs.applyPatch()
	fs.exists, fs.isDirectory, fs.isFile =
		compatfs.exists, compatfs.isDirectory, compatfs.isFile
end

return compatfs
