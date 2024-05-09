-- baseCommands.lua
math.randomseed(os.time())

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
    },
    ["ban"] = {
        description = "Bans a user.",
        exec = function(message)
            --TODO: Figure how to ban people with a reason.
            if message.member:hasPermission("banMembers") and message.guild then
                client.banMembers(message.guild, message.mentions[1].id)
            end
        end
    },
    ["kickoulette"] = {
        description = "You pick a number between 1 and 10 and I will kick you. If you pick the same number as me, I will kick you.",
        exec = function(message)
            local numberToGuess = math.random(1, 10)

            message.channel:send(
                "Pick a number between 1 and 10, and I'll kick you. If you pick the same number as me, I will kick you.")
            --TODO: Figure out why Client here doesn't work.
                client:on('messageCreate', function(msg)
                if msg.author == message.author then
                    local guess = tonumber(msg.content)
                    if guess == numberToGuess then
                        msg.channel:send("You got it! I kicked you.")
                        msg.member:kick()
                    else
                        msg.channel:send("Nope, it was " .. numberToGuess)
                    end
                end
            end)
        end
    },
    ["msg"] = {
        description = "Returns the message you sent.",
        exec = function(message)
            --TODO: Message.content won't send in discord. Why?
            print("Message: " .. message.content)
            message.channel:send(message.content)
        end
    }
}
return baseCommands
