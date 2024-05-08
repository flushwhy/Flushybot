-- baseCommands.lua
    local baseCommands = {
        ["hello"] = {
            description = "Answers with world.",
            exec = function(message)
                print("Executing hello command.")
                message.channel:send("world!")
            end
        }
    }
    return baseCommands
