import json, sys, time, os, re, urllib.request, urllib.error, hashlib
# Working folder (inventory.json, the cache): first argument, or the current folder.
SP = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith('-') else os.getcwd()
CACHE = os.path.join(SP, 'recipes', 'wdb_cache')
BASE = 'https://forever.warcraftdb.com/api/data/node/'
UA = 'TradebookDataBot/1.0 (WoW addon recipe-source research; python-urllib)'
SKIP = {'screenshots', 'comments', 'teaches', 'can-be-placed-in', 'reagent-for'}
last = [0.0]

def cpath(p):
    return os.path.join(CACHE, re.sub(r'[^A-Za-z0-9_.-]', '_', p) + '.json')

def get(p):
    fp = cpath(p)
    if os.path.exists(fp):
        return json.load(open(fp, encoding='utf-8'))
    res = None
    for i in range(5):
        dt = time.time() - last[0]
        if dt < 0.55: time.sleep(0.55 - dt)
        last[0] = time.time()
        try:
            req = urllib.request.Request(BASE + p, headers={'User-Agent': UA, 'Accept': 'application/json'})
            with urllib.request.urlopen(req, timeout=30) as r:
                res = {'_status': 200, 'body': json.loads(r.read().decode('utf-8'))}
                break
        except urllib.error.HTTPError as e:
            if e.code == 404:
                res = {'_status': 404}; break
            err = f'HTTP {e.code}'
        except Exception as e:
            err = str(e)
        time.sleep(2 ** i)
    if res is None:
        print('FAIL', p, err, flush=True); return {'_status': 'error', 'err': err}
    json.dump(res, open(fp, 'w', encoding='utf-8'), ensure_ascii=False)
    return res

def tab_all(node, i, slug):
    rows, pg = [], 1
    while True:
        r = get(f'{node}/{i}/tab/{slug}?page={pg}')
        b = r.get('body') or {}
        rows += b.get('rows') or []
        if pg >= (b.get('pages') or 1): break
        pg += 1
    return rows

if __name__ == '__main__':
    inv = json.load(open(os.path.join(SP, 'recipes', 'inventory.json'), encoding='utf-8'))
    order = {'unknown': 0, 'notYet': 1, 'known': 2}
    ids = []
    for r in sorted(inv, key=lambda r: order.get(r['status'], 3)):
        for i in r.get('recipeItemIDs') or []:
            if i not in ids: ids.append(i)
    print(len(ids), 'items', flush=True)
    for n, i in enumerate(ids):
        r = get(f'item/{i}')
        b = r.get('body') or {}
        for t in b.get('tabs') or []:
            if t['slug'] in SKIP or not t.get('count'): continue
            tab_all('item', i, t['slug'])
        if n % 50 == 0: print(n, i, flush=True)
    print('done items', flush=True)
