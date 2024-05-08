-- baseCommands.lua
    local baseCommands = {
        ["hello"] = {
            description = "Answers with world.",
            exec = function(message)
                message.channel:send("world!")
            end
        },
        ["ping"] = {
            description = "Pings the bot.",
            exec = function(message)
                message.channel:send("Pong!")
            end
        }
    }
    return baseCommands
