-- dev/TradebookDev/RateTest.lua
-- /tbdev ratetest: how fast can addon messages go out on a channel in Forever? (Maintainer
-- only; never packaged.) Tradebook's sharing sends one message a second because an earlier
-- test saw about 7 go out at once and then AddonMessageThrottle. This measures it properly.
--
-- On its own hidden channel (TEST_CHANNEL), with Tradebook's own sending held (Net.Hold), it
-- runs phases one after the other:
--   rates 1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20 messages a second, one prefix;
--   if 20 a second went through clean: 30, 40, 50, 75, 100;
--   then 2, 5 and 10 messages a second spread over that many prefixes (1 a second each), to see
--   whether the game's limit is per prefix.
-- Each phase sends full-size messages (255 characters, like real shares) for DURATION s, then
-- waits GAP s (late echoes come in, the game's allowance refills). The channel echoes your own
-- messages back, which shows they really went out. Per phase: sends accepted, refused
-- (AddonMessageThrottle or other), echoed, and the rate echoed in the last SUSTAIN s (after the
-- first burst is used up). Results: a window to copy, and TradebookDevDB.rateTest.
-- /tbdev ratetest long [minutes]: one message a second, nonstop, for that long (30 minutes
-- unless given): running totals in chat every PROGRESS_EVERY s, and in the end a line per
-- minute: tried, accepted, refused, echoed, lost (accepted but never echoed). Shows how long
-- 1/s holds up.
-- /tbdev ratetest channels: 1 message a second on each of several channels at once, to see
-- whether the limit is per channel: 3 channels, then as many as are free (a character can be
-- in 10 numbered channels at most), each with one prefix for all and a prefix per channel.
-- CHANNEL_DURATION s each (past the first burst), delivered rate over the last CHANNEL_SUSTAIN s.
-- /tbdev ratetest stop: stop early (results so far).
-- Found 2026-11-17 (one prefix): 1/s all through; 2/s and up, 10 went out, then nothing for the
-- rest of the 20 s (AddonMessageThrottle and ChannelThrottle): sending too often keeps the
-- allowance from refilling. A 15 s pause gave 10 again.

local Dev = TradebookDev

local TEST_CHANNEL = "TradebookRateTest"
local PREFIX = "TBRATE"
local DURATION = 20
local GAP = 15
local SUSTAIN = 10
local MSG_LEN = 255
local BASE = { 1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20 }
local HIGHER = { 30, 40, 50, 75, 100 }
local SPREAD = { 2, 5, 10 }
local MAX_CHANNELS = 10
local PROGRESS_EVERY = 60 -- seconds between the long test's running totals
local ECHO_WAIT = 5       -- seconds before a message not echoed yet counts as lost
local CHANNEL_DURATION = 60
local CHANNEL_SUSTAIN = 30
local CHANNEL_GAP = 20

local function channelName(i)
    return i == 1 and TEST_CHANNEL or (TEST_CHANNEL .. i)
end

-- PURE. The channel phases for `free` channels joined: 3 (or fewer) channels, then all of
-- them; each with one prefix for all (distinct = false) and a prefix per channel.
function Dev.RateChannelPlan(free)
    local out = {}
    local counts = { math.min(3, free) }
    if free > 3 then counts[2] = free end
    for _, k in ipairs(counts) do
        for _, distinct in ipairs({ false, true }) do
            out[#out + 1] = { rate = k, channels = k, prefixes = distinct and k or 1, distinct = distinct,
                duration = CHANNEL_DURATION, sustain = CHANNEL_SUSTAIN, gap = CHANNEL_GAP }
        end
    end
    return out
end

-- PURE. The channel test's lines: per phase, the totals and the delivered rate against what
-- it tried, then a line per channel.
function Dev.RateChannelLines(phases)
    local lines = {}
    for _, p in ipairs(phases) do
        lines[#lines + 1] = ("%d channels, %s: %d tried, %d accepted, %d refused, %d echoed; %.1f/s delivered at the end (tried %d/s)")
            :format(p.channels, p.distinct and "a prefix each" or "one prefix", p.tried, p.sent, p.refused, p.echoed,
                Dev.RateSustained(p), p.rate)
        for c = 1, p.channels do
            local b = p.byChan and p.byChan[c] or { sent = 0, refused = 0, echoed = 0 }
            local reasons = {}
            for name, n in pairs(b.reasons or {}) do reasons[#reasons + 1] = name .. " " .. n end
            table.sort(reasons)
            lines[#lines + 1] = ("    channel %d: %d accepted, %d refused, %d echoed%s"):format(c, b.sent, b.refused,
                b.echoed, #reasons > 0 and ("  (" .. table.concat(reasons, ", ") .. ")") or "")
        end
    end
    return lines
end

-- PURE. The phases: { rate, prefixes, higher = true for the extra fast ones }.
function Dev.RatePlan()
    local out = {}
    for _, r in ipairs(BASE) do out[#out + 1] = { rate = r, prefixes = 1 } end
    for _, k in ipairs(SPREAD) do out[#out + 1] = { rate = k, prefixes = k, spread = true } end
    return out
end

-- PURE. The extra fast phases, to run when 20 a second went through clean.
function Dev.RateHigher()
    local out = {}
    for _, r in ipairs(HIGHER) do out[#out + 1] = { rate = r, prefixes = 1, higher = true } end
    return out
end

-- PURE. Did a phase go through clean: nothing refused, everything echoed?
function Dev.RateClean(p)
    return p.sent > 0 and p.refused == 0 and p.echoed >= p.sent
end

-- PURE. Messages echoed per second among those sent in the last SUSTAIN s of the phase
-- (or the phase's own duration and sustain).
function Dev.RateSustained(p)
    local duration, window = p.duration or DURATION, p.sustain or SUSTAIN
    local n = 0
    for seq, at in pairs(p.sentAt or {}) do
        if at >= duration - window and p.echoAt[seq] then n = n + 1 end
    end
    return n / window
end

-- PURE. The long test, one line per minute (sends in that minute), then the totals.
-- p: the phase (sentAt / refusedAt / echoAt by seq, seconds from its start); upTo: seconds
-- run so far. Lost: accepted but not echoed.
function Dev.RateLongLines(p, upTo)
    local lines = { "minute  tried  accepted  refused  echoed  lost" }
    local minutes = math.max(1, math.ceil(upTo / 60))
    local tot = { tried = 0, sent = 0, refused = 0, echoed = 0, lost = 0 }
    local firstProblem
    for m = 1, minutes do
        local lo, hi = (m - 1) * 60, m * 60
        local c = { tried = 0, sent = 0, refused = 0, echoed = 0, lost = 0 }
        for seq, at in pairs(p.sentAt or {}) do
            if at >= lo and at < hi then
                c.sent = c.sent + 1
                if p.echoAt[seq] then
                    c.echoed = c.echoed + 1
                else
                    c.lost = c.lost + 1
                    if not firstProblem or at < firstProblem then firstProblem = at end
                end
            end
        end
        for _, at in pairs(p.refusedAt or {}) do
            if at >= lo and at < hi then
                c.refused = c.refused + 1
                if not firstProblem or at < firstProblem then firstProblem = at end
            end
        end
        c.tried = c.sent + c.refused
        for k, v in pairs(c) do tot[k] = tot[k] + v end
        lines[#lines + 1] = ("%d  %d  %d  %d  %d  %d"):format(m, c.tried, c.sent, c.refused, c.echoed, c.lost)
    end
    lines[#lines + 1] = ("total  %d  %d  %d  %d  %d"):format(tot.tried, tot.sent, tot.refused, tot.echoed, tot.lost)
    lines[#lines + 1] = firstProblem
        and ("First problem after %d:%02d."):format(math.floor(firstProblem / 60), math.floor(firstProblem % 60))
        or "No problems: every message went out and came back."
    return lines
end

-- PURE. The long test's running totals at `now` (seconds from its start). A message accepted
-- in the last ECHO_WAIT s isn't lost yet (its echo may be on the way).
function Dev.RateProgress(p, now)
    local refused, echoed, lost = 0, 0, 0
    for _ in pairs(p.refusedAt or {}) do refused = refused + 1 end
    local sent = 0
    for seq, at in pairs(p.sentAt or {}) do
        sent = sent + 1
        if p.echoAt[seq] then
            echoed = echoed + 1
        elseif now - at >= ECHO_WAIT then
            lost = lost + 1
        end
    end
    return ("%d:%02d  tried %d, accepted %d, refused %d, echoed %d, lost %d"):format(math.floor(now / 60),
        math.floor(now % 60), sent + refused, sent, refused, echoed, lost)
end

-- PURE. One line per phase, for the results window.
function Dev.RateLines(phases)
    local lines = { "rate/s  prefixes  tried  accepted  refused  echoed  echoed/s (last " .. SUSTAIN .. " s)  first refused at" }
    for _, p in ipairs(phases) do
        local reasons = {}
        for name, n in pairs(p.reasons or {}) do reasons[#reasons + 1] = name .. " " .. n end
        table.sort(reasons)
        lines[#lines + 1] = ("%d/s  %d  %d  %d  %d  %d  %.1f  %s%s"):format(p.rate, p.prefixes, p.tried, p.sent,
            p.refused, p.echoed, Dev.RateSustained(p), p.firstRefused and ("%.1f s"):format(p.firstRefused) or "-",
            #reasons > 0 and ("  (" .. table.concat(reasons, ", ") .. ")") or "")
    end
    return lines
end

---------------------------------------------------------------------------
-- in game
---------------------------------------------------------------------------

local run -- the test in progress: { session, channel, phases, index, phase, startAt, frame }
local resultNames

local function resultName(r)
    if r == true or r == 0 or r == nil then return nil end -- sent
    if not resultNames then
        resultNames = {}
        local e = Enum and Enum.SendAddonMessageResult
        for k, v in pairs(e or {}) do resultNames[v] = k end
    end
    if r == false then return "Refused" end
    return resultNames[r] or ("result " .. tostring(r))
end

local function prefixOf(i)
    return i == 1 and PREFIX or (PREFIX .. i)
end

local function hideChannel()
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local cf = _G["ChatFrame" .. i]
        if cf then
            if ChatFrame_RemoveChannel then
                pcall(ChatFrame_RemoveChannel, cf, TEST_CHANNEL)
            elseif ChatFrameUtil and ChatFrameUtil.RemoveChannel then
                pcall(ChatFrameUtil.RemoveChannel, cf, TEST_CHANNEL)
            end
        end
    end
end

local function say(msg) print("|cffd9a54aTradebook Dev|r rate test: " .. msg) end

local function finish(stopped)
    if not run then return end
    local r = run
    run = nil
    r.frame:SetScript("OnUpdate", nil)
    local ns = Dev.NS()
    if ns and ns.Net and ns.Net.Hold then ns.Net.Hold(false) end
    for i = 1, (r.joined or 1) do pcall(_G.LeaveChannelByName, channelName(i)) end
    if r.ticker then r.ticker:Cancel() end
    local done = {}
    for _, p in ipairs(r.phases) do if p.tried then done[#done + 1] = p end end
    local lines, header
    if r.mode == "channels" then
        lines = Dev.RateChannelLines(done)
        header = ("Channel test %s, %s. %d channels free; 1 message a second per channel, %d s each, %d-character messages.")
            :format(date("%Y-%m-%d %H:%M"), stopped and "stopped early" or "finished", #r.channels, CHANNEL_DURATION,
                MSG_LEN)
    elseif r.long then
        local p = r.phases[1]
        lines = Dev.RateLongLines(p, math.min(p.duration, GetTime() - (r.startAt or GetTime())))
        header = ("Long rate test %s, %s. 1 message a second for up to %d minutes, %d-character messages."):format(
            date("%Y-%m-%d %H:%M"), stopped and "stopped early" or "finished", p.duration / 60, MSG_LEN)
    else
        lines = Dev.RateLines(done)
        header = ("Rate test %s, %s. %d s per rate, %d s between, %d-character messages."):format(
            date("%Y-%m-%d %H:%M"), stopped and "stopped early" or "finished", DURATION, GAP, MSG_LEN)
    end
    local text = header .. "\n" .. table.concat(lines, "\n")
    local d = Dev.DB()
    d.rateTest = { at = time(), stopped = stopped or nil, lines = lines }
    say(stopped and "stopped." or "finished.")
    Dev.ShowText("Tradebook Dev: send rate test",
        "How many messages a second went out on a test channel (echoed = came back, so really sent).", text)
end

local function startPhase()
    local p = run.phases[run.index]
    if not p then
        C_Timer.After(5, function() finish(false) end)
        return
    end
    p.tried, p.sent, p.refused, p.echoed, p.nextAt = 0, 0, 0, 0, 0
    p.sentAt, p.echoAt, p.reasons, p.refusedAt = {}, {}, {}, {}
    p.byChan, p.chanOf = {}, {}
    run.phase, run.startAt = p, GetTime()
    if p.channels then
        say(("%d channels, %s, 1/s each for %d s..."):format(p.channels, p.distinct and "a prefix each" or "one prefix",
            p.duration))
        return
    end
    if p.long then
        say(("1/s nonstop for %d minutes; running totals every %d s."):format(p.duration / 60, PROGRESS_EVERY))
        run.ticker = C_Timer.NewTicker(PROGRESS_EVERY, function()
            if run and run.phase == p then say(Dev.RateProgress(p, GetTime() - run.startAt)) end
        end)
        return
    end
    say(("%d/s on %d prefix%s for %d s..."):format(p.rate, p.prefixes, p.prefixes == 1 and "" or "es", DURATION))
end

local function endPhase()
    local p = run.phase
    run.phase = nil
    if p.long then
        C_Timer.After(GAP, function() finish(false) end)
        return
    end
    -- Report once the late echoes are in, then the next phase.
    C_Timer.After(p.gap or GAP, function()
        if not run then return end
        if p.channels then
            for _, line in ipairs(Dev.RateChannelLines({ p })) do say(line) end
            run.index = run.index + 1
            startPhase()
            return
        end
        say(("%d/s: %d tried, %d accepted, %d refused, %d echoed, %.1f/s at the end"):format(p.rate, p.tried, p.sent,
            p.refused, p.echoed, Dev.RateSustained(p)))
        -- 20 a second clean: try faster, before the prefix phases.
        if p.rate == 20 and p.prefixes == 1 and not p.higher and Dev.RateClean(p) then
            local at = run.index + 1
            for i, h in ipairs(Dev.RateHigher()) do table.insert(run.phases, at + i - 1, h) end
            say("20/s went through clean: trying faster too.")
        end
        -- A higher rate that already failed: skip the rest of the higher ones.
        if p.higher and not Dev.RateClean(p) then
            while run.phases[run.index + 1] and run.phases[run.index + 1].higher do table.remove(run.phases, run.index + 1) end
        end
        run.index = run.index + 1
        startPhase()
    end)
end

local function send(p, seq)
    local prefix, channel, c = prefixOf(((seq - 1) % p.prefixes) + 1), run.channel, nil
    if p.channels then
        c = ((seq - 1) % p.channels) + 1
        prefix, channel = p.distinct and prefixOf(c) or PREFIX, run.channels[c]
        p.chanOf[seq] = c
        p.byChan[c] = p.byChan[c] or { sent = 0, refused = 0, echoed = 0, reasons = {} }
    end
    local head = ("%s:%d:%d:"):format(run.session, run.index, seq)
    local msg = head .. string.rep("x", MSG_LEN - #head)
    local r = _G.C_ChatInfo.SendAddonMessage(prefix, msg, "CHANNEL", channel)
    local now = GetTime() - run.startAt
    p.tried = p.tried + 1
    local refused = resultName(r)
    local b = c and p.byChan[c]
    if refused then
        p.refused = p.refused + 1
        p.reasons[refused] = (p.reasons[refused] or 0) + 1
        p.firstRefused = p.firstRefused or now
        p.refusedAt[seq] = now
        if b then
            b.refused = b.refused + 1
            b.reasons[refused] = (b.reasons[refused] or 0) + 1
        end
    else
        p.sent = p.sent + 1
        p.sentAt[seq] = now
        if b then b.sent = b.sent + 1 end
    end
end

local function onUpdate()
    local p = run and run.phase
    if not p then return end
    local elapsed = GetTime() - run.startAt
    if elapsed >= (p.duration or DURATION) then
        endPhase()
        return
    end
    -- On schedule, never catching up: after a loading screen (or a slow frame) the missed
    -- sends are skipped, so they can't go out in a burst and trip the game's limit.
    p.nextAt = p.nextAt or 0
    if elapsed - p.nextAt > 1 then p.nextAt = elapsed end
    local n = 0
    while elapsed >= p.nextAt and n < 200 do
        send(p, p.tried + 1)
        p.nextAt = p.nextAt + 1 / p.rate
        n = n + 1
    end
end

local function onEcho(_, _, prefix, text, chatType)
    if not run or chatType ~= "CHANNEL" or type(prefix) ~= "string" or prefix:sub(1, #PREFIX) ~= PREFIX then return end
    local session, index, seq = tostring(text):match("^(%x+):(%d+):(%d+):")
    if session ~= run.session then return end
    local p = run.phases[tonumber(index)]
    seq = tonumber(seq)
    if p and p.echoAt and p.sentAt[seq] and not p.echoAt[seq] then
        p.echoAt[seq] = GetTime()
        p.echoed = p.echoed + 1
        local c = p.chanOf and p.chanOf[seq]
        if c and p.byChan[c] then p.byChan[c].echoed = p.byChan[c].echoed + 1 end
    end
end

local echoFrame
function Dev.RateTest(arg)
    arg = arg or ""
    local mode, minutes = arg:match("^(%a*)%s*(%d*)")
    if mode == "stop" then
        if run then finish(true) else say("not running.") end
        return
    end
    if run then say("already running (/tbdev ratetest stop to stop).") return end
    if not (_G.C_ChatInfo and _G.C_ChatInfo.SendAddonMessage) then say("this game has no addon messages.") return end
    local ns = Dev.NS()
    for i = 1, 10 do _G.C_ChatInfo.RegisterAddonMessagePrefix(prefixOf(i)) end
    if not echoFrame then
        echoFrame = CreateFrame("Frame")
        echoFrame:RegisterEvent("CHAT_MSG_ADDON")
        echoFrame:SetScript("OnEvent", onEcho)
    end
    local long = mode == "long"
    local multi = mode == "channels"
    minutes = math.max(1, math.min(240, tonumber(minutes) or 30))
    if multi then
        for i = 1, MAX_CHANNELS do _G.JoinTemporaryChannel(channelName(i)) end
        say("joining up to 10 test channels and holding Tradebook's own sharing; about 6 minutes."
            .. " /tbdev ratetest stop to stop.")
        C_Timer.After(5, function()
            local ids = {}
            for i = 1, MAX_CHANNELS do
                local id = tonumber((_G.GetChannelName(channelName(i)))) or 0
                if id > 0 then ids[#ids + 1] = id end
            end
            if #ids == 0 then say("couldn't join any test channel.") return end
            for i = 1, MAX_CHANNELS do
                if (tonumber((_G.GetChannelName(channelName(i)))) or 0) > 0 then
                    for f = 1, (NUM_CHAT_WINDOWS or 10) do
                        local cf = _G["ChatFrame" .. f]
                        if cf and ChatFrame_RemoveChannel then pcall(ChatFrame_RemoveChannel, cf, channelName(i)) end
                    end
                end
            end
            say(("%d test channels joined (the rest of the 10 channel slots are in use)."):format(#ids))
            if ns and ns.Net and ns.Net.Hold then ns.Net.Hold(true) end
            run = { session = ("%04x"):format(math.random(0, 0xffff)), channels = ids, channel = ids[1],
                phases = Dev.RateChannelPlan(#ids), index = 1, frame = CreateFrame("Frame"), mode = "channels",
                joined = MAX_CHANNELS }
            run.frame:SetScript("OnUpdate", onUpdate)
            C_Timer.After(CHANNEL_GAP, function() if run then startPhase() end end)
        end)
        return
    end
    _G.JoinTemporaryChannel(TEST_CHANNEL)
    say(("joining the test channel and holding Tradebook's own sharing; about %d minutes. /tbdev ratetest stop to stop.")
        :format(long and minutes or 11))
    C_Timer.After(3, function()
        local id = _G.GetChannelName(TEST_CHANNEL)
        id = tonumber(id) or 0
        if id <= 0 then say("couldn't join the test channel.") return end
        hideChannel()
        if ns and ns.Net and ns.Net.Hold then ns.Net.Hold(true) end
        local phases = long and { { rate = 1, prefixes = 1, long = true, duration = minutes * 60 } } or Dev.RatePlan()
        run = { session = ("%04x"):format(math.random(0, 0xffff)), channel = id, phases = phases, index = 1,
            frame = CreateFrame("Frame"), long = long }
        run.frame:SetScript("OnUpdate", onUpdate)
        -- Let the game's allowance fill up before the first phase.
        C_Timer.After(GAP, function() if run then startPhase() end end)
    end)
end
