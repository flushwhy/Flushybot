discordia = require('discordia')
client = discordia.Client()
local Dotenv = require('dotenv')

-- commands
local baseCommands = require("commands.baseCommands")

Dotenv.load_env(".env")

discordia.extensions() -- load all helpful extensions


function Commands(prefix, ...)
    local commands = {}
    for _, cmds in ipairs({...}) do
        for key, value in pairs(cmds) do
            commands[prefix .. key] = value
        end
    end
    return commands
end

local prefix = "!"
local commands = Commands(prefix, baseCommands)

--[[
    This is basiscally a listen to ALL messages, and react to the commands.
    That are passed by the Commands() function above this. If everything goes well.
    It will excute the "exec" function of the command. That can be found in commands\<name>Commands.lua.
]]
client:on("messageCreate", function(message)

    print ("Message: " .. message.content)
    if message.author.bot then
        return
    end

    for command, value in pairs(commands) do
        if message.content == command then
            value.exec(message)
        end
    end
end)

client:run("Bot " .. Dotenv.get_value("TOKEN"))
