"""Search Wikimedia Commons for freely licensed images, and fetch one with its licence details.

    python3 -I tools/decks/commons_search.py search "Lawrenceburg Indiana distillery" "Seagram 1940s"
    python3 -I tools/decks/commons_search.py info "File:Some exact name.jpg"
    python3 -I tools/decks/commons_search.py get "File:Some exact name.jpg" <out_dir>/<shortname>.jpg

`info` prints the licence, author, date and description from the file page's metadata.
`get` downloads a copy up to 1920 px wide and prints the same details. Read the licence
yourself and look at the image before using it; credit it in the outline's image credits.
Commons rate-limits automated clients: keep searches specific and few, and the script waits
between requests.
"""
import json
import subprocess
import sys
import time
import urllib.parse

UA = 'WSS-deck-research/1.0 (image research for tasting decks)'
API = 'https://commons.wikimedia.org/w/api.php?'


def fetch(url, out=None):
    cmd = ['curl', '-sS', '-L', '-m', '90', '-A', UA, url]
    if out:
        cmd += ['-o', out]
    for attempt in range(3):
        r = subprocess.run(cmd, capture_output=True, text=not out)
        if r.returncode == 0:
            return r.stdout
        time.sleep(20 * (attempt + 1))
    raise SystemExit('fetch failed: %s' % url)


def api(**params):
    params.setdefault('format', 'json')
    text = fetch(API + urllib.parse.urlencode(params))
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        raise SystemExit('Commons returned something that is not JSON (rate limited?). Wait a minute and retry.')


def search(terms):
    for q in terms:
        res = api(action='query', list='search', srnamespace=6, srlimit=20, srsearch=q)
        print('##', q)
        for r in res.get('query', {}).get('search', []):
            if not r['title'].lower().endswith('.pdf'):
                print(' -', r['title'])
        time.sleep(5)


def details(title):
    res = api(action='query', prop='imageinfo', iiprop='url|extmetadata|size', iiurlwidth=1920, titles=title)
    page = next(iter(res['query']['pages'].values()))
    if 'imageinfo' not in page:
        raise SystemExit('no such file: %s' % title)
    info = page['imageinfo'][0]
    meta = info.get('extmetadata', {})

    def m(key):
        return (meta.get(key, {}).get('value') or '').strip()

    print('file:       ', title)
    print('page:       ', info.get('descriptionurl'))
    print('size:       ', info.get('width'), 'x', info.get('height'))
    print('licence:    ', m('LicenseShortName'), m('LicenseUrl'))
    print('usage terms:', m('UsageTerms'))
    print('attribution required:', m('AttributionRequired'))
    print('author:     ', m('Artist')[:300])
    print('credit:     ', m('Credit')[:300])
    print('date:       ', m('DateTimeOriginal') or m('DateTime'))
    print('description:', m('ImageDescription')[:400])
    return info


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    cmd = sys.argv[1]
    if cmd == 'search':
        search(sys.argv[2:])
    elif cmd == 'info':
        details(sys.argv[2])
    elif cmd == 'get' and len(sys.argv) == 4:
        info = details(sys.argv[2])
        fetch(info.get('thumburl') or info['url'], out=sys.argv[3])
        print('saved:      ', sys.argv[3])
    else:
        raise SystemExit(__doc__)


if __name__ == '__main__':
    main()
