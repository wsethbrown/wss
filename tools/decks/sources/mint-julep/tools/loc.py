"""Search Chronicling America via loc.gov JSON API: loc.py "query" start_date end_date [n]"""
import json, subprocess, sys, urllib.parse
q, d1, d2 = sys.argv[1], sys.argv[2], sys.argv[3]
n = sys.argv[4] if len(sys.argv) > 4 else '15'
url = ('https://www.loc.gov/collections/chronicling-america/?' + urllib.parse.urlencode(
    {'q': q, 'start_date': d1, 'end_date': d2, 'fo': 'json', 'c': n, 'dl': 'page', 'ops': 'AND', 'qs': q, 'searchType': 'advanced'}))
out = subprocess.run(['curl', '-sL', '-m', '60', url], capture_output=True, text=True).stdout
d = json.loads(out)
for r in d.get('results', []):
    print(r.get('date'), '|', (r.get('partof_title') or [''])[0] if isinstance(r.get('partof_title'), list) else r.get('partof_title'), '|', r.get('id'))
