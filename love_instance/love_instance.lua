local path = string.match((...), ".+[./]") or "";

local OpenWindow = require(path .. "windowHandler");

function love.run()
    OpenWindow:init(arg);

	if love.load then
        love.load(love.arg.parseGameArguments(arg), arg);
    end

	-- We don't want the first frame's dt to include time taken by love.load.
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
                        OpenWindow:closeAll();
						return a or 0;
					end
				end

				love.handlers[name](a,b,c,d,e,f);
			end
		end

		if love.timer then
            dt = love.timer.step();
        end

        OpenWindow:update();
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

local utf8 = require("utf8");
local function error_printer(msg, layer)
	print((debug.traceback("Error: " .. tostring(msg), 1 + (layer or 1)):gsub("\n[^\n]+$", "")));
end
function love.errorhandler(msg)
    OpenWindow:closeAll();

	msg = tostring(msg);
	error_printer(msg, 2);

	if not love.window or not love.graphics or not love.event then
		return;
	end

	if not love.graphics.isCreated() or not love.window.isOpen() then
		local success, status = pcall(love.window.setMode, 800, 600);

		if not success or not status then
			return;
		end
	end

	-- reset state.
	if love.mouse then
		love.mouse.setVisible(true);
		love.mouse.setGrabbed(false);
		love.mouse.setRelativeMode(false);

		if love.mouse.isCursorSupported() then
			love.mouse.setCursor();
		end
	end
    -- stop all joystick vibrations.
	if love.joystick then
		for i,v in ipairs(love.joystick.getJoysticks()) do
			v:setVibration();
		end
	end
    -- stop audio
	if love.audio then
        love.audio.stop();
    end

	love.graphics.reset();
	local font = love.graphics.setNewFont(14);
	love.graphics.setColor(1,1,1);

	local trace = debug.traceback();

	love.graphics.origin();

	local sanitizedmsg = {};
	for char in msg:gmatch(utf8.charpattern) do
		table.insert(sanitizedmsg, char);
	end
	sanitizedmsg = table.concat(sanitizedmsg);

	local err = {};

	table.insert(err, "Error\n");
	table.insert(err, sanitizedmsg);

	if #sanitizedmsg ~= #msg then
		table.insert(err, "Invalid UTF-8 string in error message.");
	end

	table.insert(err, "\n");

	for l in trace:gmatch("(.-)\n") do
		if not l:match("boot.lua") then
			l = l:gsub("stack traceback:", "Traceback\n");
			table.insert(err, l);
		end
	end

	local p = table.concat(err, "\n");

	p = p:gsub("\t", "");
	p = p:gsub("%[string \"(.-)\"%]", "%1");

	local function draw()
		if not love.graphics.isActive() then
            return;
        end

		local pos = 70;
		love.graphics.clear(89/255, 157/255, 220/255);
		love.graphics.printf(p, pos, pos, love.graphics.getWidth() - pos);
		love.graphics.present();
	end

	local fullErrorText = p;
	local function copyToClipboard()
		if not love.system then
            return;
        end

		love.system.setClipboardText(fullErrorText);
		p = p .. "\nCopied to clipboard!";
	end

	if love.system then
		p = p .. "\n\nPress Ctrl+C or tap to copy this error";
	end

	return function()
		love.event.pump();

		for e, a, b, c in love.event.poll() do
			if e == "quit" then
				return 1;
			elseif e == "keypressed" and a == "escape" then
				return 1;
			elseif e == "keypressed" and a == "c" and love.keyboard.isDown("lctrl", "rctrl") then
				copyToClipboard();
			elseif e == "touchpressed" then
				local name = love.window.getTitle();

				if #name == 0 or name == "Untitled" then
                    name = "Game";
                end

				local buttons = {"OK", "Cancel"};

				if love.system then
					buttons[3] = "Copy to clipboard";
				end

				local pressed = love.window.showMessageBox("Quit "..name.."?", "", buttons);

				if pressed == 1 then
					return 1;
				elseif pressed == 3 then
					copyToClipboard();
				end
			end
		end

		draw();

		if love.timer then
			love.timer.sleep(0.1);
		end
	end
end

return OpenWindow;
