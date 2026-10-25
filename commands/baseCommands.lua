local baseCommands = {}
local Dotenv = require("dotenv")
local http = require("coro-http")
local json = require("json")

local function stripeServicePost(path, payload)
    local baseUrl = Dotenv.get_value("STRIPE_SERVICE_URL")
    local serviceToken = Dotenv.get_value("STRIPE_SERVICE_TOKEN")
    assert(baseUrl and baseUrl ~= "", "STRIPE_SERVICE_URL is not configured")
    assert(serviceToken and serviceToken ~= "", "STRIPE_SERVICE_TOKEN is not configured")

    local response, body = http.request("POST", baseUrl .. path, {
        { "Content-Type", "application/json" },
        { "Authorization", "Bearer " .. serviceToken }
    }, json.encode(payload))

    if not response or response.code < 200 or response.code >= 300 then
        error("Stripe service returned HTTP " .. tostring(response and response.code or "no response"))
    end
    return json.decode(body)
end

baseCommands.hello = {
    description = "Say hello.",
    exec = function(message)
        message.channel:send("world!")
    end
}

baseCommands.ping = {
    description = "Check whether the bot is online.",
    exec = function(message)
        message.channel:send("Pong!")
    end
}

baseCommands.help = {
    description = "List available commands.",
    exec = function(message)
        local names = {}
        for name in pairs(baseCommands) do
            names[#names + 1] = name
        end
        table.sort(names)

        local lines = { "**Flushybot commands**" }
        for _, name in ipairs(names) do
            lines[#lines + 1] = string.format("`!%s` — %s", name, baseCommands[name].description)
        end
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
            message.channel:send("I couldn't apply the timeout. Check that I have **Moderate Members** permission and my role is high enough.")
            return
        end

        local timeoutUntil = os.date("!%Y-%m-%dT%H:%M:%SZ", os.time() + minutes * 60)
        local registered, registerErr = pcall(function()
            stripeServicePost("/internal/timeouts", {
                guildId = message.guild.id,
                userId = message.author.id,
                timeoutUntil = timeoutUntil
            })
        end)
        if not registered then
            print("Could not register timeout for early unmute: " .. tostring(registerErr))
        end

        local reply = string.format("%s rolled a **%d-minute timeout**. Good luck out there.", message.author.mentionString, minutes)
        if registered then
            reply = reply .. " Use `!donate [2|3|4]` if you'd like to pay $2–$4 to end this Muteoulette timeout early."
        end
        message.channel:send(reply)
    end
}

baseCommands.donate = {
    description = "Pay $2, $3, or $4 to end your active Muteoulette timeout early.",
    exec = function(message)
        if not message.guild then
            message.channel:send("Use this command in the server where you were timed out.")
            return
        end

        local amount = tonumber(message.content:match("^!donate%s*(%d*)$"))
        if amount == nil or amount == 0 then amount = 3 end
        if amount ~= 2 and amount ~= 3 and amount ~= 4 then
            message.channel:send("Usage: !donate [2|3|4] — choose a $2, $3, or $4 payment.")
            return
        end

        local ok, result = pcall(function()
            return stripeServicePost("/internal/checkout", {
                guildId = message.guild.id,
                userId = message.author.id,
                amountCents = amount * 100
            })
        end)
        if not ok then
            print("Could not create Stripe checkout: " .. tostring(result))
            message.channel:send("I couldn't create a checkout link. Make sure the Stripe service is configured and that you have an active Muteoulette timeout.")
            return
        end
        if not result.url then
            message.channel:send("No checkout link was returned. Try again later.")
            return
        end

        message.author:send(string.format("Your $%d early-unmute checkout link: %s\nYour timeout is only removed after Stripe confirms payment.", amount, result.url))
        message.channel:send(message.author.mentionString .. ", I sent your secure checkout link in a DM. Check your privacy settings if you don't receive it.")
    end
}

baseCommands.msg = {
    description = "Repeat your message (use !msg <text>).",
    exec = function(message)
        local text = message.content:match("^!msg%s+(.+)$")
        if not text then
            message.channel:send("Usage: !msg <text>")
            return
        end
        message.channel:send(text)
    end
}

return baseCommands
