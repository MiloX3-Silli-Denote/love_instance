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

excpetion 1: the 'name' key in the table is reserved for the name of the project, love_instance will write the files to this directory in the appdata and if no conf.lua s specified it will use this as the name of the window
exception 2: the 'callback' key in the table is reserved for communication between the windows, when the window sends information back to the parent window it will call the 'callback' function with the message as the argument

### Create a Window
```lua
```
