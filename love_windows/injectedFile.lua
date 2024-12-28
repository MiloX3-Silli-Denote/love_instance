local InjectedFile = [[
-- automagicaly generated code (yes all of it :3c)

local MY_NAME = "__NAME__";
local enet = require("enet");

local Communicator = {};
Communicator.__index = Communicator;

function Communicator:init()
    print("init??");
    self.host = enet.host_create();
    self.server = self.host:connect("localhost:1345", 2);
    self.toClose = false;
end

function Communicator:_server_receive(event)
    if event.peer ~= self.server then
        return;
    end

    if event.channel == 1 then
        if love.recieve then
            love.recieve(event.data);
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

    while event ~= nil do
        if event.type == "receive" then
            self:_server_receive(event);
        elseif event.type == "disconnect" then
            self:_server_disconnect(event);
        elseif event.type == "connect" then
            event.peer:send("__CONNECT " .. MY_NAME, 0)
            print("child: CONNECTED!!!");
        end

        event = self.host:service();
    end

    if self.toClose then
        love.event.quit();
    end
end

function Communicator:close()
    if self.server then
        self.server:disconnect();
    end
end
function Communicator:collapse(msg)
    if msg then
        self:send(msg);
    end

    self.toClose = true;
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