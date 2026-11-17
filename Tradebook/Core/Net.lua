-- Core/Net.lua
-- In-game sharing of NPC data between Tradebook users. Every copy joins a hidden chat channel
-- and announces the vendors and trainers its player opens; what it hears from other players
-- is checked and kept in TradebookDB.heard, shown in the Vendors tab ("other players") and,
-- once two players agree, used like scanned data. "import npc data" also exports it.
-- Disenchant results are shared the same way: each player's totals per Forever disenchant band
-- (heard.de[who], the player's latest totals replace the older ones; Core/Disenchant.lua
-- counts them for a band once 2+ players have reported it).
--
-- Passing along to a collector (the maintainer, who runs dev/TradebookDev: Net.SetCollector):
-- a collector says "<session>~CTL~HELLO" when it joins and every COLLECTOR_HELLO seconds.
-- Players who hear it re-send their own recent scans, and pass along what they heard from
-- other players that no collector has received yet: one heard report per text, with header
-- TBR1 (not TBV1, so no regular copy of Tradebook, old or new, takes it in) and an "R~<hash>"
-- line naming the original player, so "2 players agree" still counts the original players.
-- The collector answers "<session>~CTL~ACK~<msgID>" and the report is marked relayed (until
-- that player sends a newer one). Control messages don't fit the wire format: older copies
-- ignore them.
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
Net.BACKLOG_DAYS = 30     -- scans this recent are re-announced after login, slowly
Net.BACKLOG_GAP = 20      -- seconds between re-announced NPCs
Net.SENDER_LIMIT = 90     -- messages per minute from one player before they're ignored
Net.MAX_DE_PLAYERS = 300  -- players whose disenchant totals are kept (the oldest is dropped)
Net.COLLECTOR_HELLO = 600 -- seconds between a collector's hellos
Net.RELAY_BATCH = 200     -- heard reports passed along per hello
Net.RELAY_GAP = 3         -- seconds between passed-along reports
Net.RELAY_AGAIN = 1800    -- a player answers hellos at most this often

---------------------------------------------------------------------------
-- PURE: hashing, chunking, reassembly, validation, merging
---------------------------------------------------------------------------

-- PURE. A short hash of a string (to count different players without keeping names).
function Net.Hash(s)
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
    return ("%08x"):format(h)
end

-- PURE. What a scan says, without what changes on every visit (the date, where you stood,
-- limited stock counts): the same fingerprint means nothing new to send. A vendor or trainer
-- that matches the community data is just a confirmation.
function Net.Fingerprint(kind, e, community)
    if kind == "vendor" then
        if ns.Share.VendorMatches(e, community) then return "C" end
        local ids = {}
        for id in pairs(e.items or {}) do ids[#ids + 1] = id end
        table.sort(ids)
        local parts = { tostring(e.name) }
        for _, id in ipairs(ids) do
            local it = e.items[id]
            parts[#parts + 1] = table.concat({ id, it.p or "", (it.s or -1) >= 0 and "L" or "", it.c or "" }, ":")
        end
        return Net.Hash(table.concat(parts, ";"))
    end
    if ns.Share.TrainerMatches(e, community) then return "CT" end
    local lines = {}
    for i, line in ipairs(e.services or {}) do lines[i] = line end
    table.sort(lines)
    return Net.Hash(tostring(e.name) .. ";" .. tostring(e.skill) .. ";" .. table.concat(lines, ";"))
end

-- PURE. Should a scan go out? last: what was sent for it before ({ fp, collector }), or nil.
-- force: a collector just said hello (re-send what went out while no collector was there).
function Net.ShouldSend(last, fp, force)
    if not (last and last.fp == fp) then return true end
    return force == true and not last.collector
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
    return (table.concat(p.parts):gsub("%^", "\n")), id
end

-- PURE. A control message ("<session>~CTL~HELLO", "<session>~CTL~ACK~<msgID>"): what, arg; or nil.
function Net.Control(msg)
    local what, arg = tostring(msg):match("^%w+~CTL~(%u+)~?(.*)$")
    return what, arg
end

-- PURE. Share text of one heard report, passed along for player `who` (header TBR1, R line).
function Net.RelayText(text, who)
    local body = text:gsub("^TBV1", "TBR1", 1)
    local header, rest = body:match("^([^\n]*)\n?(.*)$")
    return header .. "\nR~" .. who .. (rest ~= "" and ("\n" .. rest) or "")
end

-- PURE. A passed-along text: the original player and the text as a normal share text; or nil.
function Net.ParseRelay(text)
    if tostring(text):sub(1, 5) ~= "TBR1~" then return nil end
    local who = text:match("\nR~(%x+)\n") or text:match("\nR~(%x+)$")
    if not who or #who > 16 then return nil end
    return who, (text:gsub("^TBR1", "TBV1", 1))
end

-- PURE. Heard reports no collector has received yet: { { kind, npc, who, rec } }, at most
-- `limit`, skipping player `skip` (the collector's own reports).
function Net.Unrelayed(heard, limit, skip)
    local out = {}
    local function add(ref)
        if #out < limit and ref.who ~= skip then out[#out + 1] = ref end
    end
    for _, kind in ipairs({ "vendors", "trainers" }) do
        for npc, rec in pairs(heard and heard[kind] or {}) do
            for who, r in pairs(rec.reports or {}) do
                if not r.relayed then add({ kind = kind, npc = npc, who = who, rec = r }) end
            end
        end
    end
    for who, h in pairs(heard and heard.de or {}) do
        if not h.relayed then add({ kind = "de", who = who, rec = h }) end
    end
    return out
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

-- PURE. A checked copy of one band of another player's disenchant totals, or nil.
function Net.CleanDisenchant(band, rec)
    if not (okID(band) and band < 100000 and type(rec) == "table") then return nil end
    local n = tonumber(rec.n)
    if not n or n < 1 or n > 100000 or n ~= math.floor(n) then return nil end
    local mats, any = {}, false
    for id, m in pairs(rec.mats or {}) do
        local t, q, lo, hi = tonumber(m.t), tonumber(m.q), tonumber(m.lo), tonumber(m.hi)
        if not (okID(id) and t and q and lo and hi) then return nil end
        if t < 1 or t > n or lo < 1 or hi < lo or hi > 50 or q < t * lo or q > t * hi then return nil end
        mats[id] = { t = t, q = q, lo = lo, hi = hi }
        any = true
    end
    if not any or count(mats) > 10 then return nil end
    return { n = n, mats = mats }
end

-- PURE. Keep one player's disenchant totals in heard.de ({ [who] = { at, bands } }): their
-- latest totals replace the older ones; when full, the player heard from longest ago is dropped.
function Net.RecordDisenchants(heard, bands, who, now)
    heard.de = heard.de or {}
    if not heard.de[who] and count(heard.de) >= Net.MAX_DE_PLAYERS then
        local oldest, at
        for k, r in pairs(heard.de) do
            if not at or r.at < at or (r.at == at and k < oldest) then oldest, at = k, r.at end
        end
        heard.de[oldest] = nil
    end
    heard.de[who] = { at = now, bands = bands }
    return true
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

-- PURE. Take one whole share text from player `who` into `heard`. Returns how many NPCs were
-- kept, and what (for the maintainer's notifications, dev/TradebookDev):
--   { vendors = { [npcID] = { name, items = n, map = uiMapID } },
--     trainers = { [npcID] = { name, skill, services = n } },
--     confirmed = { { kind = "vendor" | "trainer", npc } }, confirms = n,
--     deBands = { [bandID] = checked totals }, disenchants = n bands }
function Net.Accept(heard, text, who, now)
    local vendors, trainers, confirmed, disenchants = ns.Share.Decode(text)
    local info = { vendors = {}, trainers = {}, confirmed = {}, confirms = 0, deBands = {}, disenchants = 0 }
    if not vendors then return 0, info end
    local kept = 0
    local bands, nb = {}, 0
    for band, rec in pairs(disenchants or {}) do
        local clean = Net.CleanDisenchant(band, rec)
        if clean then bands[band], nb = clean, nb + 1 end
    end
    if nb > 0 and nb <= 200 then
        Net.RecordDisenchants(heard, bands, who, now)
        kept = kept + nb
        info.disenchants, info.deBands = nb, bands
    end
    for npc, e in pairs(vendors) do
        local clean = okID(npc) and Net.CleanVendor(e, now)
        if clean and Net.Record(heard, "vendors", npc, clean, who, now) then
            kept = kept + 1
            info.vendors[npc] = { name = clean.name or "?", items = count(clean.items or {}),
                map = clean.loc and clean.loc.m }
        end
    end
    for npc, t in pairs(trainers or {}) do
        local clean = okID(npc) and Net.CleanTrainer(t, now)
        if clean and Net.Record(heard, "trainers", npc, clean, who, now) then
            kept = kept + 1
            info.trainers[npc] = { name = clean.name or "?", skill = clean.skill, services = #(clean.services or {}) }
        end
    end
    heard.confirms = heard.confirms or { vendor = {}, trainer = {} }
    for _, c in ipairs(confirmed or {}) do
        local list = heard.confirms[c.kind]
        if list and okID(c.npc) and (list[c.npc] or count(list) < Net.MAX_NPCS) then
            list[c.npc] = list[c.npc] or {}
            local seen = okTime(c.seenAt, now)
            if not list[c.npc][who] or seen > list[c.npc][who] then list[c.npc][who] = seen end
            kept = kept + 1
            info.confirms = info.confirms + 1
            info.confirmed[#info.confirmed + 1] = { kind = c.kind, npc = c.npc }
        end
    end
    return kept, info
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
local stats = { sent = 0, heard = 0, players = {}, relayed = 0, acked = 0 }
local collector = false -- this copy collects passed-along reports (dev/TradebookDev)
local relayQueue = {}   -- heard reports to pass along to a collector
local sentRelay = {}    -- [msgID] = the report it carried (marked relayed on the collector's ACK)
local lastRelay, answeredAt, collectorWho = 0, nil, nil
local collectorAt -- GetTime() of the last collector hello heard

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

-- Other players' disenchant totals: { [who] = { at, bands } }.
function Net.HeardDisenchants()
    return ns.db and ns.db.heard and ns.db.heard.de or {}
end

-- Total disenchants recorded, to tell when there's something new to announce.
local function disenchantTotal()
    local n = 0
    for _, rec in pairs(ns.db.disenchants or {}) do n = n + (rec.n or 0) end
    return n
end

local function textFor(kind, npc)
    local build = Compat.Call("GetBuildInfo") or "?"
    local ver = Compat.Call("C_AddOns.GetAddOnMetadata", "Tradebook", "Version") or "?"
    if kind == "disenchant" then
        local total = disenchantTotal()
        if total == 0 then return nil end
        return (ns.Share.Encode({}, build, ver, nil, { disenchants = ns.db.disenchants })), tostring(total)
    end
    if kind == "vendor" then
        local e = ns.db.vendors and ns.db.vendors[npc]
        if not (e and e.items and next(e.items)) then return nil end
        local community = ns.CommunityVendors and ns.CommunityVendors[npc]
        return (ns.Share.Encode({ [npc] = e }, build, ver, nil, { community = ns.CommunityVendors })),
            Net.Fingerprint("vendor", e, community)
    end
    local t = ns.db.trainers and ns.db.trainers[npc]
    if not (t and t.services and #t.services > 0) then return nil end
    local community = ns.CommunityTrainers and ns.CommunityTrainers[npc]
    return (ns.Share.Encode({}, build, ver, { [npc] = t }, { communityTrainers = ns.CommunityTrainers })),
        Net.Fingerprint("trainer", t, community)
end

-- A control message, first in line (they're short and time-sensitive).
local function control(what, arg)
    table.insert(queue, 1, session .. "~CTL~" .. what .. (arg and ("~" .. arg) or ""))
end

-- Queue one of your scans for sending: only when it says something you haven't sent yet (a
-- first visit, or something new or changed at the NPC; Net.Fingerprint). force: a collector
-- said hello, so also what went out while no collector was online.
local function announce(kind, npc, force)
    local text, fp = textFor(kind, npc)
    if not text then return end
    ns.db.netSent = ns.db.netSent or {}
    local key = kind .. ":" .. npc
    if not Net.ShouldSend(ns.db.netSent[key], fp, force) then return end
    msgCounter = msgCounter + 1
    local parts = Net.Chunk(text, session .. ("%x"):format(msgCounter))
    if not parts or #queue + #parts > 400 then return end
    for _, p in ipairs(parts) do queue[#queue + 1] = p end
    local collectorOnline = collectorAt ~= nil and GetTime() - collectorAt < Net.COLLECTOR_HELLO * 1.5
    ns.db.netSent[key] = { fp = fp, at = GetServerTime(), collector = collectorOnline or nil }
end

-- Called after a disenchant was recorded (Core/Disenchant.lua): your totals go out a minute
-- after the last one (a session of disenchanting is one announcement).
function Net.Disenchanted()
    if not enabled() then return end
    ns.Throttle("net:disenchant", 60, function() announce("disenchant", 0) end)
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
            announce(job.kind, job.npc, job.force)
        end
        -- Pass along one heard report to a collector.
        if #queue == 0 and #relayQueue > 0 and now - lastRelay >= Net.RELAY_GAP then
            lastRelay = now
            local ref = table.remove(relayQueue, 1)
            local build = Compat.Call("GetBuildInfo") or "?"
            local ver = Compat.Call("C_AddOns.GetAddOnMetadata", "Tradebook", "Version") or "?"
            local text
            if ref.kind == "vendors" then
                text = ns.Share.Encode({ [ref.npc] = ref.rec.e }, build, ver)
            elseif ref.kind == "trainers" then
                text = ns.Share.Encode({}, build, ver, { [ref.npc] = ref.rec.e })
            else
                text = ns.Share.Encode({}, build, ver, nil, { disenchants = ref.rec.bands })
            end
            msgCounter = msgCounter + 1
            local id = session .. ("%x"):format(msgCounter)
            local parts = text and Net.Chunk(Net.RelayText(text, ref.who), id)
            if parts then
                for _, p in ipairs(parts) do queue[#queue + 1] = p end
                sentRelay[id] = ref
                stats.relayed = stats.relayed + 1
            end
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

-- Your recent scans, newest first, to re-announce after login: only what you haven't sent yet
-- (force: a collector just came online, so also what went out while none was there).
local function fillBacklog(force)
    backlog = {}
    local cutoff = GetServerTime() - Net.BACKLOG_DAYS * 86400
    for npc, e in pairs(ns.db.vendors or {}) do
        if (e.seenAt or 0) > cutoff then backlog[#backlog + 1] = { kind = "vendor", npc = npc, at = e.seenAt, force = force } end
    end
    for npc, t in pairs(ns.db.trainers or {}) do
        if (t.seenAt or 0) > cutoff then backlog[#backlog + 1] = { kind = "trainer", npc = npc, at = t.seenAt, force = force } end
    end
    table.sort(backlog, function(a, b) return a.at > b.at end)
    -- Your disenchant totals (skipped when unchanged since they were sent).
    if disenchantTotal() > 0 then
        table.insert(backlog, 1, { kind = "disenchant", npc = 0, at = GetServerTime(), force = force })
    end
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

-- This copy collects passed-along reports (dev/TradebookDev). Says hello now and regularly.
function Net.SetCollector(on)
    collector = on and true or false
    if collector then
        C_Timer.After(30, function() if enabled() and channelID then control("HELLO") end end)
        C_Timer.NewTicker(Net.COLLECTOR_HELLO, function() if enabled() and channelID then control("HELLO") end end)
    end
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
    local what, arg = Net.Control(text)
    if what then
        if what == "HELLO" and not collector then
            -- A collector is online: re-send your own recent scans and pass along what you heard,
            -- after a short random wait (so not everyone answers at once), at most every 30 min.
            collectorWho = who
            collectorAt = GetTime()
            local now = GetTime()
            if not answeredAt or now - answeredAt >= Net.RELAY_AGAIN then
                answeredAt = now
                C_Timer.After(5 + math.random(0, 55), function()
                    fillBacklog(true)
                    relayQueue = Net.Unrelayed(ns.db.heard, Net.RELAY_BATCH, collectorWho)
                    ns.Debug("net: collector online,", #backlog, "own scans and", #relayQueue, "heard reports to send")
                end)
            end
        elseif what == "ACK" and Net.IsOwn(arg, session) and sentRelay[arg] then
            sentRelay[arg].rec.relayed = true
            sentRelay[arg] = nil
            stats.acked = stats.acked + 1
        end
        return
    end
    local minute = math.floor(GetTime() / 60)
    local s = senders[who]
    if not s or s.minute ~= minute then
        s = { minute = minute, n = 0, blocked = s and s.blocked }
        senders[who] = s
    end
    s.n = s.n + 1
    if s.n > Net.SENDER_LIMIT then s.blocked = true end
    if s.blocked then return end
    local full, msgID = Net.Feed(asm, who, text, GetTime())
    if not full then return end
    ns.db.heard = ns.db.heard or {}
    -- Passed along by `who` for another player: only a collector takes it in, as that player's.
    local relayed, relayText = Net.ParseRelay(full)
    if relayed then
        if not collector then return end
        control("ACK", msgID)
        if selfSender and relayed == Net.Hash(selfSender) then return end -- your own data, back again
        who, full = relayed, relayText
    end
    local kept, info = Net.Accept(ns.db.heard, full, who, GetServerTime())
    if kept > 0 then
        ns.Fire("NET_HEARD", who, info)
        stats.heard = stats.heard + kept
        stats.players[who] = true
        changed()
        if ns.Trainers then ns.Trainers.Invalidate() end
        if ns.Disenchant then ns.Disenchant.Invalidate() end
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
        ("Heard so far: %d vendors, %d trainers, disenchants from %d players"):format(count(heard.vendors or {}),
            count(heard.trainers or {}), count(heard.de or {})),
        collector and "Collecting: other players pass along what they heard to you"
            or ("Passing along to a collector: %d heard reports waiting, %d sent and received this session"):format(
                #Net.Unrelayed(heard, 100000, collectorWho), stats.acked),
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
