"""Make an already-built pptx open in Keynote, writing a repaired copy.

    python3 -I tools/decks/repair_pptx.py <in.pptx> <out.pptx>
    python3 -I tools/decks/repair_pptx.py --check <in.pptx>

Decks built before the fix in wsskit.link_notes_master have a notes master part that
presentation.xml never lists (python-pptx leaves <p:notesMasterIdLst> out). Keynote refuses
such a file: "The file format is invalid". This adds the one missing element and copies every
other part of the package byte for byte, so slides, pictures and notes are untouched.

It never writes over its input or over any existing file, and a failure leaves no output. New decks do not need it: build.py's output is already right,
and build.py fails if it is not. Needs only the Python standard library.
"""
import os
import sys
import tempfile
import zipfile
from pathlib import Path
from xml.etree import ElementTree

PRES = 'ppt/presentation.xml'
RELS = 'ppt/_rels/presentation.xml.rels'
NS_P = 'http://schemas.openxmlformats.org/presentationml/2006/main'
NS_R = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
NS_REL = 'http://schemas.openxmlformats.org/package/2006/relationships'
NOTES_MASTER = NS_R + '/notesMaster'
ANCHOR = '</p:sldMasterIdLst>'
# What reading a file that is not a sound pptx can raise: a missing file or part, not a zip,
# broken XML, an encrypted entry (RuntimeError), or a fault this repair refuses (ValueError).
UNREADABLE = (OSError, KeyError, ValueError, RuntimeError, zipfile.BadZipFile, ElementTree.ParseError)


def notes_master_rid(rels_xml):
    """The id of presentation.xml's relationship to the notes master, or None."""
    for rel in ElementTree.fromstring(rels_xml).iter('{%s}Relationship' % NS_REL):
        if rel.get('Type') == NOTES_MASTER:
            return rel.get('Id')
    return None


def listing(pres_xml):
    """(r:id values inside <p:notesMasterIdLst>, whether it sits where it must).
    (None, True) when the element is absent. Its place is straight after
    <p:sldMasterIdLst>, ahead of the slide list."""
    root = ElementTree.fromstring(pres_xml)
    tags = [child.tag for child in root]
    tag = '{%s}notesMasterIdLst' % NS_P
    if tag not in tags:
        return None, True
    at = tags.index(tag)
    masters = '{%s}sldMasterIdLst' % NS_P
    placed = tags[at - 1] == masters if masters in tags else at == 0
    rids = [el.get('{%s}id' % NS_R) for el in root[at].iter('{%s}notesMasterId' % NS_P)]
    return rids, placed


def problem_in(rels_xml, pres_xml):
    rid = notes_master_rid(rels_xml)
    listed, placed = listing(pres_xml)
    if rid is None:
        return 'presentation.xml lists a notes master the package does not have' if listed else None
    if listed is None:
        return 'the notes master is not listed in presentation.xml (no p:notesMasterIdLst)'
    if listed != [rid]:
        return 'p:notesMasterIdLst names %s, the notes master relationship is %s' % (listed, rid)
    if not placed:
        return 'p:notesMasterIdLst is in the wrong place in presentation.xml (it goes straight after p:sldMasterIdLst)'
    return None


def notes_master_problem(pptx_path):
    """What is wrong with the notes master listing, as a sentence; None when it is right.
    Raises one of UNREADABLE when the file cannot be read as a pptx at all."""
    with zipfile.ZipFile(str(pptx_path)) as z:
        return problem_in(z.read(RELS), z.read(PRES))


def fixed_presentation_xml(pres_xml, rid):
    """presentation.xml (bytes) with the notes master listed after the slide master list."""
    text = pres_xml.decode('utf-8')
    root = ElementTree.fromstring(pres_xml)
    if root.tag != '{%s}presentation' % NS_P:
        raise ValueError('%s is not a presentation part' % PRES)
    # The element is written with the usual p: and r: prefixes, so they must be bound as usual.
    head = text[:text.index('>', text.index('<p:presentation')) + 1] if '<p:presentation' in text else ''
    if 'xmlns:p="%s"' % NS_P not in head or 'xmlns:r="%s"' % NS_R not in head:
        raise ValueError('%s uses unusual namespace prefixes (not p: and r:); this repair only '
                         'handles the usual ones, nothing written' % PRES)
    if text.count(ANCHOR) != 1:
        raise ValueError('%s has no single %s to put the element after; nothing written' % (PRES, ANCHOR))
    add = '<p:notesMasterIdLst><p:notesMasterId r:id="%s"/></p:notesMasterIdLst>' % rid
    return text.replace(ANCHOR, ANCHOR + add).encode('utf-8')


def repair(src, dst):
    """Write a repaired copy of src to dst. Returns 'repaired', 'already fine' (a plain copy),
    or 'nothing to repair' (no notes master in the deck: no file is written).

    dst must not exist yet. The copy is written under a temporary name beside dst and only
    takes the name dst once it has been checked, so a failure leaves nothing behind."""
    src, dst = Path(src).resolve(), Path(dst).resolve()
    if src == dst:
        raise ValueError('refusing to write over the input; give a different output path')
    if dst.exists():
        raise ValueError('%s already exists; give an output path that does not' % dst)
    with zipfile.ZipFile(str(src)) as zin:
        rels, pres = zin.read(RELS), zin.read(PRES)
        rid = notes_master_rid(rels)
        listed, _ = listing(pres)
        needed = rid is not None and listed is None
        if not needed:
            problem = problem_in(rels, pres)
            if problem:
                raise ValueError(problem + '; this repair cannot fix that')
            if rid is None:
                return 'nothing to repair'
        else:
            pres = fixed_presentation_xml(pres, rid)
        dst.parent.mkdir(parents=True, exist_ok=True)
        handle, tmp = tempfile.mkstemp(dir=str(dst.parent), prefix=dst.name + '.', suffix='.tmp')
        os.close(handle)
        try:
            with zipfile.ZipFile(tmp, 'w') as zout:
                for info in zin.infolist():
                    data = pres if info.filename == PRES else zin.read(info.filename)
                    zout.writestr(info, data, compress_type=info.compress_type)
            left = notes_master_problem(tmp)
            if left:
                raise ValueError('the repaired copy would still be wrong: %s; nothing written' % left)
            if dst.exists():
                raise ValueError('%s appeared while repairing; nothing written' % dst)
            os.replace(tmp, str(dst))
        finally:
            if os.path.exists(tmp):
                os.remove(tmp)
    return 'repaired' if needed else 'already fine'


def explain(error):
    """One line for any of UNREADABLE."""
    if isinstance(error, FileNotFoundError):
        return 'no such file'
    if isinstance(error, zipfile.BadZipFile):
        return 'not a pptx (not a zip file): %s' % error
    if isinstance(error, ElementTree.ParseError):
        return 'not a pptx this tool can read (broken XML: %s)' % error
    if isinstance(error, KeyError):
        return 'not a pptx this tool can read (%s)' % str(error).strip('\'"')
    return ' '.join(str(error).split()) or type(error).__name__


def main(argv):
    if len(argv) == 3 and argv[1] == '--check':
        try:
            problem = notes_master_problem(argv[2])
        except UNREADABLE as e:
            raise SystemExit('repair_pptx.py: %s: %s' % (argv[2], explain(e)))
        print('%s: %s' % (argv[2], problem or 'ok'))
        return 1 if problem else 0
    if len(argv) != 3 or argv[1].startswith('-'):
        raise SystemExit(__doc__)
    try:
        result = repair(argv[1], argv[2])
    except UNREADABLE as e:
        raise SystemExit('repair_pptx.py: %s: %s' % (argv[1], explain(e)))
    if result == 'nothing to repair':
        print('%s: no notes master, nothing to repair; no file written' % argv[1])
    else:
        print('%s: %s, wrote %s' % (argv[1], result, argv[2]))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
