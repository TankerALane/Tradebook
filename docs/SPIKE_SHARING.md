# Sharing test: can Tradebook copies share NPC data in game? (about 10 minutes)

**Tradebook Net Test** is already linked into your AddOns folder. It's a throwaway test addon, and it doesn't touch Tradebook. Everything is saved to its SavedVariables, so do the steps, then `/reload` and tell me "net test done". Notes in brackets are things I can't see in the data, so tell me what you saw.

Other players are only ever logged as "self" or "other", never by name.

## A. In a city
1. Fully restart WoW (it's a new addon), and enable **Tradebook Net Test** in the AddOns list.
2. `/tbn test`, then wait about 30 seconds until chat says "Done" and lists the results. [Did a "TradebookNetTest" channel appear in your chat window or chat tabs, or did any text from it show in chat?][ ]
3. `/reload`.

## B. In a dungeon
4. Go into any dungeon (just inside the entrance is enough), run `/tbn test` again and wait for "Done".
5. `/reload`.

## C. With another player (if you can)
This step is the real proof that messages reach other players. It needs someone else running the test addon at the same time: a friend, a guildmate, or a second WoW account of your own.

6. Both of you type `/tbn ping`. [Did chat say "Heard a ping from another player" for both of you?][ ]
7. `/reload`.

## D. Afterwards
8. `/tbn leave`, then disable **Tradebook Net Test**.

## Notes / errors
