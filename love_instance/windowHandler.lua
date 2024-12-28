local enet = require("enet");

local path = string.match((...), "(.+)[./]") or "";

local DefaultConf = require(path .. "/defaultConf");
local InjectFile = require(path .. "/injectedFile");
local CoverFile = require(path .. "/coverFile");

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
    for i, v in ipairs(self.peers) do
        v:send(window_event.__CLOSE, 0);
    end

    if self.server then
        self.server:broadcast(window_event.__CLOSE, 0); -- channel 0 for event communication
    end
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

        print(form .. "'", "." .. data .. ".");

        if form == window_event.__CONNECT then
            if self.windows[data] then
                self.windows[data].peer = peer;
            end
        else
            print("NEW MESSAGE : '" .. msg .. "'");
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
        print(event.channel, event.data, event.type);

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

function OpenWindow:openFused(files)
    local savpath = love.filesystem.getSaveDirectory();
    local exepath = love.filesystem.getSourceBaseDirectory();
	love.filesystem.write('lovec.exe', love.filesystem.newFileData('lovec.exe'));

    for k, v in pairs(files) do
        if type(k) == "string" then
            local name = string.match(k, "^.+%..+$") or k .. ".lua";
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

    local savpath = love.filesystem.getSaveDirectory();

    for k, v in pairs(files) do
        if type(k) == "string" then
            local name = string.match(k, "^.+%..+$") or k .. ".lua";
            love.filesystem.write(name, v);
        else
            print("WARNING: could not create file of non string type name");
        end
    end

    io.popen('""' .. self.unfilteredArgs[-2] .. '" "' .. savpath .. '/.""');

    love.filesystem.setIdentity(prevIdentity);
end

function OpenWindow:newWindow(files)
    assert(type(files) == "table", "cannot create window without files");
    assert(files.main ~= nil, "cannot create a window without a main.lua file");

    if type(files.main) == "string" then
        files.main = "Parent_Window = require(\"" .. COVER_FILENAME .. "\"); -- automagicaly generated code\r\n" .. files.main;
    else
        error("havent added support for main.lua file not being a string");
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
    print(name);
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
