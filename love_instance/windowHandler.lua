local enet = require("enet");

local path = string.match((...), ".+[./]") or "";

local DefaultConf = require(path .. "defaultConf");
local InjectFile = require(path .. "injectedFile");
local CoverFile = require(path .. "coverFile");

local MAX_WINDOW_COUNT = 64;
local SERVER_CHANNEL_COUNT = 2;
-- channel 0: event communication
-- channel 1: window communication

local INJECT_FILENAME = "INJECTED_FILE";
local COVER_FILENAME = "COVER_FILE";

local window_event = {
    __DISCONNECTED = "__DICONNECTED";
    __CONNECT = "__CONNECT";
    __CLOSE = "__CLOSE";
    close = "close";
}; -- enum

local event_type = {
    receive = "receive";
    connect = "connect";
    disconnect = "disconnect";
}; -- enum

local OpenWindow = {};
OpenWindow.__index = OpenWindow;

function OpenWindow:init(unfilteredArgs)
    self.peers = {};
    self.windows = {};

    self.unfilteredArgs = unfilteredArgs;

    self.server = enet.host_create("localhost:1345", MAX_WINDOW_COUNT, SERVER_CHANNEL_COUNT);
end

function OpenWindow:closeAll()
    self.server:broadcast(window_event.__CLOSE, 0); -- channel 0 for event communication
    self.server:flush();
end

function OpenWindow:_server_connect(event)
    local peer = event.peer;

    if self.peers[peer] then
        error("ERROR: client connected as a peer that already exists");
    end

    self.peers[peer] = {
        queue = {};
    };
end
function OpenWindow:_server_disconnect(event)
    local peer = event.peer;

    if not self.peers[peer] then
        return;
    end

    table.insert(self.peers[peer].queue, {message = window_event.__DISCONNECTED, channel = 0});
end
function OpenWindow:_server_receive(event)
    local peer = event.peer;

    if not self.peers[peer] then
        print("WARNING: recieving messages from non-allocated peer, ignoring and continuing");
        return;
    end

    if event.channel == 0 then
        local msg = event.data;
        local form, data = string.match(msg, "^(__.-) (.*)$");

        if form == window_event.__CONNECT then
            if self.windows[data] then
                self.windows[data].peer = peer;
            end
        else
            print("NEW EVENT MESSAGE (not good) : '" .. msg .. "'");
        end

        return;
    end

    table.insert(self.peers[peer].queue, {message = event.data, channel = event.channel});
end

function OpenWindow:_syncWindow(window, key)
    local peer = window.peer;

    if not peer or not self.peers[peer] then
        return;
    end

    while #self.peers[peer].queue > 0 do
        local event = table.remove(self.peers[peer].queue, 1);
        local message = event.message;

        if event.channel == 1 then
            if window.callback then
                window.callback(message);
            end
        elseif event.channel == 0 then
            if message == window_event.__DISCONNECTED then
                if window.callback then
                    window.callback(window_event.close);
                end

                self.windows[key] = nil;
                self.peers[peer] = nil;
            end
        end
    end
end
function OpenWindow:_updateWindow(window)
    if not window.peer then
        return;
    end

    while #window.queue > 0 do
        local event = table.remove(window.queue, 1);

        window.peer:send(event.message, event.channel);
    end
end

function OpenWindow:update()
    for k, v in pairs(self.windows) do
        self:_updateWindow(v);
    end

    local event = self.server:service();

    while event ~= nil do
        if event.type == event_type.receive then
            self:_server_receive(event);
        elseif event.type == event_type.connect then
            self:_server_connect(event);
        elseif event.type == event_type.disconnect then
            self:_server_disconnect(event);
        end

        event = self.server:service();
    end

    for k, v in pairs(self.windows) do
        self:_syncWindow(v, k);
    end
end

function OpenWindow:checkAvailableFilename(filename)
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
	};

	local preparedStr = "/" .. string.gsub(filename, "/", "//") .. "/";
	for i, v in ipairs(dissallowedNames) do
		if string.find(preparedStr, "/" .. v[1] .. "/") then
			return false, "files cannot be named " .. v[2];
		end
	end

	local illegalCharacters = "[<>:\"|?*%c]";
	if string.find(filename, illegalCharacters) then
		return false, "filenames cannot contain: '" .. string.match(filename, illegalCharacters) .. "' (if nothing is visible then it is a control character)";
	end

	return true; -- got past all of the tests
end

function OpenWindow:openFused(files)
    local savpath = love.filesystem.getSaveDirectory();
    local exepath = love.filesystem.getSourceBaseDirectory();
	love.filesystem.write('lovec.exe', love.filesystem.newFileData('lovec.exe'));

    for k, v in pairs(files) do
        if type(k) == "string" then
            local name = string.match(k, "^.+%..+$") or k .. ".lua";

			assert(self:checkAvailableFilename(name)); -- has its error message built in

            if string.find(name, "/") then
                love.filesystem.createDirectory(string.match(name, "^(.+)/"));
            end

            love.filesystem.write(name, v);
        else
            print("WARNING: could not create file of non string type name");
        end
    end

    assert(love.filesystem.mount(exepath, "temp"), "Could not mount source to base directory");

	for _, v in ipairs(love.filesystem.getDirectoryItems("temp")) do
		if string.match(v, "^.+(%..+)$") == '.dll' and love.filesystem.isFile("temp/" .. v) then
			love.filesystem.write(v, love.filesystem.newFileData("temp/" .. v));
		end
	end
	love.filesystem.unmount("temp");

    io.popen('""' .. savpath .. '/lovec.exe" "' .. savpath .. '/.""');
end
function OpenWindow:openUnfused(files, name)
    local prevIdentity = love.filesystem.getIdentity();
    love.filesystem.setIdentity(name);

	self:emptyPath("");

    local savpath = love.filesystem.getSaveDirectory();

    for k, v in pairs(files) do
        if type(k) == "string" then
            local name = string.match(k, "^.+%..+$") or k .. ".lua";

			assert(self:checkAvailableFilename(name)); -- has its error message built in

            if string.find(name, "/") then
                love.filesystem.createDirectory(string.match(name, "^(.+)/"));
            end

            love.filesystem.write(name, v);
        else
            print("WARNING: could not create file of non string type name");
        end
    end

    io.popen('""' .. self.unfilteredArgs[-2] .. '" "' .. savpath .. '/.""');

    love.filesystem.setIdentity(prevIdentity);
end

function OpenWindow:emptyPath(dir)
	if love.filesystem.getInfo(dir, "directory") then
        for _, v in ipairs(love.filesystem.getDirectoryItems(dir)) do
            self:emptyPath(dir .. '/' .. v);
            love.filesystem.remove(dir .. '/' .. v);
        end
	end
end

function OpenWindow:newWindow(files)
    assert(type(files) == "table", "cannot create window without files");
    assert(files.main ~= nil, "cannot create a window without a main.lua file");

    if type(files.main) == "string" then
        files.main = "require(\"" .. COVER_FILENAME .. "\"); -- automagicaly generated code\r\n" .. files.main;
    elseif files.main.type and files.main:type() == "File" then
		files.main = "require(\"" .. COVER_FILENAME .. "\"); -- automagicaly generated code\r\n" .. files.main:read();
	else
        error("havent added support for main.lua file not being a string or love2d 'File'");
    end

    local name = files.name or "UNNAMED";
    local callback = files.callback;
    files.name = nil;
    files.callback = nil;

    if not files.conf then
        files.conf = DefaultConf(name);
    end

    assert(self.windows[name] == nil, "cannot create window named '" .. name .. "' because a window with that name already exists");
    assert(files[INJECT_FILENAME] == nil, "cannot have a file named: '" .. INJECT_FILENAME .. "'");
    assert(files[COVER_FILENAME] == nil, "cannot have a file named: '" .. COVER_FILENAME .. "'")

    files[COVER_FILENAME] = CoverFile(INJECT_FILENAME);
    files[INJECT_FILENAME] = InjectFile(name);

    if love.filesystem.isFused() then
        self:openFused(files);
    else
        self:openUnfused(files, name);
    end

    self.windows[name] = {callback = callback, queue = {}};
end

function OpenWindow:closeWindow(name)
    if not self.windows[name] then
        return;
    end

    table.insert(self.windows[name].queue, {message = window_event.__CLOSE, channel = 0});
end

function OpenWindow:tellWindow(windowname, data)
    if not self.windows[windowname] then
        return;
    end

    table.insert(self.windows[windowname].queue, {message = data, channel = 1});
end

return setmetatable({}, OpenWindow);
