# Testing — round 8: in-game sharing, Find Herbs / Find Minerals

Fully restart WoW first (new files). Notes in brackets are things I can't see in the data.

## A. Find Herbs / Find Minerals
- [ ] On the Herbalism and Mining tabs, the spell icon and its name sit on their own row above the search box. Dragging it to an action bar works; clicking it starts tracking.
- [ ] In combat, the Tradebook window still closes, and the icon works again after combat.

## B. Sharing in game
- [ ] `/tb net` about 15 seconds after logging in: "Sharing: on, channel: <number>". [Did a "TradebookShare" channel or any text from it show in chat?]
- [ ] Open a vendor, wait about 10 seconds, then `/tb net`: "messages sent" went up.
- [ ] Settings (`/tb options`): "Share vendor and trainer data with other Tradebook users in game" is ticked. Unticking it and running `/tb net` says "Sharing: off"; ticking it again joins the channel again.
- [X] In a dungeon, nothing is sent: `/tb net test` outside, zone in within ~15 seconds, `/tb net` inside (first line says "paused: in a dungeon", "Waiting to send" stays the same for 30 seconds), zone out, `/tb net` again (the rest goes out), then `/reload`.
- [ ] Your chat channel numbers (General, Trade, LocalDefense...) are unchanged.
- [ ] With another Tradebook user (when you can): after one of you opens a vendor, the other's `/tb net` shows "NPC reports heard from 1 players", and the vendor shows in the Vendors tab with "(unconfirmed)".

## Notes / errors
