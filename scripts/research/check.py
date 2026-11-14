"""Cross-check Tradebook (LibProfessionDB-derived) recipe vendors against WoW Forever data.

Inputs (all in this folder):
  vendor_recipes.json            - the 321 entries to check
  wago/*.csv                     - wago.tools DB2 exports, build 1.60.1.70938 (wowf)
  qdb/qdb_{item,npc,object,quest}.json - produced by qdb_parse.py from the local QuestieDB_Forever.toc
Outputs: local_check.json
Run: python -I check.py
"""
import csv, json, os, collections

HERE = os.path.dirname(os.path.abspath(__file__))
W = os.path.join(HERE, 'wago')


def rcsv(name):
    with open(os.path.join(W, name + '.csv'), encoding='utf-8', newline='') as f:
        return list(csv.DictReader(f))


def rjson(name):
    with open(os.path.join(HERE, name), encoding='utf-8') as f:
        return json.load(f)


entries = rjson('vendor_recipes.json')
qi, qn, qo, qq = (rjson('qdb/qdb_%s.json' % e) for e in ('item', 'npc', 'object', 'quest'))

# ---- wago tables
ie = {r['ID']: r for r in rcsv('ItemEffect')}
ixe = rcsv('ItemXItemEffect')
sparse = {r['ID']: r for r in rcsv('ItemSparse')}
itemtab = {r['ID']: r for r in rcsv('Item')}
learn36 = collections.defaultdict(set)  # spell -> spells it teaches via Effect 36 LEARN_SPELL
for r in rcsv('SpellEffect'):
    if r['Effect'] == '36' and r['EffectTriggerSpell'] not in ('', '0'):
        learn36[r['SpellID']].add(r['EffectTriggerSpell'])
area = {r['ID']: r['AreaName_lang'] for r in rcsv('AreaTable')}

# spell -> {itemID: method}
taught_by = collections.defaultdict(dict)
for x in ixe:
    e = ie.get(x['ItemEffectID'])
    if not e:
        continue
    item, sp = x['ItemID'], e['SpellID']
    if e['TriggerType'] == '6':  # ITEM_SPELLTRIGGER_LEARN_SPELL_ID: SpellID is the taught spell itself
        taught_by[sp].setdefault(item, 'ItemEffect.TriggerType=6 SpellID')
    for t in learn36.get(sp, ()):  # on-use spell with Effect 36 LEARN_SPELL -> EffectTriggerSpell
        taught_by[t].setdefault(item, 'ItemEffect(SpellID=%s) -> SpellEffect Effect=36 EffectTriggerSpell' % sp)

# Questie's own teachesSpell field (item field 16) as a secondary link
for iid, r in qi.items():
    if '16' in r:
        taught_by[str(r['16'])].setdefault(iid, 'QuestieDB item.teachesSpell')

FRIEND = {'A': 'Alliance', 'H': 'Horde', 'AH': 'Both'}


def npcinfo(nid):
    r = qn.get(str(nid))
    if r is None:
        return {'npcID': nid, 'name': None, 'inQuestieDB': False}
    z = r.get('9')
    sp = r.get('7') or {}
    if isinstance(sp, list):  # dense CBOR array = Lua table keyed 1..n (zone 1 = Dun Morogh)
        sp = {str(i + 1): v for i, v in enumerate(sp) if v}
    zones = sorted(set(int(k) for k in sp.keys()))
    return {'npcID': nid, 'name': r.get('1'), 'subName': r.get('14'), 'zoneID': z, 'zone': area.get(str(z)) if z else None,
            'spawnZones': [area.get(str(k), str(k)) for k in zones],
            'faction': FRIEND.get(r.get('13'), 'Hostile/none' if r.get('13') is None else r.get('13')),
            'hasSpawns': bool(r.get('7')), 'vendorFlag': bool((r.get('15') or 0) & 4), 'inQuestieDB': True}


def named(ids, table):
    return [{'id': i, 'name': (table.get(str(i)) or {}).get('1')} for i in ids]


out = []
for e in entries:
    sid = str(e['recipeSpellID'])
    items = taught_by.get(sid, {})
    rec = {'recipeSpellID': e['recipeSpellID'], 'recipeName': e['recipeName'], 'profession': e['profession'] or 'Rank book',
           'requiredSkill': e.get('requiredSkill'), 'recipeItems': [], 'questieVendors': [],
           'libVendors': [], 'status': None}
    libv = {v['npcID'] for v in e['vendors']}
    for v in e['vendors']:
        info = npcinfo(v['npcID'])
        info['libName'] = v['name']
        rec['libVendors'].append(info)
    rec['libVendorsMissingFromQuestieNPCs'] = [v['npcID'] for v in rec['libVendors'] if not v['inQuestieDB']]
    qv = set()
    other = {'npcDrops': [], 'objectDrops': [], 'itemDrops': [], 'questRewards': [], 'startQuest': None}
    item_in_qdb = False
    for iid, how in sorted(items.items(), key=lambda kv: int(kv[0])):
        sp = sparse.get(iid, {})
        q = qi.get(iid)
        it = itemtab.get(iid, {})
        rec['recipeItems'].append({'itemID': int(iid), 'name': sp.get('Display_lang') or (q or {}).get('1'),
                                   'wagoClass': '%s/%s' % (it.get('ClassID'), it.get('SubclassID')) if it else None,
                                   'linkMethod': how, 'inQuestieDB': q is not None,
                                   'questieTeachesSpell': (q or {}).get('16')})
        if q is None:
            continue
        item_in_qdb = True
        qv |= set(q.get('14') or [])
        other['npcDrops'] += q.get('2') or []
        other['objectDrops'] += q.get('3') or []
        other['itemDrops'] += q.get('4') or []
        other['questRewards'] += q.get('6') or []
        if q.get('5'):
            other['startQuest'] = q['5']
    rec['questieVendors'] = [npcinfo(n) for n in sorted(qv)]
    if not items:
        rec['status'] = 'no_item'
    elif not qv:
        rec['status'] = 'questie_none'
        if not item_in_qdb:
            rec['note'] = 'recipe item(s) exist in Forever DB2 but not in QuestieDB item data'
    elif qv == libv:
        rec['status'] = 'agree'
    elif qv & libv:
        rec['status'] = 'partial'
    else:
        rec['status'] = 'disagree'
    if qv and libv != qv:
        rec['libOnly'] = sorted(libv - qv)
        rec['questieOnly'] = sorted(qv - libv)
    if any(other[k] for k in other):
        rec['questieOtherSources'] = {
            'npcDrops': named(sorted(set(other['npcDrops'])), qn),
            'objectDrops': named(sorted(set(other['objectDrops'])), qo),
            'itemDrops': named(sorted(set(other['itemDrops'])), qi),
            'questRewards': named(sorted(set(other['questRewards'])), qq),
            'startQuest': other['startQuest'],
        }
        rec['questieOtherSources'] = {k: v for k, v in rec['questieOtherSources'].items() if v}
    out.append(rec)

with open(os.path.join(HERE, 'local_check.json'), 'w', encoding='utf-8') as f:
    json.dump(out, f, indent=1, ensure_ascii=False)

c = collections.Counter(r['status'] for r in out)
print(c)
pp = collections.defaultdict(collections.Counter)
for r in out:
    pp[r['profession']][r['status']] += 1
for k, v in sorted(pp.items()):
    print(k, dict(v))
print('lib vendors missing from Questie NPCs:', sorted({n for r in out for n in r['libVendorsMissingFromQuestieNPCs']}))
print('link methods:', collections.Counter(i['linkMethod'].split(' ')[0] for r in out for i in r['recipeItems']))
print('multi-item:', [(r['recipeName'], [i['itemID'] for i in r['recipeItems']]) for r in out if len(r['recipeItems']) > 1])
