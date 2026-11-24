"""Print the shapes, positions, fonts, colours and notes of a .pptx, slide by slide.

Use it to study a reference deck (the owner's own decks) or to check a built one:
    python3 -I tools/decks/inspect_pptx.py deck.pptx [3,4,7]
The optional list limits the output to those slide numbers. Sizes are inches.
"""
import sys
from pptx import Presentation
from pptx.util import Emu
p=Presentation(sys.argv[1])
only=set(int(x) for x in sys.argv[2].split(',')) if len(sys.argv)>2 else None
E2=914400
def col(f):
    try:
        if f.type==1: return str(f.fore_color.rgb)
    except Exception: pass
    return '-'
print('size',p.slide_width/E2,p.slide_height/E2)
for i,s in enumerate(p.slides,1):
    if only and i not in only: continue
    bg='-'
    try: bg=col(s.background.fill)
    except: pass
    print(f'\n=== SLIDE {i} bg={bg} layout={s.slide_layout.name}')
    for sh in s.shapes:
        g=f'{sh.left/E2:.2f},{sh.top/E2:.2f} {sh.width/E2:.2f}x{sh.height/E2:.2f}'
        fill=line='-'
        try: fill=col(sh.fill)
        except: pass
        try: line=(str(sh.line.color.rgb) if sh.line.fill.type==1 else '-')+'/'+str(sh.line.width.pt if sh.line.width else '')
        except: pass
        t=sh.shape_type
        print(f'- {sh.name[:22]:22} {t} {g} fill={fill} line={line}')
        if sh.has_text_frame:
            tf=sh.text_frame
            print('    anchor',tf._bodyPr.get('anchor'),'ins',[tf.margin_left/E2,tf.margin_top/E2])
            for para in tf.paragraphs:
                runs=[]
                for r in para.runs:
                    f=r.font
                    c='-'
                    try: c=str(f.color.rgb)
                    except: pass
                    runs.append(f'[{f.name} {f.size.pt if f.size else None} b{int(bool(f.bold))} i{int(bool(f.italic))} {c}] {r.text[:90]!r}')
                if runs: print('    p al=%s ls=%s sb=%s'%(para.alignment,para.line_spacing,para.space_before),' | '.join(runs))
        if getattr(sh,'has_table',False) and sh.has_table:
            tb=sh.table
            print('    table',len(tb.rows),'x',len(tb.columns),'colw',[round(c.width/E2,2) for c in tb.columns],'rowh',[round(r.height/E2,2) for r in tb.rows])
            for r in list(tb.rows)[:2]:
                for c in r.cells:
                    fs=[(ru.font.name,ru.font.size.pt if ru.font.size else None,ru.font.bold) for pp in c.text_frame.paragraphs for ru in pp.runs]
                    print('     cell',repr(c.text[:30]),col(c.fill),fs[:1])
    if s.has_notes_slide:
        n=s.notes_slide.notes_text_frame.text
        print('  NOTES len',len(n),repr(n[:300]))
