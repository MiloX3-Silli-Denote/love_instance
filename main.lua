-- testing file

OpenWindow = require("love_instance/love_instance");

local mainFile = [[
local b = 0;

function love.receive(msg)
    print("child recieved: " .. msg);

    if msg == "CYAN" then
        b = 1;
    elseif msg == "GREEN" then
        b = 0;
    end
end

local num = 0

function love.load()
    print("child: opened");
end

function love.update(dt)
    num = num + dt;

    if love.keyboard.isDown("p") then
        love.send("kys :3");
    end

    if love.keyboard.isDown("o") then
        love.collapse("check out my kyles dad impression");
    end
end

function love.draw()
    love.graphics.print(tostring(num), 5, 10);

    love.graphics.setColor(1,0,0);
    love.graphics.rectangle("fill", 40, 30, 100, 70);

    love.graphics.setColor(0,1,b);
    love.graphics.rectangle("fill", 120, 80, 60, 40);
end
]];

files = {
    main = mainFile;
    name = "something_stupid";
    callback = function(msg)
        print("callback: " .. msg);
    end;
};

local widnow = nil;

function love.load()
    widnow = OpenWindow:newWindow(files);

    print(widnow);
end

function love.update(dt)
    if love.keyboard.isDown("g") then
        widnow:open();
    end

    if love.keyboard.isDown("q") then
        widnow:send("CYAN");
    end

    if love.keyboard.isDown("w") then
        widnow:send("GREEN");
    end

    if love.keyboard.isDown("e") then
        widnow:close();
    end
end