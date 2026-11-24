"""Convert British spellings to American outside quotation marks.

    python3 -I tools/decks/american.py <file>...

Text inside “curly” or "straight" quotation marks on one line is left alone, since a
quotation keeps its source's spelling. In a .py or .json file only curly quotes count, because
straight quotes there belong to the file format. It rewrites the files and prints every changed line:
read them. Do not run it on a deck whose subject is British.
"""
import re, sys
PAIRS = [("centred","centered"),("centring","centering"),("catalogued","cataloged"),("cataloguing","cataloging"),
         ("savoury","savory"),("sulphur","sulfur"),("instalment","installment"),("barrelled","barreled"),
         ("colour","color"),("flavour","flavor"),("favour","favor"),("honour","honor"),("labour","labor"),
         ("neighbour","neighbor"),("harbour","harbor"),("rumour","rumor"),("humour","humor"),("vapour","vapor"),
         ("odour","odor"),("mould","mold"),("smoulder","smolder"),("centre","center"),("litre","liter"),
         ("metre","meter"),("theatre","theater"),("fibre","fiber"),("grey","gray"),("defence","defense"),
         ("offence","offense"),("programme","program"),("catalogue","catalog"),("aluminium","aluminum"),
         ("judgement","judgment"),("ageing","aging"),("whilst","while"),("amongst","among"),
         ("labelled","labeled"),("labelling","labeling"),("travelled","traveled"),("travelling","traveling"),
         ("cancelled","canceled"),("modelled","modeled"),("sceptic","skeptic"),("storey","story"),
         ("cheque","check"),("tonne","ton"),("plough","plow"),("draught","draft"),("kerb","curb"),("tyre","tire"),
         ("licence","license"),("practise","practice"),("fulfil ","fulfill "),("enrol ","enroll "),("maths","math")]
ISE = re.compile(r"\b(\w+?)(is)(e|ed|es|ing|ation|ations)\b")
ISE_WORDS = {"organ","recogn","real","special","standard","author","critic","emphas","popular","modern","character",
             "capital","national","general","summar","apolog","categor","memor","util","minim","maxim","final","civil",
             "legal","industrial","commercial","central","normal","symbol","vapor","pasteur","caramel","oxid","homogen",
             "steril","crystall","digit","monopol","neutral","harmon","econom","prior","local","global","public","subsid","colon","rational"}
def conv(seg):
    for b, a in PAIRS:
        seg = re.sub(b, a, seg); seg = re.sub(b.capitalize(), a.capitalize(), seg); seg = re.sub(b.upper(), a.upper(), seg)
    def ise(m):
        return m.group(1) + "iz" + m.group(3) if m.group(1).lower() in ISE_WORDS else m.group(0)
    return ISE.sub(ise, seg)
QUOTED = re.compile(r'(“[^”\n]*”|"[^"\n]*")')
CURLY = re.compile(r'(“[^”\n]*”)')
n = 0
for path in sys.argv[1:]:
    src = open(path, encoding="utf-8").read(); out = []
    for line in src.split("\n"):
        parts = (CURLY if path.endswith(('.py', '.json')) else QUOTED).split(line)
        new = "".join(p if i % 2 else conv(p) for i, p in enumerate(parts))
        if new != line: n += 1; print(f"{path}: {line.strip()[:90]}\n   -> {new.strip()[:90]}")
        out.append(new)
    open(path, "w", encoding="utf-8").write("\n".join(out))
print(n, "lines changed")
