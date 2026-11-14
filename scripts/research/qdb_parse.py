"""Parse QuestieDB (WoW Forever, baked mode) TOC metadata store into JSON.

Format (from src/read/baked.lua + src/meta/*Meta.lua):
  ## X-<Entity>-<id>-S: base64(CBOR map)  -> scalar row {fieldIndex: value, "p": presence bitmask of table fields}
  ## X-<Entity>-<id>-<fieldIndex>: base64(CBOR) -> table field value
  value "~N~" => chunked; parts in key-1 .. key-N, concatenated.
  ## X-<Entity>-IDS: base64(zlib(CBOR array)) (not needed; ids come from keys).
Static corrections are already folded in at generation time (correction files' Load() bodies are stripped).
Usage: python -I qdb_parse.py <path to QuestieDB_Forever.toc> <outdir>
"""
import sys, re, base64, json, struct, os


def cbor_decode(b):
    pos = 0

    def read(n):
        nonlocal pos
        r = b[pos:pos + n]
        pos += n
        return r

    def arg(ai):
        if ai < 24:
            return ai
        if ai == 24:
            return read(1)[0]
        if ai == 25:
            return struct.unpack('>H', read(2))[0]
        if ai == 26:
            return struct.unpack('>I', read(4))[0]
        if ai == 27:
            return struct.unpack('>Q', read(8))[0]
        if ai == 31:
            return None
        raise ValueError('bad ai %d' % ai)

    def item():
        nonlocal pos
        ib = read(1)[0]
        mt, ai = ib >> 5, ib & 31
        if mt == 0:
            return arg(ai)
        if mt == 1:
            return -1 - arg(ai)
        if mt in (2, 3):
            n = arg(ai)
            if n is None:
                parts = []
                while b[pos] != 0xff:
                    parts.append(item())
                pos += 1
                return ''.join(parts) if mt == 3 else ''.join(p if isinstance(p, str) else p.decode('utf-8', 'replace') for p in parts)
            raw = read(n)
            return raw.decode('utf-8', 'replace')
        if mt == 4:
            n = arg(ai)
            out = []
            if n is None:
                while b[pos] != 0xff:
                    out.append(item())
                pos += 1
            else:
                for _ in range(n):
                    out.append(item())
            return out
        if mt == 5:
            n = arg(ai)
            out = {}
            if n is None:
                while b[pos] != 0xff:
                    k = item(); out[k] = item()
                pos += 1
            else:
                for _ in range(n):
                    k = item(); out[k] = item()
            return out
        if mt == 6:
            arg(ai)
            return item()
        if mt == 7:
            if ai == 20: return False
            if ai == 21: return True
            if ai in (22, 23): return None
            if ai == 25:
                h = struct.unpack('>e', read(2))[0]; return h
            if ai == 26:
                return struct.unpack('>f', read(4))[0]
            if ai == 27:
                return struct.unpack('>d', read(8))[0]
            raise ValueError('simple %d' % ai)
    return item()


def main(toc, outdir):
    store = {}
    rx = re.compile(r'^## (X-(?:Item|Npc|Object|Quest)-[^:]+): (.*)$')
    with open(toc, encoding='utf-8') as f:
        for line in f:
            m = rx.match(line.rstrip('\r\n'))
            if m:
                store[m.group(1)] = m.group(2)

    def get(key):
        v = store.get(key)
        if v is None:
            return None
        m = re.match(r'^~(\d+)~$', v)
        if m:
            return ''.join(store[key + '-' + str(i)] for i in range(1, int(m.group(1)) + 1))
        return v

    def dec(v):
        return cbor_decode(base64.b64decode(v))

    out = {}
    for ent, tablefields, fieldcount in (('Item', {2, 3, 4, 6, 14, 15}, 16), ('Npc', {7, 8, 10, 11}, 15), ('Object', set(), 0), ('Quest', set(), 0)):
        ids = set()
        rid = re.compile(r'^X-%s-(\d+)-S$' % ent)
        for k in store:
            m = rid.match(k)
            if m:
                ids.add(int(m.group(1)))
        rows = {}
        for i in sorted(ids):
            row = dec(get('X-%s-%d-S' % (ent, i)))
            if isinstance(row, list):  # dense CBOR array => Lua sequence, 1-based
                row = {n + 1: v for n, v in enumerate(row) if v is not None}
            rec = {str(k): v for k, v in row.items()}
            p = row.get('p', 0) or 0
            # table fields: read any present key regardless (also respect presence mask)
            for fi in range(1, 20):
                k = 'X-%s-%d-%d' % (ent, i, fi)
                if k in store:
                    rec[str(fi)] = dec(get(k))
                    rec.setdefault('_presenceOK', True)
                    if not (p >> (fi - 1)) & 1:
                        rec['_presenceMismatch'] = rec.get('_presenceMismatch', []) + [fi]
            rows[i] = rec
        out[ent] = rows
        print(ent, len(rows))
    for ent, rows in out.items():
        with open(os.path.join(outdir, 'qdb_%s.json' % ent.lower()), 'w', encoding='utf-8') as f:
            json.dump(rows, f, ensure_ascii=False, default=str)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
