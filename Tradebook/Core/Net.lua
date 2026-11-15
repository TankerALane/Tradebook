-- Core/Net.lua
-- In-game sharing of NPC data between Tradebook users. Every copy joins a hidden chat channel
-- and announces the vendors and trainers its player opens; what it hears from other players
-- is checked and kept in TradebookDB.heard, shown in the Vendors tab ("other players") and,
-- once two players agree, used like scanned data. "import npc data" also exports it.
--
-- Only NPC data is sent, in the /tb share text format (Core/Share.lua): NPC IDs, names, where
-- they stand, what they sell or teach and for how much. Nothing about the player's characters.
-- Other players are kept apart only by a short hash of their name (to count how many players
-- agree), never by name, and the hashes are never exported.
--
-- Tested in Forever (spikes/TradebookNet, docs/SPIKE_SHARING.md): a custom channel carries
-- addon messages and can be removed from the chat windows; 255-character messages arrive whole;
-- about 7 messages go out at once, then the game throttles (AddonMessageThrottle), while one
-- per second always got through. Dungeons tested 2026-11-14 (/tb net test: paused inside, all sent after). Not yet tested: a second
-- player actually hearing the messages.
--
-- Wire format: one share text, its line breaks turned into "^", cut into messages of
--   <msgID>~<part>~<parts>~<payload>
-- msgID starts with a random 4-hex tag per session, so a copy knows its own messages when the
-- channel echoes them back. (Comparing the sender's name didn't work: Forever writes sender
-- names differently from UnitName, and the first build heard its own player as "another".)
-- and put back together by the receiver (per sender and msgID).

local _, ns = ...
local Compat = ns.Compat

local Net = {}
ns.Net = Net

Net.PREFIX = "TRADEBOOK"
Net.CHANNEL = "TradebookShare"
Net.PAYLOAD = 230         -- characters of share text per message (header fits in 255)
Net.MAX_PARTS = 40        -- bigger NPCs are not sent (a vendor is usually 1-3 messages)
Net.MAX_PENDING = 30      -- unfinished incoming texts kept at once
Net.PENDING_TTL = 120     -- seconds before an unfinished text is dropped
Net.MAX_REPORTERS = 3     -- reports kept per NPC (the oldest is replaced)
Net.MAX_NPCS = 3000       -- NPCs kept per kind in TradebookDB.heard
Net.INTERVAL = 1.1        -- seconds between messages sent
Net.RESEND_AFTER = 86400  -- an unchanged scan is announced again after a day
Net.BACKLOG_DAYS = 30     -- scans this recent are re-announced after login, slowly
Net.BACKLOG_GAP = 20      -- seconds between re-announced NPCs
Net.SENDER_LIMIT = 90     -- messages per minute from one player before they're ignored

---------------------------------------------------------------------------
-- PURE: hashing, chunking, reassembly, validation, merging
---------------------------------------------------------------------------

-- PURE. A short hash of a string (to count different players without keeping names).
function Net.Hash(s)
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
    return ("%08x"):format(h)
end

-- PURE. Cut share text into messages. nil when it needs more than MAX_PARTS.
function Net.Chunk(text, msgID)
    local body = (text:gsub("%^", " "):gsub("\n", "^"))
    local parts = {}
    for i = 1, #body, Net.PAYLOAD do parts[#parts + 1] = body:sub(i, i + Net.PAYLOAD - 1) end
    if #parts == 0 or #parts > Net.MAX_PARTS then return nil end
    for i, p in ipairs(parts) do parts[i] = ("%s~%d~%d~%s"):format(msgID, i, #parts, p) end
    return parts
end

-- PURE. Was this message sent by the copy whose session tag is `session`?
function Net.IsOwn(msg, session)
    return tostring(msg):sub(1, #session) == session and #session > 0
end

-- PURE. A test message (/tb net test): starts with the session tag (so its echo is known as
-- your own) and doesn't fit the wire format, so every copy of Tradebook ignores it.
function Net.TestMessage(session, k)
    return ("%st%d~test"):format(session, k)
end

-- PURE. A new reassembler (one per session).
function Net.NewAssembler()
    return { pending = {}, n = 0 }
end

-- PURE. Feed one message from `sender`; returns the whole share text once all parts are in.
function Net.Feed(asm, sender, msg, now)
    local id, i, n, payload = tostring(msg):match("^(%w+)~(%d+)~(%d+)~(.*)$")
    i, n = tonumber(i), tonumber(n)
    if not (id and i and n) or n < 1 or n > Net.MAX_PARTS or i < 1 or i > n then return nil end
    for key, p in pairs(asm.pending) do
        if now - p.at > Net.PENDING_TTL then
            asm.pending[key] = nil
            asm.n = asm.n - 1
        end
    end
    local key = sender .. "/" .. id
    local p = asm.pending[key]
    if not p then
        if asm.n >= Net.MAX_PENDING then return nil end
        p = { n = n, got = 0, parts = {}, at = now }
        asm.pending[key] = p
        asm.n = asm.n + 1
    end
    if p.n ~= n then return nil end
    if not p.parts[i] then
        p.parts[i] = payload
        p.got = p.got + 1
    end
    p.at = now
    if p.got < n then return nil end
    asm.pending[key] = nil
    asm.n = asm.n - 1
    return (table.concat(p.parts):gsub("%^", "\n"))
end

local function okID(v)
    return type(v) == "number" and v > 0 and v < 10000000 and v == math.floor(v)
end

local function okName(s)
    return type(s) == "string" and #s > 0 and #s <= 60
end

local function okLoc(l)
    if l == nil then return true end
    local function coord(v) return type(v) == "number" and v >= 0 and v <= 100 end
    return okID(l.m) and coord(l.x) and coord(l.y)
end

local function okTime(t, now)
    if type(t) ~= "number" then return now end
    if t > now + 86400 or t < now - 365 * 86400 then return now end
    return t
end

-- PURE. A checked copy of a vendor heard from another player, or nil when anything is off.
function Net.CleanVendor(e, now)
    if type(e) ~= "table" or not okName(e.name) or not okLoc(e.loc) then return nil end
    local items, n = {}, 0
    for itemID, it in pairs(e.items or {}) do
        if not okID(itemID) or type(it) ~= "table" then return nil end
        if it.p ~= nil and (type(it.p) ~= "number" or it.p < 0 or it.p > 100000000) then return nil end
        if it.c ~= nil and (type(it.c) ~= "string" or #it.c > 120) then return nil end
        n = n + 1
        if n > 400 then return nil end
        items[itemID] = { p = it.p, s = tonumber(it.s) or -1, c = it.c }
    end
    if n == 0 then return nil end
    return { name = e.name, loc = e.loc, seenAt = okTime(e.seenAt, now), items = items }
end

-- PURE. A checked copy of a trainer heard from another player, or nil.
function Net.CleanTrainer(t, now)
    if type(t) ~= "table" or not okName(t.name) or not okLoc(t.loc) then return nil end
    if t.skill ~= nil and not okID(t.skill) then return nil end
    local services = {}
    for _, line in ipairs(t.services or {}) do
        if type(line) ~= "string" or #line > 200 then return nil end
        services[#services + 1] = line
        if #services > 300 then return nil end
    end
    if #services == 0 then return nil end
    return { name = t.name, skill = t.skill, loc = t.loc, seenAt = okTime(t.seenAt, now), services = services }
end

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- PURE. Keep one player's report of an NPC in heard[kind] ({ [npcID] = { reports = { [who] =
-- { at, e } } } }), replacing that player's older report and, when full, the oldest one.
-- Returns true when kept.
function Net.Record(heard, kind, npc, entry, who, now)
    heard[kind] = heard[kind] or {}
    local list = heard[kind]
    local rec = list[npc]
    if not rec then
        if count(list) >= Net.MAX_NPCS then return false end
        rec = { reports = {} }
        list[npc] = rec
    end
    if not rec.reports[who] and count(rec.reports) >= Net.MAX_REPORTERS then
        local oldest, at
        for k, r in pairs(rec.reports) do
            if not at or r.at < at or (r.at == at and k < oldest) then oldest, at = k, r.at end
        end
        rec.reports[oldest] = nil
    end
    rec.reports[who] = { at = now, e = entry }
    return true
end

-- PURE. The report most players agree with: entry, how many players agree (at least 1).
-- matches(a, b) says whether two reports describe the same NPC data.
function Net.Best(rec, matches)
    local best, bestN, bestAt
    for _, r in pairs(rec and rec.reports or {}) do
        local n = 0
        for _, s in pairs(rec.reports) do
            if s == r or matches(r.e, s.e) or matches(s.e, r.e) then n = n + 1 end
        end
        if not best or n > bestN or (n == bestN and (r.e.seenAt or 0) > (bestAt or 0)) then
            best, bestN, bestAt = r.e, n, r.e.seenAt
        end
    end
    return best, bestN or 0
end

-- PURE. Take one whole share text from player `who` into `heard`. Returns how many NPCs were kept.
function Net.Accept(heard, text, who, now)
    local vendors, trainers, confirmed = ns.Share.Decode(text)
    if not vendors then return 0 end
    local kept = 0
    for npc, e in pairs(vendors) do
        local clean = okID(npc) and Net.CleanVendor(e, now)
        if clean and Net.Record(heard, "vendors", npc, clean, who, now) then kept = kept + 1 end
    end
    for npc, t in pairs(trainers or {}) do
        local clean = okID(npc) and Net.CleanTrainer(t, now)
        if clean and Net.Record(heard, "trainers", npc, clean, who, now) then kept = kept + 1 end
    end
    heard.confirms = heard.confirms or { vendor = {}, trainer = {} }
    for _, c in ipairs(confirmed or {}) do
        local list = heard.confirms[c.kind]
        if list and okID(c.npc) and (list[c.npc] or count(list) < Net.MAX_NPCS) then
            list[c.npc] = list[c.npc] or {}
            local seen = okTime(c.seenAt, now)
            if not list[c.npc][who] or seen > list[c.npc][who] then list[c.npc][who] = seen end
            kept = kept + 1
        end
    end
    return kept
end

local function trainerMatches(a, b) return ns.Share.TrainerMatches(a, b) end
local function vendorMatches(a, b) return ns.Share.VendorMatches(a, b) end

-- PURE. The best report of every heard NPC of one kind: { [npcID] = entry + agree }.
function Net.BestAll(heard, kind)
    local out = {}
    local matches = kind == "trainers" and trainerMatches or vendorMatches
    for npc, rec in pairs(heard and heard[kind] or {}) do
        local e, n = Net.Best(rec, matches)
        if e then
            local copy = {}
            for k, v in pairs(e) do copy[k] = v end
            copy.agree, copy.heard = n, true
            out[npc] = copy
        end
    end
    return out
end

---------------------------------------------------------------------------
-- In game: channel, sending queue, receiving
---------------------------------------------------------------------------

local asm = Net.NewAssembler()
local queue = {}       -- messages waiting to go out
local backlog = {}     -- { kind, npc } of your scans to re-announce, slowly
local lastBacklog = 0
local channelID
local msgCounter = 0
local session = ("%04x"):format(math.random(0, 0xffff)) -- this copy's tag on its messages
local selfSender -- how the channel names you (learned from your first echo)
local version = 0      -- bumped when heard data changes (caches)
local senders = {}     -- [who] = { minute, n }: flood protection
local cached = {}
local stats = { sent = 0, heard = 0, players = {} }

local function enabled()
    return ns.db and ns.db.settings and ns.db.settings.netShare ~= false and not ns.fake
end

local function hideChannel()
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local cf = _G["ChatFrame" .. i]
        if cf then
            if ChatFrame_RemoveChannel then
                pcall(ChatFrame_RemoveChannel, cf, Net.CHANNEL)
            elseif ChatFrameUtil and ChatFrameUtil.RemoveChannel then
                pcall(ChatFrameUtil.RemoveChannel, cf, Net.CHANNEL)
            end
        end
    end
end

local function findChannel()
    local id = Compat.Call("GetChannelName", Net.CHANNEL)
    channelID = (tonumber(id) or 0) > 0 and id or nil
    return channelID
end

function Net.Version() return version end

local function changed()
    version = version + 1
    cached = {}
end

-- Heard vendors / trainers, best report each (cached until new data arrives).
function Net.HeardVendors()
    cached.vendors = cached.vendors or Net.BestAll(ns.db and ns.db.heard, "vendors")
    return cached.vendors
end

function Net.HeardTrainers()
    cached.trainers = cached.trainers or Net.BestAll(ns.db and ns.db.heard, "trainers")
    return cached.trainers
end

local function textFor(kind, npc)
    local build = Compat.Call("GetBuildInfo") or "?"
    local ver = Compat.Call("C_AddOns.GetAddOnMetadata", "Tradebook", "Version") or "?"
    if kind == "vendor" then
        local e = ns.db.vendors and ns.db.vendors[npc]
        if not (e and e.items and next(e.items)) then return nil end
        return (ns.Share.Encode({ [npc] = e }, build, ver, nil, { community = ns.CommunityVendors })), e.seenAt
    end
    local t = ns.db.trainers and ns.db.trainers[npc]
    if not (t and t.services and #t.services > 0) then return nil end
    return (ns.Share.Encode({}, build, ver, { [npc] = t }, { communityTrainers = ns.CommunityTrainers })), t.seenAt
end

-- Queue one of your scans for sending (skipped when that scan already went out today).
local function announce(kind, npc, force)
    local text, seenAt = textFor(kind, npc)
    if not text then return end
    ns.db.netSent = ns.db.netSent or {}
    local key = kind .. ":" .. npc
    local last = ns.db.netSent[key]
    local now = GetServerTime()
    if not force and last and last.seen == seenAt and now - last.at < Net.RESEND_AFTER then return end
    msgCounter = msgCounter + 1
    local parts = Net.Chunk(text, session .. ("%x"):format(msgCounter))
    if not parts or #queue + #parts > 400 then return end
    for _, p in ipairs(parts) do queue[#queue + 1] = p end
    ns.db.netSent[key] = { seen = seenAt, at = now }
end

-- Called after a vendor or trainer window was read (Core/Merchants.lua, Core/Trainers.lua).
function Net.Scanned(kind, npc)
    if not enabled() then return end
    -- Buying items re-reads the window: announce once, a few seconds after the last read.
    ns.Throttle("net:" .. kind .. npc, 5, function() announce(kind, npc) end)
end

local function inInstance()
    local inside = Compat.Call("IsInInstance")
    return inside == true
end

-- Why sending is paused right now, or nil.
local function pauseReason()
    if InCombatLockdown() then return "in combat" end
    if inInstance() then return "in a dungeon" end
end

local lastPause = false -- the reason last logged (false = sending)
local function pump()
    if not enabled() or not channelID then return end
    local reason = pauseReason()
    if (reason or false) ~= lastPause then
        lastPause = reason or false
        if reason then
            ns.Debug("net: paused,", reason .. ",", #queue, "messages waiting")
        else
            ns.Debug("net: sending again,", #queue, "messages waiting")
        end
    end
    if reason then return end
    if #queue == 0 then
        local now = GetTime()
        if #backlog > 0 and now - lastBacklog >= Net.BACKLOG_GAP then
            lastBacklog = now
            local job = table.remove(backlog, 1)
            announce(job.kind, job.npc)
        end
        if #queue == 0 then return end
    end
    local msg = queue[1]
    local result = Compat.Call("C_ChatInfo.SendAddonMessage", Net.PREFIX, msg, "CHANNEL", channelID)
    local throttled = Enum and Enum.SendAddonMessageResult and result == Enum.SendAddonMessageResult.AddonMessageThrottle
    if throttled then return end -- try the same message again next tick
    table.remove(queue, 1)
    stats.sent = stats.sent + 1
    ns.Debug("net: sent a message,", #queue, "waiting")
end

-- /tb net test: queue `n` test messages, enough backlog to watch sending pause in a dungeon.
function Net.Test(n)
    if not enabled() then return false end
    n = n or 20
    for k = 1, n do queue[#queue + 1] = Net.TestMessage(session, k) end
    ns.Debug("net: test,", n, "messages queued,", #queue, "waiting")
    return true
end

-- Your recent scans, newest first, to re-announce after login.
local function fillBacklog()
    backlog = {}
    local cutoff = GetServerTime() - Net.BACKLOG_DAYS * 86400
    for npc, e in pairs(ns.db.vendors or {}) do
        if (e.seenAt or 0) > cutoff then backlog[#backlog + 1] = { kind = "vendor", npc = npc, at = e.seenAt } end
    end
    for npc, t in pairs(ns.db.trainers or {}) do
        if (t.seenAt or 0) > cutoff then backlog[#backlog + 1] = { kind = "trainer", npc = npc, at = t.seenAt } end
    end
    table.sort(backlog, function(a, b) return a.at > b.at end)
end

local function join()
    if not enabled() then return end
    if not findChannel() then Compat.Call("JoinTemporaryChannel", Net.CHANNEL) end
    C_Timer.After(2, function()
        if findChannel() then
            hideChannel()
            ns.Debug("net: in channel", channelID)
        else
            ns.Debug("net: could not join the channel")
        end
    end)
end

-- Turn sharing on or off (the setting).
function Net.SetEnabled(on)
    ns.db.settings.netShare = on and true or false
    if on then
        join()
        fillBacklog()
    else
        queue, backlog = {}, {}
        if findChannel() then Compat.Call("LeaveChannelByName", Net.CHANNEL) end
        channelID = nil
    end
end

local function onAddonMessage(_, prefix, text, chatType, sender)
    if prefix ~= Net.PREFIX or chatType ~= "CHANNEL" or not enabled() then return end
    sender = tostring(sender or "")
    -- Your own messages come back on the channel: known by this session's tag (and, once one
    -- has come back, by how the channel names you).
    if Net.IsOwn(text, session) then
        selfSender = sender
        return
    end
    if sender == selfSender then return end
    local who = Net.Hash(sender)
    local minute = math.floor(GetTime() / 60)
    local s = senders[who]
    if not s or s.minute ~= minute then
        s = { minute = minute, n = 0, blocked = s and s.blocked }
        senders[who] = s
    end
    s.n = s.n + 1
    if s.n > Net.SENDER_LIMIT then s.blocked = true end
    if s.blocked then return end
    local full = Net.Feed(asm, who, text, GetTime())
    if not full then return end
    ns.db.heard = ns.db.heard or {}
    local kept = Net.Accept(ns.db.heard, full, who, GetServerTime())
    if kept > 0 then
        stats.heard = stats.heard + kept
        stats.players[who] = true
        changed()
        if ns.Trainers then ns.Trainers.Invalidate() end
        ns.Throttle("net:refresh", 2, function() if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end end)
    end
end

-- Status lines for /tb net.
function Net.Status()
    local heard = ns.db and ns.db.heard or {}
    return {
        ("Sharing: %s, channel: %s%s"):format(enabled() and "on" or "off", channelID and tostring(channelID) or "not joined",
            enabled() and pauseReason() and (" (paused: " .. pauseReason() .. ")") or ""),
        ("This session: %d messages sent, %d NPC reports heard from %d players"):format(stats.sent, stats.heard,
            count(stats.players)),
        ("Waiting to send: %d messages, %d NPCs to re-announce"):format(#queue, #backlog),
        ("Heard so far: %d vendors, %d trainers"):format(count(heard.vendors or {}), count(heard.trainers or {})),
    }
end

function Net.Start()
    Compat.Call("C_ChatInfo.RegisterAddonMessagePrefix", Net.PREFIX)
    ns.On("CHAT_MSG_ADDON", onAddonMessage)
    ns.On("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(10, join)
    end)
    -- Joining a channel right at login can fail while the chat system starts; try again later.
    C_Timer.After(60, function() if not channelID then join() end end)
    C_Timer.After(90, function() if enabled() then fillBacklog() end end)
    C_Timer.NewTicker(Net.INTERVAL, pump)
end
