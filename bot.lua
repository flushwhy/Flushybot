local discordia = require('discordia')
local client = discordia.Client()
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


client:on("messageCreate", function(message)
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
