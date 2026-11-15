-- spikes/TradebookNet/Net.lua
-- Throwaway test: can Tradebook copies share NPC data through addon messages in Forever?
-- Answers: does a hidden custom channel work for addon messages, can it be hidden from chat,
-- what does the throttle allow, does a 255-character message go through, and does any of it
-- work inside a dungeon. Everything is saved to TradebookNetDB (/reload to write it).
-- Privacy: senders are only logged as "self" or "other", never by name.

local PREFIX = "TBNETTEST"
local CHANNEL = "TradebookNetTest"
local NL = "\n"

TradebookNetDB = TradebookNetDB or {}
local db
local run -- the test in progress (also saved)

local function say(msg) print("|cffd9a54aTB Net|r: " .. msg) end

local function resultName(r)
    if type(r) == "number" and Enum and Enum.SendAddonMessageResult then
        for k, v in pairs(Enum.SendAddonMessageResult) do
            if v == r then return k end
        end
    end
    return tostring(r)
end

local function channelID()
    local id = GetChannelName(CHANNEL)
    return (id and id > 0) and id or nil
end

local function hideChannel()
    local how = "none"
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local cf = _G["ChatFrame" .. i]
        if cf then
            if ChatFrame_RemoveChannel then
                pcall(ChatFrame_RemoveChannel, cf, CHANNEL)
                how = "ChatFrame_RemoveChannel"
            elseif ChatFrameUtil and ChatFrameUtil.RemoveChannel then
                pcall(ChatFrameUtil.RemoveChannel, cf, CHANNEL)
                how = "ChatFrameUtil.RemoveChannel"
            end
        end
    end
    return how
end

local function send(tag, chatType, target, text)
    local ok, r = pcall(C_ChatInfo.SendAddonMessage, PREFIX, text, chatType, target)
    local rec = { tag = tag, type = chatType, len = #text, ok = ok, result = ok and resultName(r) or tostring(r) }
    if run then run.sends[#run.sends + 1] = rec end
    return rec
end

local function pad(s, n) return s .. string.rep("x", n - #s) end

local function summary()
    if not run then return end
    local sent, okSent = {}, {}
    for _, s in ipairs(run.sends) do
        local k = s.tag:match("^(%a+)")
        sent[k] = (sent[k] or 0) + 1
        if s.ok and (s.result == "Success" or s.result == "0" or s.result == "true" or s.result == "nil") then
            okSent[k] = (okSent[k] or 0) + 1
        end
    end
    local got = {}
    for _, r in ipairs(run.received) do
        local k = r.tag:match("^(%a+)") or "?"
        got[k .. "/" .. r.type .. "/" .. r.from] = (got[k .. "/" .. r.type .. "/" .. r.from] or 0) + 1
    end
    say(("Done. Channel id: %s, hidden with: %s, in instance: %s"):format(tostring(run.channelID),
        tostring(run.hidden), tostring(run.instance)))
    for k, n in pairs(sent) do say(("  sent %s: %d (accepted %d)"):format(k, n, okSent[k] or 0)) end
    for k, n in pairs(got) do say(("  received %s: %d"):format(k, n)) end
    local codes = {}
    for _, s in ipairs(run.sends) do codes[s.result] = (codes[s.result] or 0) + 1 end
    for k, n in pairs(codes) do say(("  result %s: %d"):format(k, n)) end
    say("Now /reload so the results are saved.")
    run.done = true
end

local function startTest()
    local inInstance, instanceType = IsInInstance()
    run = { at = time(), build = select(1, GetBuildInfo()), instance = inInstance and instanceType or "none",
        sends = {}, received = {} }
    db.runs[#db.runs + 1] = run
    say("Joining the test channel...")
    JoinTemporaryChannel(CHANNEL)
    C_Timer.After(3, function()
        run.channelID = channelID()
        run.hidden = hideChannel()
        if not run.channelID then
            say("Couldn't join the channel. Testing guild/party/whisper only.")
        end
        local me = UnitName("player")
        -- 1. One normal message on each route.
        if run.channelID then send("single", "CHANNEL", run.channelID, "single~1") end
        if IsInGuild() then send("single", "GUILD", nil, "single~guild") end
        if IsInGroup() then send("single", "PARTY", nil, "single~party") end
        send("single", "WHISPER", me, "single~whisper")
        -- 2. The longest allowed message.
        if run.channelID then send("long", "CHANNEL", run.channelID, pad("long~255~", 255)) end
        -- 3. A burst of 30 at once (where does the throttle start?).
        if run.channelID then
            for i = 1, 30 do send("burst" .. i, "CHANNEL", run.channelID, pad(("burst~%02d~"):format(i), 200)) end
        end
        -- 4. After 15 s to recover: 10 messages, one per second.
        C_Timer.After(15, function()
            for i = 1, 10 do
                C_Timer.After(i, function()
                    if run.channelID then send("paced" .. i, "CHANNEL", run.channelID, pad(("paced~%02d~"):format(i), 200)) end
                end)
            end
            C_Timer.After(14, summary)
        end)
        say("Sending... results in about 30 seconds.")
    end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
    if event == "ADDON_LOADED" and a1 == "TradebookNet" then
        db = TradebookNetDB
        db.runs = db.runs or {}
        db.pings = db.pings or {}
        db.registered = tostring(C_ChatInfo.RegisterAddonMessagePrefix(PREFIX))
    elseif event == "CHAT_MSG_ADDON" and a1 == PREFIX then
        local text, chatType, sender = a2, a3, a4
        -- Compare the name part only: Forever's realm part doesn't match what Ambiguate expects
        -- (round 1 logged our own echoes as "other").
        local from = ((sender or ""):match("^[^-]+") == UnitName("player")) and "self" or "other"
        local tag = (text:match("^([^~]+)") or "?")
        local rec = { tag = tag, type = chatType, from = from, len = #text, at = GetTime() }
        if run and not run.done then run.received[#run.received + 1] = rec end
        if tag == "ping" then
            db.pings[#db.pings + 1] = rec
            if from == "other" then
                say(("Heard a ping from another player (%s, %d characters)."):format(chatType, #text))
                -- answer once so both sides see each other
                if not text:find("~reply") and channelID() then
                    send("pong", "CHANNEL", channelID(), "ping~reply")
                end
            end
        end
    end
end)

SLASH_TRADEBOOKNET1 = "/tbn"
SlashCmdList.TRADEBOOKNET = function(msg)
    msg = (msg or ""):lower():match("^%s*(%S*)")
    if msg == "test" then
        startTest()
    elseif msg == "ping" then
        if not channelID() then JoinTemporaryChannel(CHANNEL) end
        C_Timer.After(2, function()
            hideChannel()
            local id = channelID()
            if not id then say("Not in the test channel.") return end
            local r = send("ping", "CHANNEL", id, "ping~hello")
            say("Ping sent: " .. r.result .. ". Anyone else running /tbn ping should answer.")
        end)
    elseif msg == "leave" then
        LeaveChannelByName(CHANNEL)
        say("Left the test channel.")
    else
        say("/tbn test  run the full test (about 30 s)" .. NL .. "/tbn ping  say hello to other testers"
            .. NL .. "/tbn leave  leave the test channel")
    end
end
