local DefaultConf = [[
function love.conf(t)
    t.title = "__NAME__";
    t.version = "11.4";

    t.console = true;
    -- if console is active it wont open a new console
    -- it will print to the opened console if one is already open
    -- if console is dissabled but a 'print()' attempt is made then it will *SOMETIMES* crash (very finickey and iconsistent)

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
