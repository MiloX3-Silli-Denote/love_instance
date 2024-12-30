local enet = require("enet");

local path = string.match((...), ".+[./]") or "";

local Window = require(path .. "window");
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
    __DISCONNECTED = "__DISCONNECTED";
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
        local form, data = string.match(msg, "^(__[^ ]+) (.*)$");

        if form == window_event.__CONNECT then
            if self.windows[data] then
                self.windows[data]:setPeer(peer);
            end
        else
            print("NEW EVENT MESSAGE (not good) : '" .. msg .. "'");
        end

        return;
    end

    table.insert(self.peers[peer].queue, {message = event.data, channel = event.channel});
end

function OpenWindow:update()
    for k, v in pairs(self.windows) do
        v:update();

        if not v.useable and not v:isOpen() then
            v:clearIdentity(); -- unload
            self.windows[k] = nil;
        end
    end

    local event = self.server:service();
    local maxCount = 1000;

    while event ~= nil do
        if event.type == event_type.receive then
            self:_server_receive(event);
        elseif event.type == event_type.connect then
            self:_server_connect(event);
        elseif event.type == event_type.disconnect then
            self:_server_disconnect(event);
        end

        maxCount = maxCount - 1;
        if maxCount <= 0 then
            break;
        end

        event = self.server:service();
    end

    for _, v in pairs(self.windows) do
        if v.peer and self.peers[v.peer] then
            local del = false;

            while #self.peers[v.peer].queue > 0 do
                if v:getMessage(table.remove(self.peers[v.peer].queue, 1)) then
                    del = true;
                end
            end

            if del then
                self.peers[v.peer] = nil;
            end
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

    local window = Window.new(files, name, callback, self.unfilteredArgs);

    self.windows[name] = window;

    return window;
end

function OpenWindow:checkName(name)
    return self.windows[name] == nil;
end

return setmetatable({}, OpenWindow);
