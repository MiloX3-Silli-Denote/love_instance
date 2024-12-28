local OpenWindow = {};
OpenWindow.__index = OpenWindow;

--! THIS IS SELF MODYFYING CODE, DO NOT EVEN THINK ABOUT TOUCHING IT
--! IMPOSSIBLE TO DEBUG AND MORE IMPOSSIBLE TO UNDERSTAND (IDK HOW I GOT IT TO WORK)
--! MARK: NO TOUCHING
local instanceWindow = [[
local ignore = false;

function love.finalize(args)
    if ignore then
        return;
    end

    local str = "";

    for k, v in pairs(args) do
        assert(string.find(k, "|") == nil, "cannot have '|' in string name, tried name: " .. k);
        str = str .. k .. "|" .. v .. "\r\n";
    end

    str = str .. "__close|true";

    local prevIdentity = love.filesystem.getIdentity();
    love.filesystem.setIdentity("communication");
    love.filesystem.write(name .. "_ret.txt", str);
    love.filesystem.setIdentity(prevIdentity);

    ignore = true;

    love.event.quit();
end

local windowUpdate = function()
    local prevIdentity = love.filesystem.getIdentity();
    love.filesystem.setIdentity("communication");

    if not love.filesystem.getInfo(name .. ".txt") then
        love.event.quit();
    else
        for line in love.filesystem.lines(name .. ".txt") do
            local name, state = string.match(line, "^(.*)|(.*)$");

            if name == "__close" then
                if state == "true" then
                    love.event.quit();
                end
            end

            if love.instruction then
                love.instruction(name, state);
            end
        end
    end

    love.filesystem.setIdentity(prevIdentity);
end

function love.run()
	if love.load then
        love.load(love.arg.parseGameArguments(arg), arg);
    end

	if love.timer then
        love.timer.step();
    end

	local dt = 0;

	return function()
		if love.event then
			love.event.pump();

			for name, a,b,c,d,e,f in love.event.poll() do
				if name == "quit" then
					if not love.quit or not love.quit() then
                        love.finalize();

						return a or 0;
					end
				end

				love.handlers[name](a,b,c,d,e,f);
			end
		end

		if love.timer then
            dt = love.timer.step();
        end

        windowUpdate();
		if love.update then
            love.update(dt);
        end

		if love.graphics and love.graphics.isActive() then
			love.graphics.origin();
			love.graphics.clear(love.graphics.getBackgroundColor());

			if love.draw then
                love.draw();
            end

			love.graphics.present();
		end

		if love.timer then
            love.timer.sleep(0.001);
        end
	end
end
local prevErr = love.errorhandler;
function love.errorhandler(msg)
    love.finalize();

    return prevErr(msg);
end]];

local openWindows = {};

local prevErrHandler = love.errorhandler;
function love.errorhandler(msg)
    OpenWindow.closeAll();

    return prevErrHandler(msg);
end

function OpenWindow.closeAll()
    local prevIdentity = love.filesystem.getIdentity();

    love.filesystem.setIdentity("communication");
    for _, v in ipairs(openWindows) do
        love.filesystem.write(v.name .. ".txt", "__close|true");
    end

    for _, v in ipairs(openWindows) do
        love.filesystem.setIdentity(v.name);
        OpenWindow.recurseRemove("");
    end

    love.filesystem.setIdentity(prevIdentity);
end
function OpenWindow.clear()
    local prevIdentity = love.filesystem.getIdentity();

    love.filesystem.setIdentity("communication");
    OpenWindow.recurseRemove("");

    for _, v in ipairs(openWindows) do
        love.filesystem.setIdentity(v.name);
        OpenWindow.recurseRemove("");
    end

    love.filesystem.setIdentity(prevIdentity);
end
function OpenWindow.recurseRemove(dir)
    local dirItems = love.filesystem.getDirectoryItems(dir);

    for _, v in ipairs(dirItems) do
        local fileName = dir .. "/" .. v;

        local info = love.filesystem.getInfo(fileName);

		if info then
			if info.type == "directory" then
                OpenWindow.recurseRemove(fileName);
			end

            love.filesystem.remove(fileName);
		end
    end

    love.filesystem.remove(dir);
end

function OpenWindow.load()
    OpenWindow.clear();
end

function OpenWindow.new(files)
    assert(files.main ~= nil, "cannot create new window without main file");

    if type(files.main) == "string" then
        files.main = "require(\"instanceWindow\"); -- automatically generated code\r\n" .. files.main;
    elseif files.main:typeOf("File") then
        files.main = "require(\"instanceWindow\"); -- automatically generated code\r\n" .. files.main:read();
    elseif files.main:typeOf("FileData") then
        files.main = "require(\"instanceWindow\"); -- automatically generated code\r\n" .. files.main:getString(); -- idk
    end

    local name = files.name;
    local callback = files.callback;
    files.name = nil;
    files.callback = nil;

    assert(type(name) == "string", "new window must have a directory name, (set 'name' to a string)");

    local prevIdentity = love.filesystem.getIdentity();

    love.filesystem.setIdentity("communication");
    assert(love.filesystem.getInfo(name .. ".txt") == nil, "cannot open new window on preexisting name");
    love.filesystem.write(name .. ".txt", "__close|false");
    love.filesystem.write(name .. "_ret.txt", "__close|false");
    love.filesystem.setIdentity(name);

    files.instanceWindow = "local name = \"" .. name .. "\"; -- automatically generated code\r\n" .. instanceWindow;

    if love.filesystem.isFused() then
        OpenWindow.openFused(files);
    else
        OpenWindow.openUnfused(files);
    end

    table.insert(openWindows, {name = name, callback = callback});
    print(name);

    love.filesystem.setIdentity(prevIdentity);
end

function OpenWindow.openFused(files)
    files.unfilteredArgs = nil;

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
function OpenWindow.openUnfused(files)
    local unfilteredArgs = files.unfilteredArgs;
    files.unfilteredArgs = nil;

    assert(unfilteredArgs ~= nil, "must pass unfiltered args for non fused instances, (the second argument passed to love.load())");

    local savpath = love.filesystem.getSaveDirectory();

    for k, v in pairs(files) do
        if type(k) == "string" then
            local name = string.match(k, "^.+%..+$") or k .. ".lua";
            love.filesystem.write(name, v);
        else
            print("WARNING: could not create file of non string type name");
        end
    end

    io.popen('""' .. unfilteredArgs[-2] .. '" "' .. savpath .. '/.""');
end

function OpenWindow.update()
    local previdentity = love.filesystem.getIdentity();
    love.filesystem.setIdentity("communication");

    for _, v in ipairs(openWindows) do
        if not love.filesystem.getInfo(v.name .. "_ret.txt") then
            love.filesystem.remove(v.name .. ".txt");
            love.filesystem.remove(v.name .. "_ret.txt");
        else
            for line in love.filesystem.lines(v.name .. "_ret.txt") do
                local name, state = string.match(line, "^(.*)|(.*)$");

                if name == "__close" then
                    if state == "true" then
                        love.filesystem.remove(v.name .. ".txt");
                        love.filesystem.remove(v.name .. "_ret.txt");
                    end
                elseif v.callback then
                    v.callback(name, state);
                end
            end
        end
    end

    love.filesystem.setIdentity(previdentity);
end
function OpenWindow.quit()
    OpenWindow.closeAll();
end

function OpenWindow.closeWindow(name)
    for i, v in ipairs(openWindows) do
        if v.name == name then
            break;
        elseif i == #openWindows then
            return;
        end
    end

    local prevIdentity = love.filesystem.getIdentity();
    love.filesystem.setIdentity("communication");
    love.filesystem.write(name .. ".txt", "__close|true");
    love.filesystem.setIdentity(prevIdentity);
end

return OpenWindow;