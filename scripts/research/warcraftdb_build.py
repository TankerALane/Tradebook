import sys
import json, os, re, csv, sys, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from warcraftdb_fetch import get, tab_all, SP, SKIP
sys.stdout.reconfigure(encoding='utf-8')
R = os.path.join(SP, 'recipes')
FETCH_NPCS = '--npcs' in sys.argv
inv = json.load(open(os.path.join(R, 'inventory.json'), encoding='utf-8'))
qnpc = json.load(open(os.path.join(R, 'qdb', 'qdb_npc.json'), encoding='utf-8'))
qobj = json.load(open(os.path.join(R, 'qdb', 'qdb_object.json'), encoding='utf-8'))
qitem = json.load(open(os.path.join(R, 'qdb', 'qdb_item.json'), encoding='utf-8'))
area = {}
with open(os.path.join(R, 'wago', 'AreaTable.csv'), encoding='utf-8') as f:
    for row in csv.DictReader(f):
        area[int(row['ID'])] = row['AreaName_lang']


def strip(h):
    return re.sub(r'<[^>]+>', '', h or '').strip() or None


def zid(h):
    m = re.search(r'/data/zone/(\d+)', h or '')
    return int(m.group(1)) if m else None


def faction(h):
    if not h:
        return None
    s = []
    if 'faction-horde' in h: s.append('Horde')
    if 'faction-alliance' in h: s.append('Alliance')
    return ' '.join(s + [strip(h) or '']).strip() or None


def qzone(rec):
    if not rec:
        return None
    sp = rec.get('7') or {}
    if isinstance(sp, list):  # Lua array keyed 1..n (areaID 1 = Dun Morogh) decoded as JSON list
        sp = {str(i + 1): v for i, v in enumerate(sp) if v}
    if sp:
        a = max(sp, key=lambda k: len(sp[k] or []))
        return {'areaID': int(a), 'name': area.get(int(a)), 'spawnPoints': len(sp[a] or [])}
    z = rec.get('9')
    return {'areaID': z, 'name': area.get(z)} if z else None


def npc_info(nid):
    if not FETCH_NPCS:
        return {}
    r = get(f'npc/{nid}')
    b = r.get('body') or {}
    d = b.get('data') or {}
    m = (b.get('extra') or {}).get('npc_map') or {}
    fl = {f['id']: f['name'] for f in m.get('floors') or []}
    c = collections.Counter(p.get('ui_map_id') for p in m.get('pins') or [])
    zones = [{'uiMapID': k, 'name': fl.get(k), 'pins': v} for k, v in c.most_common()]
    return {'wdbNpcFound': r.get('_status') == 200, 'wdbLevel': d.get('level'), 'wdbZones': zones or None,
            'wdbReaction': strip(d.get('reaction'))}


out = []
for rec in inv:
    e = {k: rec[k] for k in ('recipeSpellID', 'recipeName', 'profession', 'status')}
    e['items'] = []
    for iid in rec.get('recipeItemIDs') or []:
        qi = qitem.get(str(iid)) or {}
        qdrops = set(qi.get('2') or [])
        qobjs = set(qi.get('3') or [])
        node = get(f'item/{iid}')
        st = node.get('_status')
        it = {'itemID': iid, 'exists': True if st == 200 else (False if st == 404 else None)}
        if it['exists'] is None:
            it['fetchError'] = node.get('err')
        b = node.get('body') or {}
        d = b.get('data') or {}
        it['wdbName'] = d.get('name')
        it['questieName'] = qi.get('1')
        it['tabs'] = [t['slug'] for t in b.get('tabs') or [] if t['slug'] not in ('screenshots', 'comments')]
        it['droppedBy'], it['objects'], it['soldBy'], it['rewardFrom'], it['containedIn'], it['other'] = [], [], [], [], [], {}
        if d.get('source'):
            it['other']['sourceField'] = d.get('source')
        for t in b.get('tabs') or []:
            s = t['slug']
            if s in SKIP or not t.get('count'):
                continue
            rows = tab_all('item', iid, s)
            if s == 'dropped-by':
                for x in rows:
                    base = {'name': x.get('name'), 'chance': x.get('chance'), 'dropChance': x.get('drop_chance'),
                            'lootType': x.get('loot_type_label'), 'sample': x.get('sample'),
                            'quantity': x.get('quantity'), 'quest': x.get('quest_label') or None}
                    ln = x.get('link_node')
                    sid = x.get('source_id')
                    if ln == 'npc':
                        qr = qnpc.get(str(sid))
                        base = {'npcID': sid, **base, **npc_info(sid), 'questieAgrees': sid in qdrops,
                                'questieNpcKnown': qr is not None,
                                'questieLevel': [qr.get('4'), qr.get('5')] if qr else None,
                                'questieZone': qzone(qr)}
                        it['droppedBy'].append(base)
                    elif ln == 'object':
                        it['objects'].append({'objectID': sid, **base, 'questieAgrees': sid in qobjs,
                                              'questieZone': qzone(qobj.get(str(sid)))})
                    elif ln == 'item':
                        it['containedIn'].append({'itemID': sid, **base})
                    else:
                        it['other'].setdefault('dropped-by:' + str(ln), []).append(x)
            elif s == 'sold-by':
                for x in rows:
                    it['soldBy'].append({'npcID': x.get('npc_id'), 'name': x.get('name'), 'cost': x.get('cost'),
                                         'stock': x.get('stock'), 'maxCount': x.get('max_count'),
                                         'zone': strip(x.get('location')), 'uiMapID': zid(x.get('location')),
                                         'reaction': faction(x.get('reaction'))})
            elif s == 'reward-from':
                for x in rows:
                    it['rewardFrom'].append({'questID': x.get('id'), 'name': x.get('name'),
                                             'rewardType': x.get('reward_type'), 'zone': x.get('zone'),
                                             'zoneID': x.get('zone_id')})
            elif s.startswith('contained-in'):
                for x in rows:
                    ln = x.get('link_node') or ('object' if 'object' in s else 'item')
                    entry = {'id': x.get('source_id') or x.get('ID') or x.get('id'), 'kind': ln, 'name': x.get('name'),
                             'chance': x.get('chance'), 'dropChance': x.get('drop_chance'), 'sample': x.get('sample')}
                    (it['objects'] if ln == 'object' else it['containedIn']).append(entry)
            else:
                it['other'][s] = rows
        # questie drop list for comparison (droppers Questie has that wdb lacks)
        wd = {x['npcID'] for x in it['droppedBy']}
        it['questieOnlyDroppers'] = [{'npcID': n, 'name': (qnpc.get(str(n)) or {}).get('1'),
                                      'questieZone': qzone(qnpc.get(str(n)))} for n in sorted(qdrops - wd)]
        for k in ('droppedBy', 'objects', 'containedIn'):
            it[k].sort(key=lambda x: -(x.get('chance') or 0))
        e['items'].append(it)
    out.append(e)
json.dump(out, open(os.path.join(R, 'wdb_sources.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('wrote', len(out))
