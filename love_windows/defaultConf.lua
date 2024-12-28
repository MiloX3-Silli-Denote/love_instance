local DefaultConf = [[
function love.conf(t)
    t.title = "__NAME__";
    t.version = "11.4";
    t.console = false; -- if console is active it wont open a new console if one is already open but will print to any other opened console (ie the console the parent love instance opened
    t.window.width = 800;
    t.window.height = 600;
    t.vSync = false;
end
]];

function getDefaultConf(name)
    name = name or "";

    local ret = string.gsub(DefaultConf, "__NAME__", name);

    return ret;
end

return getDefaultConf;
