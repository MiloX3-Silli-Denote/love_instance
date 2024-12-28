# love_instance
better version of my love_windows project, open new instances of love in other windows with communication between the new window and the parent window
(I have no idea if compiling love_instance into a .love file will break it but there is code made for it to keep working so hopefully not)

## Usage
download the love_instance folder and place it into your project (license is in the folder aswell so dont worry)
place ```Love_Instance = require("love_instance/love_instance");``` in your main script

#### IMPORTANT NOTE
if you are using love_instance in your project then you CANNOT redefine love.run or love.errorhandler/love.errorhand, in a later revision I will have an optional version that allows you to redefine these with exceptions but in this version, the love_instance redefines them to ensure windows are culled correctly on errors and crashes

to make a new instance of love then you must create a table containing all of the files you want along with some additional information like so:
```lua
Love_Instance = require("love_instance/love_instance");

local newInstance = {
  main = mainFile;
  conf = confFile;
  ["textures/player_sprite.png"] = playerSpriteFile;
  player = playerFile;

  name = "platforming game"; -- exception 1

  callback = function(msg) -- exception 2
    print(msg);
  end;
};
```
each file in the new project must be a string (will be updated to allow for files and in the future but for now you can just do file:read() to get it as a string) and will use its key in the table to determine the filename used.
ie: ```main = mainFile;``` has the key "main" so it will be copied to main.lua (if filetype is not specified then love_instance assumes .lua)
and ```["textures/player_sprite.png"] = playerSpriteFile;``` will write to to player_sprite.png file in the textures directory in the new window (if a file type IS specified then it will use that, the .png in this case)

excpetion 1: the 'name' key in the table is reserved for the name of the project, love_instance will write the files to this directory in the appdata and if no conf.lua s specified it will use this as the name of the window, if 'name' isnt defined then it will default to "UNNAMED", but there can only be one window with each name so dont open another unnamed winodw
exception 2: the 'callback' key in the table is reserved for communication between the windows, when the window sends information back to the parent window it will call the 'callback' function with the message as the argument

### Create a Window
call ```Love_Instance:newWindow(files);``` with the table of files to open a new window
```lua
local newInstance = {
  main = mainFile;
  conf = confFile;
  ["textures/player_sprite.png"] = playerSpriteFile;
  player = playerFile;

  name = "platforming game";

  callback = function(msg)
    print(msg);
  end;
};

Love_Instance:newWindow(newInstance);
```

### Send commands to and from the new window
after creating a window, Love_Instance will remember it by the name that was assigned (remember that unnamed window default to "UNNAMED")
to send a command to the new window you can call ```Love_Instance:tellWindow(windowName, message);``` with the name of the window and a string to be sent
in order for an instance to read and react to the commands, you must define a new ```love.receive(msg)``` function to be called whenever a new command is sent (remember, only strings can be sent so get creative with how you send and interpret other data types).

a window instance can send commands back to the parent window from the new ```love.send(msg);``` and ```love.collapse(msg);``` functions
```love.send(msg);``` will send a string back to the parent window which will call the callback function with the string as the argument, and ```love.collapse(msg);``` will do the same but will also close the window (kind of like a ```return msg;``` but for the entire window (note that calling ```love.event.quit();``` shortly after calling ```love.send(msg);``` may cause the message to not get sent properly).

whenever the new window instance closes, whether it be from a ```love.collapse(msg);``` call or from the user closing the window or a ```love.event.quit();``` call, the callback function will be called with "close" as an argument
