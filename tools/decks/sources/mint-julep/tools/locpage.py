"""Print the OCR text of a loc.gov newspaper page resource URL: locpage.py URL [grep-word] [context-chars]"""
import json, re, subprocess, sys
url = sys.argv[1]
sep = '&' if '?' in url else '?'
d = json.loads(subprocess.run(['curl', '-sL', '-m', '60', url + sep + 'fo=json'], capture_output=True, text=True).stdout)
ft = d['resource']['fulltext_file']
x = subprocess.run(['curl', '-sL', '-m', '60', ft], capture_output=True, text=True).stdout
words = re.findall(r'CONTENT="([^"]*)"', x)
txt = ' '.join(words) if words else x
if len(sys.argv) > 2:
    w = sys.argv[2]; c = int(sys.argv[3]) if len(sys.argv) > 3 else 1500
    for m in re.finditer(w, txt, flags=re.I):
        print('...', txt[max(0, m.start() - c // 3):m.start() + c], '...\n')
else:
    print(txt)
