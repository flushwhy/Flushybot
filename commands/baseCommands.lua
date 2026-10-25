local baseCommands = {}

baseCommands.hello = {
    description = "Say hello.",
    exec = function(message)
        message.channel:send("world!")
    end
}

baseCommands.ping = {
    description = "Check whether Flushybot is online.",
    exec = function(message)
        message.channel:send("Pong!")
    end
}

baseCommands.help = {
    description = "List available commands.",
    exec = function(message)
        local lines = { "**Flushybot commands**" }
        for name, command in pairs(baseCommands) do
            lines[#lines + 1] = string.format("`!%s` — %s", name, command.description)
        end
        table.sort(lines, function(a, b) return a < b end)
        message.channel:send(table.concat(lines, "\n"))
    end
}

baseCommands.muteoulette = {
    description = "Roll for no mute or a 5, 10, 15, or 20 minute server timeout.",
    exec = function(message)
        if not message.guild or not message.member then
            message.channel:send("Muteoulette only works in a server.")
            return
        end

        local roll = math.random(1, 5)
        if roll == 1 then
            message.channel:send(message.author.mentionString .. " escaped muteoulette. No mute this time.")
            return
        end

        local minutes = (roll - 1) * 5
        local ok, err = pcall(function()
            message.member:setTimeout(minutes * 60 * 1000)
        end)

        if not ok then
            print("muteoulette failed: " .. tostring(err))
            message.channel:send("I couldn't apply the timeout. Check that I have the Moderate Members permission and that my role is high enough.")
            return
        end

        message.channel:send(string.format("%s rolled a **%d-minute timeout**. Good luck out there.", message.author.mentionString, minutes))
    end
}

baseCommands.msg = {
    description = "Repeat your message (use !msg <text>).",
    exec = function(message)
        local text = message.content:match("^!msg%s+(.+)$")
        if not text then
            message.channel:send("Usage: `!msg <text>`")
            return
        end
        message.channel:send(text)
    end
}

return baseCommands
