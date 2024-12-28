local DefaultConf = [[
function love.conf(t)
    t.title = "__NAME__";
    t.version = "11.4";
    t.console = true;
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