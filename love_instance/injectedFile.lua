local InjectedFile = [[
-- automagicaly generated code (yes all of it :3c)

local MY_NAME = "__NAME__";
local enet = require("enet");

function love.getInstanceName()
    return MY_NAME;
end

local Communicator = {};
Communicator.__index = Communicator;

function Communicator:init()
    self.host = enet.host_create();
    self.server = self.host:connect("localhost:1345", 2);
end

function Communicator:_server_receive(event)
    if event.peer ~= self.server then
        return;
    end

    if event.channel == 1 then
        if love.receive then
            love.receive(event.data);
        end
    else
        if event.data == "__CLOSE" then
            self:collapse();
        end
    end
end
function Communicator:_server_disconnect(event)
    if event.peer ~= self.server then
        return;
    end

    self:collapse();
end

function Communicator:update()
    local event = self.host:service();
    local maxCount = 10000;

    while event ~= nil do
        if event.type == "receive" then
            self:_server_receive(event);
        elseif event.type == "disconnect" then
            self:_server_disconnect(event);
        elseif event.type == "connect" then
            event.peer:send("__CONNECT " .. MY_NAME, 0)
        end

        maxCount = maxCount - 1;
        if maxCount <= 0 then
            break;
        end

        event = self.host:service();
    end
end

function Communicator:close()
    if self.server then
        self.server:disconnect();
        self.host:flush();
    end
end
function Communicator:collapse(msg)
    if msg then
        self:send(msg);
    end

    love.event.quit();
end

function Communicator:send(data)
    self.server:send(data, 1);
end

return setmetatable({}, Communicator);
]];

function getInjectedFile(name)
    name = name or "";

    local ret = string.gsub(InjectedFile, "__NAME__", name);

    return ret;
end

return getInjectedFile;
