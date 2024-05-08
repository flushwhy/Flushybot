local discordia = require('discordia')
local client = discordia.Client()
local Dotenv = require('dotenv')

discordia.extensions()

Dotenv.load_env(".env")

discordia.extensions() -- load all helpful extensions

local prefix = '!'

local baseCommands = require("commands.baseCommands")

local commands = {}

for key, value in pairs(baseCommands) do
    commands[prefix .. key] = value
end

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