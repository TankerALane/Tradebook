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
-- Catching up (players who weren't online when something was shared): 45 s after joining the
-- channel a copy says "<session>~CTL~SYNC" (once a session). Players who hear it wait 3-20 s
-- at random; the first to start says "<session>~CTL~SYNCFOR~<asker's session>" (the others
-- drop their answer) and sends the newest SYNC_BATCH reports of the last SYNC_DAYS days, its
-- own scans as usual and what it heard as passed-along reports (TBR1, original player's hash),
-- spread over the lanes. A copy answers at most every SYNC_ANSWER_AGAIN s, and the same player
-- at most every SYNC_SAME s. Everyone online keeps them; passed-along reports are marked
-- indirect and don't count toward players agreeing (only a player's own message does), so
-- they show as unconfirmed until two players have sent the same data directly.
--
-- Only NPC data is sent, in the /tb share text format (Core/Share.lua): NPC IDs, names, where
-- they stand, what they sell or teach and for how much. Nothing about the player's characters.
-- Other players are kept apart only by a short hash of their name (to count how many players
-- agree), never by name, and the hashes are never exported.
--
-- Tested in Forever (spikes/TradebookNet, docs/SPIKE_SHARING.md): a custom channel carries
-- addon messages and can be removed from the chat windows; 255-character messages arrive whole;
-- about 7 messages go out at once, then the game throttles (AddonMessageThrottle), while one
-- per second always got through. Measured 2026-11-17 (dev /tbdev ratetest): at 2/s or more on
-- one channel only the first 10 go out and then none at all (AddonMessageThrottle and
-- ChannelThrottle: trying too often keeps the allowance from refilling); at 1/s a channel is
-- refused after about 12 s and averages about 0.5/s with a back-off; the limit is per channel
-- and prefix: 5 channels with a prefix each at 0.75/s each went 15 minutes, 3375 of 3375, none
-- refused. So:
--
-- Channels ("lanes"): lane 1 is TradebookShare with prefix TRADEBOOK (what older copies use);
-- lanes 2..LANES are TradebookShare2.. with prefixes TRADEBOOK2.., joined only while that leaves
-- CHANNEL_RESERVE of the MAX_CHAT_CHANNELS chat channels free for the player. Each lane sends at
-- most one message every INTERVAL s (0.75/s); a refused lane waits BACKOFF s, the others go on.
-- All parts of one text go on one lane. Your own scans and control messages go on lane 1 (older
-- copies hear them); passed-along reports and catch-ups go on any lane whose queue is empty, up
-- to the lanes the receiver listens on (HELLO~<lanes>, SYNC~<lanes>; none given = 1).
-- Dungeons tested 2026-11-14 (/tb net test: paused inside, all sent after). Not yet tested: a second
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
Net.INTERVAL = 1.35       -- seconds between messages on one channel (0.75/s, tested clean)
Net.LANES = 5             -- channels used at most (lane 1 = CHANNEL)
Net.MAX_CHAT_CHANNELS = 20 -- chat channels a character can be in (measured)
Net.CHANNEL_RESERVE = 5   -- channels always left free for the player
Net.BACKOFF = 15          -- seconds a refused channel waits
Net.TICK = 0.2            -- seconds between looks at the lanes
Net.BACKLOG_DAYS = 30     -- scans this recent are re-announced after login, slowly
Net.BACKLOG_GAP = 20      -- seconds between re-announced NPCs
Net.SENDER_LIMIT = 90     -- messages per minute from one player before they're ignored
Net.MAX_DE_PLAYERS = 300  -- players whose disenchant totals are kept (the oldest is dropped)
Net.COLLECTOR_HELLO = 600 -- seconds between a collector's hellos
Net.RELAY_BATCH = 200     -- heard reports passed along per hello
Net.RELAY_AGAIN = 1800    -- a player answers hellos at most this often
Net.SYNC_ASK_AFTER = 45   -- seconds after joining the channel before asking to catch up
Net.SYNC_DAYS = 7         -- catch-up covers reports this recent
Net.SYNC_BATCH = 60       -- reports sent per catch-up
Net.SYNC_ANSWER_AGAIN = 600 -- a player answers a catch-up at most this often
Net.SYNC_SAME = 1800      -- the same player is caught up at most this often

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

-- PURE. Hashes your own characters can have on the channel ("First Second", as Forever names
-- senders, plus the saved key and the first name alone), from TradebookDB.characters keys
-- ("First-Second"). Worked out on the fly, never stored.
function Net.OwnHashes(characters)
    local out = {}
    for key in pairs(characters or {}) do
        if type(key) == "string" then
            out[Net.Hash(key)] = true
            out[Net.Hash((key:gsub("-", " ")))] = true
            out[Net.Hash(key:match("^[^-]+") or key)] = true
        end
    end
    return out
end

-- PURE. Drop what your own characters "reported" from heard data: your scans and disenchants
-- passed back to you by other players (already saved, and they must not count as another
-- player agreeing). Returns how many entries were removed.
function Net.ForgetMine(heard, characters)
    if not heard then return 0 end
    local own, n = Net.OwnHashes(characters), 0
    for _, kind in ipairs({ "vendors", "trainers" }) do
        for npc, rec in pairs(heard[kind] or {}) do
            for who in pairs(rec.reports or {}) do
                if own[who] then rec.reports[who], n = nil, n + 1 end
            end
            if not next(rec.reports or {}) then heard[kind][npc] = nil end
        end
    end
    for who in pairs(heard.de or {}) do
        if own[who] then heard.de[who], n = nil, n + 1 end
    end
    for _, list in pairs(heard.confirms or {}) do
        for _, byWho in pairs(list) do
            for who in pairs(byWho) do
                if own[who] then byWho[who], n = nil, n + 1 end
            end
        end
    end
    return n
end

-- Is `who` (a sender hash) one of your own characters?
function Net.IsMine(who)
    return Net.OwnHashes(ns.db and ns.db.characters)[who] == true
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
-- { at, e, indirect } } } }), replacing that player's older report and, when full, the oldest
-- one. indirect: it was passed along by someone else (a catch-up), so it doesn't count toward
-- players agreeing (Net.Best). Returns true when kept; false when that player's report is
-- already there and no older (nothing new), or the list is full.
function Net.Record(heard, kind, npc, entry, who, now, indirect)
    heard[kind] = heard[kind] or {}
    local list = heard[kind]
    local rec = list[npc]
    local old = rec and rec.reports[who]
    if old and (old.e.seenAt or 0) >= (entry.seenAt or 0) and (indirect or not old.indirect) then
        return false
    end
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
    rec.reports[who] = { at = now, e = entry, indirect = indirect or nil }
    return true
end

-- PURE. The report most players agree with: entry, how many players agree (at least 1).
-- matches(a, b) says whether two reports describe the same NPC data. Only reports a player
-- sent directly count as agreeing; passed-along ones (indirect) are shown but count for none.
function Net.Best(rec, matches)
    local best, bestN, bestAt
    for _, r in pairs(rec and rec.reports or {}) do
        local n = 0
        for _, s in pairs(rec.reports) do
            if not s.indirect and (s == r or matches(r.e, s.e) or matches(s.e, r.e)) then n = n + 1 end
        end
        if not best or n > bestN or (n == bestN and (r.e.seenAt or 0) > (bestAt or 0)) then
            best, bestN, bestAt = r.e, n, r.e.seenAt
        end
    end
    if best and bestN < 1 then bestN = 1 end
    return best, bestN or 0
end

-- PURE. What to send a player catching up: the newest reports of the last `days` days, at
-- most `limit`: { { kind = "vendors"|"trainers", npc, who = original player (nil: your own
-- scan), e } }. heard: TradebookDB.heard; own: { vendors = ..., trainers = ... } your scans.
function Net.SyncReports(heard, own, now, days, limit)
    local cutoff = now - days * 86400
    local out = {}
    for _, kind in ipairs({ "vendors", "trainers" }) do
        for npc, e in pairs(own and own[kind] or {}) do
            if (e.seenAt or 0) > cutoff then out[#out + 1] = { kind = kind, npc = npc, e = e } end
        end
        for npc, rec in pairs(heard and heard[kind] or {}) do
            for who, r in pairs(rec.reports or {}) do
                if (r.e and r.e.seenAt or 0) > cutoff then
                    out[#out + 1] = { kind = kind, npc = npc, who = who, e = r.e }
                end
            end
        end
    end
    table.sort(out, function(a, b)
        local sa, sb = a.e.seenAt or 0, b.e.seenAt or 0
        if sa ~= sb then return sa > sb end
        if a.npc ~= b.npc then return a.npc < b.npc end
        return tostring(a.who) < tostring(b.who)
    end)
    for i = #out, limit + 1, -1 do out[i] = nil end
    return out
end

-- PURE. Take one whole share text from player `who` into `heard`. Returns how many NPCs were
-- kept, and what (for the maintainer's notifications, dev/TradebookDev):
--   { vendors = { [npcID] = { name, items = n, map = uiMapID } },
--     trainers = { [npcID] = { name, skill, services = n } },
--     confirmed = { { kind = "vendor" | "trainer", npc } }, confirms = n,
--     deBands = { [bandID] = checked totals }, disenchants = n bands }
function Net.Accept(heard, text, who, now, indirect)
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
        if clean and Net.Record(heard, "vendors", npc, clean, who, now, indirect) then
            kept = kept + 1
            info.vendors[npc] = { name = clean.name or "?", items = count(clean.items or {}),
                map = clean.loc and clean.loc.m }
        end
    end
    for npc, t in pairs(trainers or {}) do
        local clean = okID(npc) and Net.CleanTrainer(t, now)
        if clean and Net.Record(heard, "trainers", npc, clean, who, now, indirect) then
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

-- PURE. Lane i's channel name and addon-message prefix.
function Net.LaneName(i) return i == 1 and Net.CHANNEL or (Net.CHANNEL .. i) end
function Net.LanePrefix(i) return i == 1 and Net.PREFIX or (Net.PREFIX .. i) end

-- PURE. Which lane a prefix / channel name belongs to, or nil when it isn't Tradebook's.
function Net.LaneOfPrefix(prefix)
    if prefix == Net.PREFIX then return 1 end
    local n = tonumber(tostring(prefix):match("^" .. Net.PREFIX .. "(%d)$"))
    return n and n >= 2 and n <= Net.LANES and n or nil
end
function Net.LaneOfChannel(name)
    if name == Net.CHANNEL then return 1 end
    local n = tonumber(tostring(name):match("^" .. Net.CHANNEL .. "(%d)$"))
    return n and n >= 2 and n <= Net.LANES and n or nil
end

-- PURE. How many extra lanes (beyond lane 1) to join: `inUse` = chat channels the player is in,
-- lane 1 counted, the extra lanes not.
function Net.ExtraLanes(inUse, max, reserve, lanes)
    return math.max(0, math.min(lanes - 1, max - inUse - reserve))
end

-- PURE. What a SendAddonMessage result means: "sent", "backoff" (throttled: wait, then the same
-- message again) or "gone" (not in that channel any more). Older clients return nothing.
function Net.SendOutcome(result, enum)
    if result == nil or result == true or not enum then return "sent" end
    if result == enum.AddonMessageThrottle or result == enum.ChannelThrottle then return "backoff" end
    if (enum.InvalidChannel and result == enum.InvalidChannel)
        or (enum.NotInChannel and result == enum.NotInChannel) then return "gone" end
    return "sent" -- anything else: dropped, as before (it won't go out on a retry either)
end

---------------------------------------------------------------------------
-- In game: channel, sending queue, receiving
---------------------------------------------------------------------------

local asm = Net.NewAssembler()
local lanes = {}       -- [i] = { id = channel number or nil, queue, nextAt, pauseUntil }
for i = 1, Net.LANES do lanes[i] = { queue = {}, nextAt = 0, pauseUntil = 0 } end
local queue = lanes[1].queue -- lane 1: your own scans and control messages
local backlog = {}     -- { kind, npc } of your scans to re-announce, slowly
local lastBacklog = 0
local channelID
local msgCounter = 0
local session = ("%04x"):format(math.random(0, 0xffff)) -- this copy's tag on its messages
local selfSender -- how the channel names you (learned from your first echo)
local version = 0      -- bumped when heard data changes (caches)
local senders = {}     -- [who] = { minute, n }: flood protection
local cached = {}
local stats = { sent = 0, heard = 0, players = {}, relayed = 0, acked = 0, synced = 0, refused = 0 }
local collector = false -- this copy collects passed-along reports (dev/TradebookDev)
local relayQueue = {}   -- heard reports to pass along to a collector
local sentRelay = {}    -- [msgID] = the report it carried (marked relayed on the collector's ACK)
local answeredAt, collectorWho = nil, nil
local relayLanes, syncLanes = 1, 1 -- lanes the collector / the player catching up listens on
local collectorAt -- GetTime() of the last collector hello heard
local syncQueue = {}    -- catch-up reports to send (Net.SyncReports)
local syncPending = {}  -- [requester session] = true while waiting to answer it
local syncAnsweredAt    -- GetTime() of the last catch-up this copy answered
local syncAnswered = {} -- [who] = GetTime() they were last caught up by this copy
local syncAsked = false -- this session asked to catch up

local function enabled()
    return ns.db and ns.db.settings and ns.db.settings.netShare ~= false and not ns.fake
end

local function hideChannel(name)
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local cf = _G["ChatFrame" .. i]
        if cf then
            if ChatFrame_RemoveChannel then
                pcall(ChatFrame_RemoveChannel, cf, name)
            elseif ChatFrameUtil and ChatFrameUtil.RemoveChannel then
                pcall(ChatFrameUtil.RemoveChannel, cf, name)
            end
        end
    end
end

local function channelNumber(name)
    local id = Compat.Call("GetChannelName", name)
    return (tonumber(id) or 0) > 0 and id or nil
end

local function findChannel()
    channelID = channelNumber(Net.CHANNEL)
    lanes[1].id = channelID
    return channelID
end

-- Lanes in use, counted from lane 1 without a gap.
local function laneCount()
    local n = 0
    for i = 1, Net.LANES do
        if not lanes[i].id then break end
        n = i
    end
    return n
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
-- Hold all sending (the maintainer's send-rate test, dev/TradebookDev/RateTest.lua).
local held = false
function Net.Hold(on) held = on and true or false end

-- Share text of a passed-along report / a catch-up report.
local function bulkText(ref, sync)
    local build = Compat.Call("GetBuildInfo") or "?"
    local ver = Compat.Call("C_AddOns.GetAddOnMetadata", "Tradebook", "Version") or "?"
    local text
    if sync then
        text = ref.kind == "vendors" and ns.Share.Encode({ [ref.npc] = ref.e }, build, ver)
            or ns.Share.Encode({}, build, ver, { [ref.npc] = ref.e })
        if ref.who then text = Net.RelayText(text, ref.who) end
        return text
    end
    if ref.kind == "vendors" then
        text = ns.Share.Encode({ [ref.npc] = ref.rec.e }, build, ver)
    elseif ref.kind == "trainers" then
        text = ns.Share.Encode({}, build, ver, { [ref.npc] = ref.rec.e })
    else
        text = ns.Share.Encode({}, build, ver, nil, { disenchants = ref.rec.bands })
    end
    return text and Net.RelayText(text, ref.who)
end

-- An idle lane takes the next passed-along or catch-up report (if the receiver listens there).
local function fillBulk(i)
    local lane = lanes[i]
    if #relayQueue > 0 and i <= relayLanes then
        local ref = table.remove(relayQueue, 1)
        msgCounter = msgCounter + 1
        local id = session .. ("%x"):format(msgCounter)
        local text = bulkText(ref, false)
        local parts = text and Net.Chunk(text, id)
        if parts then
            for _, p in ipairs(parts) do lane.queue[#lane.queue + 1] = p end
            sentRelay[id] = ref
            stats.relayed = stats.relayed + 1
        end
    elseif #syncQueue > 0 and i <= syncLanes then
        local ref = table.remove(syncQueue, 1)
        msgCounter = msgCounter + 1
        local parts = Net.Chunk(bulkText(ref, true), session .. ("%x"):format(msgCounter))
        for _, p in ipairs(parts or {}) do lane.queue[#lane.queue + 1] = p end
        stats.synced = stats.synced + 1
    end
end

local function pump()
    if held or not enabled() or not channelID then return end
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
    local now = GetTime()
    -- Your recent scans again, slowly (lane 1).
    if #queue == 0 and #backlog > 0 and now - lastBacklog >= Net.BACKLOG_GAP then
        lastBacklog = now
        local job = table.remove(backlog, 1)
        announce(job.kind, job.npc, job.force)
    end
    local enum = Enum and Enum.SendAddonMessageResult
    for i, lane in ipairs(lanes) do
        if lane.id and now >= lane.nextAt and now >= lane.pauseUntil then
            if #lane.queue == 0 then fillBulk(i) end
            local msg = lane.queue[1]
            if msg then
                lane.nextAt = now + Net.INTERVAL
                local result = Compat.Call("C_ChatInfo.SendAddonMessage", Net.LanePrefix(i), msg, "CHANNEL", lane.id)
                local outcome = Net.SendOutcome(result, enum)
                if outcome == "backoff" then
                    lane.pauseUntil = now + Net.BACKOFF
                    stats.refused = stats.refused + 1
                    ns.Debug("net: channel", i, "throttled, waiting", Net.BACKOFF, "s")
                elseif outcome == "gone" and i > 1 then
                    -- Not in that channel any more: its messages go on lane 1.
                    for _, m in ipairs(lane.queue) do queue[#queue + 1] = m end
                    lane.queue, lane.id = {}, nil
                    ns.Debug("net: lost channel", i)
                else
                    table.remove(lane.queue, 1)
                    stats.sent = stats.sent + 1
                end
            end
        end
    end
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

-- Extra lanes: join as many as leave CHANNEL_RESERVE chat channels free; leave the rest.
local function joinLanes()
    local list = { Compat.Call("GetChannelList") }
    local inUse = 0
    for i = 1, #list, 3 do
        local lane = Net.LaneOfChannel(tostring(list[i + 1]))
        if not (lane and lane > 1) then inUse = inUse + 1 end
    end
    local want = 1 + Net.ExtraLanes(inUse, Net.MAX_CHAT_CHANNELS, Net.CHANNEL_RESERVE, Net.LANES)
    for i = 2, Net.LANES do
        local name = Net.LaneName(i)
        if i <= want then
            if not channelNumber(name) then Compat.Call("JoinTemporaryChannel", name) end
        elseif channelNumber(name) then
            Compat.Call("LeaveChannelByName", name)
        end
    end
    C_Timer.After(2, function()
        for i = 2, Net.LANES do
            local name = Net.LaneName(i)
            lanes[i].id = i <= want and channelNumber(name) or nil
            if lanes[i].id then hideChannel(name) end
        end
        ns.Debug("net: sharing on", laneCount(), "channels (" .. inUse, "chat channels in use)")
    end)
end

local function join()
    if not enabled() then return end
    if not findChannel() then Compat.Call("JoinTemporaryChannel", Net.CHANNEL) end
    C_Timer.After(2, function()
        if findChannel() then
            hideChannel(Net.CHANNEL)
            ns.Debug("net: in channel", channelID)
            joinLanes()
            -- Ask the players online for what you missed (once a session), saying how many
            -- lanes you listen on.
            if not syncAsked then
                syncAsked = true
                C_Timer.After(Net.SYNC_ASK_AFTER, function()
                    if enabled() and channelID then
                        control("SYNC", tostring(laneCount()))
                        ns.Debug("net: asked to catch up")
                    end
                end)
            end
        else
            ns.Debug("net: could not join the channel")
        end
    end)
end

-- This copy collects passed-along reports (dev/TradebookDev). Says hello now and regularly.
function Net.SetCollector(on)
    collector = on and true or false
    if collector then
        local function hello() if enabled() and channelID then control("HELLO", tostring(laneCount())) end end
        C_Timer.After(30, hello)
        C_Timer.NewTicker(Net.COLLECTOR_HELLO, hello)
    end
end

-- Turn sharing on or off (the setting).
function Net.SetEnabled(on)
    ns.db.settings.netShare = on and true or false
    if on then
        join()
        fillBacklog()
    else
        backlog = {}
        for i, lane in ipairs(lanes) do
            for k = #lane.queue, 1, -1 do lane.queue[k] = nil end
            if channelNumber(Net.LaneName(i)) then Compat.Call("LeaveChannelByName", Net.LaneName(i)) end
            lane.id = nil
        end
        channelID = nil
    end
end

local function onAddonMessage(_, prefix, text, chatType, sender)
    if not Net.LaneOfPrefix(prefix) or chatType ~= "CHANNEL" or not enabled() then return end
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
            relayLanes = math.max(1, math.min(Net.LANES, tonumber(arg) or 1))
            local now = GetTime()
            if not answeredAt or now - answeredAt >= Net.RELAY_AGAIN then
                answeredAt = now
                C_Timer.After(5 + math.random(0, 55), function()
                    fillBacklog(true)
                    relayQueue = Net.Unrelayed(ns.db.heard, Net.RELAY_BATCH, collectorWho)
                    ns.Debug("net: collector online,", #backlog, "own scans and", #relayQueue, "heard reports to send")
                end)
            end
        elseif what == "SYNC" then
            -- A player came online and asks to catch up: answer after a random wait, unless
            -- someone else starts first (SYNCFOR), or you answered lately.
            local asker = tostring(text):match("^(%w+)~CTL~")
            local now = GetTime()
            if asker and not syncPending[asker]
                and not (syncAnsweredAt and now - syncAnsweredAt < Net.SYNC_ANSWER_AGAIN)
                and not (syncAnswered[who] and now - syncAnswered[who] < Net.SYNC_SAME) then
                syncPending[asker] = true
                C_Timer.After(3 + math.random(0, 17), function()
                    if not syncPending[asker] then return end
                    syncPending[asker] = nil
                    if not (enabled() and channelID) then return end
                    syncAnsweredAt, syncAnswered[who] = GetTime(), GetTime()
                    syncLanes = math.max(1, math.min(Net.LANES, tonumber(arg) or 1))
                    control("SYNCFOR", asker)
                    syncQueue = Net.SyncReports(ns.db.heard, { vendors = ns.db.vendors, trainers = ns.db.trainers },
                        GetServerTime(), Net.SYNC_DAYS, Net.SYNC_BATCH)
                    ns.Debug("net: catching a player up,", #syncQueue, "reports")
                end)
            end
        elseif what == "SYNCFOR" then
            syncPending[arg] = nil -- someone else is answering that player
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
    -- Passed along by `who` for another player (to a collector, or to catch someone up): kept
    -- as that player's. A collector confirms it got it (ACK); everyone else keeps it as passed
    -- along (indirect), shown but not counted toward players agreeing.
    local relayed, relayText = Net.ParseRelay(full)
    local indirect = false
    if relayed then
        if collector then control("ACK", msgID) else indirect = true end
        -- Your own data, back again (this character, or another of yours: already saved).
        if (selfSender and relayed == Net.Hash(selfSender)) or Net.IsMine(relayed) then return end
        who, full = relayed, relayText
    end
    local kept, info = Net.Accept(ns.db.heard, full, who, GetServerTime(), indirect)
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

local function waiting()
    local n = 0
    for _, lane in ipairs(lanes) do n = n + #lane.queue end
    return n
end

-- Status lines for /tb net.
function Net.Status()
    local heard = ns.db and ns.db.heard or {}
    return {
        ("Sharing: %s, channel: %s, %d of %d channels%s"):format(enabled() and "on" or "off",
            channelID and tostring(channelID) or "not joined", laneCount(), Net.LANES,
            enabled() and pauseReason() and (" (paused: " .. pauseReason() .. ")") or ""),
        ("This session: %d messages sent (%d refused, waited), %d NPC reports heard from %d players"):format(
            stats.sent, stats.refused, stats.heard, count(stats.players)),
        ("Waiting to send: %d messages, %d NPCs to re-announce, %d catch-up reports"):format(waiting(), #backlog,
            #syncQueue),
        ("Heard so far: %d vendors, %d trainers, disenchants from %d players"):format(count(heard.vendors or {}),
            count(heard.trainers or {}), count(heard.de or {})),
        collector and "Collecting: other players pass along what they heard to you"
            or ("Passing along to a collector: %d heard reports waiting, %d sent and received this session"):format(
                #Net.Unrelayed(heard, 100000, collectorWho), stats.acked),
    }
end

function Net.Start()
    -- Your own scans passed back to you earlier: drop them (Net.ForgetMine).
    if ns.db and ns.db.heard then
        local n = Net.ForgetMine(ns.db.heard, ns.db.characters)
        if n > 0 then
            changed()
            ns.Debug("net: dropped", n, "of your own reports passed back to you")
        end
    end
    for i = 1, Net.LANES do Compat.Call("C_ChatInfo.RegisterAddonMessagePrefix", Net.LanePrefix(i)) end
    ns.On("CHAT_MSG_ADDON", onAddonMessage)
    ns.On("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(10, join)
    end)
    -- Joining a channel right at login can fail while the chat system starts; try again later.
    C_Timer.After(60, function() if not channelID then join() end end)
    C_Timer.After(90, function() if enabled() then fillBacklog() end end)
    C_Timer.NewTicker(Net.TICK, pump)
end
