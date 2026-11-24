import sys
from pptx import Presentation
from pptx.util import Emu
p = Presentation(sys.argv[1])
for i, s in enumerate(p.slides, 1):
    print('\n=== SLIDE', i)
    for sh in s.shapes:
        pos = '%.2f,%.2f %.2fx%.2f' % (Emu(sh.left).inches, Emu(sh.top).inches, Emu(sh.width).inches, Emu(sh.height).inches)
        if sh.shape_type == 13:
            print('  PIC', pos, sh.image.filename if hasattr(sh,'image') else '', sh._element.blipFill.blip.rEmbed if False else '', s.part.related_part(sh._element.blipFill.find('.//{http://schemas.openxmlformats.org/drawingml/2006/main}blip').get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed')).partname, 'crop', sh.crop_left, sh.crop_right, sh.crop_top, sh.crop_bottom)
        elif sh.has_text_frame and sh.text_frame.text.strip():
            for para in sh.text_frame.paragraphs:
                t=''.join(r.text for r in para.runs)
                if t.strip():
                    f = para.runs[0].font
                    print('  TXT', pos, '[%s %s]' % (f.name, f.size.pt if f.size else None), repr(t))
    if s.has_notes_slide:
        n = s.notes_slide.notes_text_frame.text
        print('  NOTES:', n)
