local Window = {};
Window.__index = Window;

local fused = love.filesystem.isFused();

function Window.new(files, name, callback, unfilteredArgs)
    local instance = setmetatable({}, Window);

    instance.edits = {};

    instance.queue = {};
    instance.peer = nil;

    instance.amOpen = false;
    instance.isQueueOpen = false;

    instance.name = name;
    instance.callback = callback;
    instance.unfilteredArgs = unfilteredArgs;

    instance.useable = true;

    for k, v in pairs(files) do
        instance:addFile(k, v)
    end

    if fused then
        instance:addFile("lovec.exe", love.filesystem.newFileData("lovec.exe"));

        -- if you ever write to the folder 'loveDLLFiles' then you WILL fuck this whole thing up... dont do it (also you will lose that data)
        assert(love.filesystem.mount(exepath, "loveDLLFiles"), "Could not mount source to base directory");

	    for _, v in ipairs(love.filesystem.getDirectoryItems("loveDLLFiles")) do
            if string.sub(v, -4,-1) == ".dll" then
                instance:addFile(v, love.filesystem.newFileData("loveDLLFiles/" .. v));
            end
	    end

	    love.filesystem.unmount("loveDLLFiles");
    end

    instance:clearIdentity();
    instance:write();

    return instance;
end

function Window:addFile(filename, data)
    filename = self:cleanFilename(filename);

    if filename then
        table.insert(self.edits, {filename = filename, data = data});
    end
end
function Window:removeFile(filename)
    filename = self:cleanFilename(filename);

    if filename then
        table.insert(self.edits, {filename = filename, data = nil});
    end
end
function Window:editFile(filename, data)
    filename = self:cleanFilename(filename);

    if filename then
        table.insert(self.edits, {filename = filename, data = data});
    end
end
function Window:cleanFilename(filename)
    filename = string.gsub(filename, "\\", "/");
    filename = string.match(filename, "^.+%.[^/]*$") or filename .. ".lua";

    local allowed, err = self:checkAvailableFilename(filename);

    if allowed then
        return filename;
    else
        print("WARNING: " .. err);
    end
end
function Window:checkAvailableFilename(filename) -- probably works, idk
    filename = string.gsub(filename, "\\", "/");

	local dissallowedNames = {
		{"CON", "'CON'"};
		{"PRN", "'PRN'"};
		{"AUX", "'AUX'"};
		{"NUL", "'NUL'"};
		{"COM%d", "'COM%d' (%d is a digit)"};
		{"LPT%d", "'LPT%d' (%d is a digit)"};
		{"CON%.[^/]*", "'CON' of any file type"}; -- sneaky but CON.a.txt is also not allowed
		{"PRN%.[^/]*", "'PRN' of any file type"};
		{"AUX%.[^/]*", "'AUX' of any file type"};
		{"NUL%.[^/]*", "'NUL' of any file type"};
		{"COM%d%.[^/]*", "'COM%d' (%d is a digit) of any file type"};
		{"LPT%d%.[^/]*", "'LPT%d' (%d is a digit) of any file type"};
		{"[^/]*%.", "anything that ends with a period"};
		{"[^/]* ", "anything that ends with a space"};
        {"", "nothing"};
        {"%.[^./]*", "nothing"};
        {"%.", "'.', special case for linux"};
        {"%.%.", "'..', special case for linux"};
        {"[^/]*<[^/]*", "anything containing '<'"};
        {"[^/]*>[^/]*", "anything containing '>'"};
        {"[^/]*:[^/]*", "anything containing ':'"};
        {"[^/]*\"[^/]*", "anything containing '\"'"};
        {"[^/]*|[^/]*", "anything containing '|'"};
        {"[^/]*%?[^/]*", "anything containing '?'"};
        {"[^/]*%*[^/]*", "anything containing '*'"};
        {"[^/]*%c[^/]*", "anything containing control characters"};
	};

	local preparedStr = "/" .. filename .. "/";
	for i, v in ipairs(dissallowedNames) do
		if string.find(preparedStr, "/" .. v[1] .. "/") then
			return false, "files cannot be named " .. v[2];
		end
	end

	return true; -- got past all of the tests
end

function Window:readFile(filename)
    filename = self:cleanFilename(filename);

    if not filename then
        return;
    end

    local prevIdentity = love.filesystem.getIdentity();
    love.filesystem.setIdentity(self.name);

    local ret = love.filesystem.read(filename);

    love.filesystem.setIdentity(prevIdentity);

    return ret;
end
function Window:getFile(filename)
    filename = self:cleanFilename(filename);

    if not filename then
        return;
    end

    local prevIdentity = love.filesystem.getIdentity();
    love.filesystem.setIdentity(self.name);

    local ret = love.filesystem.newFile(filename);

    love.filesystem.setIdentity(prevIdentity);

    return ret;
end
function Window:getFileData(filename)
    filename = self:cleanFilename(filename);

    if not filename then
        return;
    end

    local prevIdentity = love.filesystem.getIdentity();
    love.filesystem.setIdentity(self.name);

    local ret = love.filesystem.newFileData(filename);

    love.filesystem.setIdentity(prevIdentity);

    return ret;
end

function Window:write()
    if #self.edits == 0 then
        return;
    end

    if self.amOpen then -- dont edit while opened
        return;
    end

    local prevIdentity = love.filesystem.getIdentity();
    love.filesystem.setIdentity(self.name);

    while #self.edits ~= 0 do
        local edit = table.remove(self.edits, 1);

        if edit.data then -- edit or add
            if string.find(edit.filename, "/") then
                love.filesystem.createDirectory(string.match(edit.filename, "^(.+)/"));
            end

            love.filesystem.write(edit.filename, edit.data);
        else -- delete file
            love.filesystem.remove(edit.filename);
        end
    end

    love.filesystem.setIdentity(prevIdentity);
end

function Window:open()
    if self.amOpen then
        print("WARNING: trying to open a window more than once");

        return;
    end

    if #self.edits ~= 0 then
        self:write();
    end

    local prevIdentity = love.filesystem.getIdentity();
    love.filesystem.setIdentity(self.name);

    local savepath = love.filesystem.getSaveDirectory();

    if fused then
        -- I stole this code and have no idea what it does, didnt stop me from altering it tho :3
        io.popen("\"\"" .. savepath .. "/lovec.exe\" \"" .. savepath .. "/.\"\"");
    else
        -- I stole this code and have no idea what it does, didnt stop me from altering it tho :3
        io.popen("\"\"" .. self.unfilteredArgs[-2] .. "\" \"" .. savepath .. "/.\"\"");
    end

    love.filesystem.setIdentity(prevIdentity);

    self.amOpen = true;
end

function Window:clearIdentity()
    local prevIdentity = love.filesystem.getIdentity();
    love.filesystem.setIdentity(self.name);

    self:emptyPath("");

    love.filesystem.setIdentity(prevIdentity);
end
function Window:emptyPath(dir)
	if love.filesystem.getInfo(dir, "directory") then
        for _, v in ipairs(love.filesystem.getDirectoryItems(dir)) do
            self:emptyPath(dir .. "/" .. v);
            love.filesystem.remove(dir .. "/" .. v);
        end
	end
end

function Window:setPeer(peer)
    self.peer = peer;
end

function Window:getMessage(event)
    if event.channel == 1 then
        if self.callback then
            self.callback(event.message);
        end
    elseif event.channel == 0 then
        print(event.message);
        if event.message == "__DISCONNECTED" then
            if self.callback then
                self.callback("close");
            end

            self.amOpen = false;

            return true;
        end
    end
end

function Window:update()
    if not self.amOpen then
        if #self.queue ~= 0 then
            self.queue = {};
        end

        self:write();

        if self.isQueueOpen then
            self:open();
            self.isQueueOpen = false;
        end

        return;
    end

    if not self.peer then
        return;
    end

    while #self.queue > 0 do
        local event = table.remove(self.queue, 1);

        self.peer:send(event.message, event.channel);
    end
end

function Window:send(msg)
    table.insert(self.queue, {message = msg, channel = 1});
end
function Window:close()
    table.insert(self.queue, {message = "__CLOSE", channel = 0});
end
function Window:queueOpen()
    self.isQueueOpen = true;
end
function Window:unqueueOpen()
    self.isQueueOpen = false;
end
function Window:isOpen()
    return self.amOpen;
end

function Window:delete()
    self.useable = false;
end

return Window;