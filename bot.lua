local discordia = require("discordia")
local Dotenv = require("dotenv")

Dotenv.load_env(".env")
discordia.extensions()

local token = Dotenv.get_value("TOKEN")
assert(token and token ~= "", "Missing TOKEN in .env")

local client = discordia.Client()
local prefix = "!"
local commands = require("commands.baseCommands")

client:on("ready", function()
    print("Flushybot is ready.")
end)

client:on("messageCreate", function(message)
    if message.author.bot or not message.content or message.content:sub(1, #prefix) ~= prefix then
        return
    end

    local name = message.content:sub(#prefix + 1):match("^(%S+)")
    local command = name and commands[name:lower()]
    if not command then return end

    coroutine.wrap(function()
        local ok, err = pcall(command.exec, message)
        if not ok then
            print(string.format("Command %s failed: %s", name, tostring(err)))
            message.channel:send("That command hit an error. Check the bot logs.")
        end
    end)()
end)

client:run("Bot " .. token)
