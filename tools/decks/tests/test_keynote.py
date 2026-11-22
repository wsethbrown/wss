"""A built pptx must list its notes master in presentation.xml, or Keynote refuses it.

    python3 -I -m unittest discover -s tools/decks/tests -t tools/decks/tests -v

Keynote ("The file format is invalid") and macOS Quick Look both fail on a pptx whose notes
master part exists but is missing from <p:notesMasterIdLst>; python-pptx leaves it out.
These tests look at the XML only, so they run without Keynote. Needs python-pptx and lxml.
"""
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

KIT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(KIT))

import repair_pptx  # noqa: E402
import wsskit  # noqa: E402

NOTES_MD = """# Script

---

## [SLIDE 1] One

A first slide with enough words in its script to count as notes.

## [SLIDE 2] Two

A second slide with enough words in its script to count as notes.
"""


def presentation_xml(path):
    with zipfile.ZipFile(str(path)) as z:
        return z.read('ppt/presentation.xml').decode('utf-8')


class KeynoteStructure(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)

    def kit_deck(self):
        """Two slides with notes, built and saved the way build.py does it."""
        (self.dir / 'speaker-notes.md').write_text(NOTES_MD)
        wsskit.init(self.dir, 'Test Deck')
        wsskit.title_slide('Test Deck', 'A hook.')
        s = wsskit.new_slide()
        wsskit.heading(s, 1.0, 'Second')
        out = self.dir / 'kit.pptx'
        self.assertEqual(wsskit.finish(self.dir / 'speaker-notes.md', out), 2)
        return out

    def raw_deck(self, notes=True):
        """What python-pptx writes on its own: the fault, when a slide has notes."""
        from pptx import Presentation
        prs = Presentation()
        slide = prs.slides.add_slide(prs.slide_layouts[6])
        if notes:
            slide.notes_slide.notes_text_frame.text = 'Some notes.'
        out = self.dir / ('raw-notes.pptx' if notes else 'raw-plain.pptx')
        prs.save(str(out))
        return out

    def test_built_deck_lists_its_notes_master(self):
        out = self.kit_deck()
        self.assertIsNone(repair_pptx.notes_master_problem(out))
        with zipfile.ZipFile(str(out)) as z:
            rid = repair_pptx.notes_master_rid(z.read(repair_pptx.RELS))
            names = z.namelist()
        self.assertIsNotNone(rid)
        self.assertIn('ppt/notesMasters/notesMaster1.xml', names)
        xml = presentation_xml(out)
        self.assertEqual(xml.count('<p:notesMasterIdLst>'), 1)
        # Straight after the slide master list, before the slide list: the schema's order.
        self.assertIn('</p:sldMasterIdLst><p:notesMasterIdLst><p:notesMasterId r:id="%s"/>'
                      '</p:notesMasterIdLst><p:sldIdLst>' % rid, xml)

    def test_built_deck_keeps_its_notes(self):
        from pptx import Presentation
        slides = list(Presentation(str(self.kit_deck())).slides)
        self.assertTrue(slides[0].notes_slide.notes_text_frame.text.startswith('[SLIDE 1] One'))
        self.assertTrue(slides[1].notes_slide.notes_text_frame.text.startswith('[SLIDE 2] Two'))

    def test_link_notes_master_is_safe_to_repeat_and_skips_decks_without_notes(self):
        from pptx import Presentation
        prs = Presentation()
        slide = prs.slides.add_slide(prs.slide_layouts[6])
        self.assertFalse(wsskit.link_notes_master(prs))  # no notes yet, nothing to list
        slide.notes_slide.notes_text_frame.text = 'Some notes.'
        self.assertTrue(wsskit.link_notes_master(prs))
        self.assertFalse(wsskit.link_notes_master(prs))
        out = self.dir / 'twice.pptx'
        prs.save(str(out))
        self.assertEqual(presentation_xml(out).count('<p:notesMasterIdLst>'), 1)

    def test_check_names_the_fault_in_a_plain_python_pptx_deck(self):
        self.assertIn('not listed', repair_pptx.notes_master_problem(self.raw_deck()))
        self.assertIsNone(repair_pptx.notes_master_problem(self.raw_deck(notes=False)))

    def test_repair_adds_only_the_missing_element(self):
        src, dst = self.raw_deck(), self.dir / 'repaired.pptx'
        before = src.read_bytes()
        self.assertEqual(repair_pptx.repair(src, dst), 'repaired')
        self.assertEqual(src.read_bytes(), before)  # the input is left alone
        self.assertIsNone(repair_pptx.notes_master_problem(dst))
        with zipfile.ZipFile(str(src)) as a, zipfile.ZipFile(str(dst)) as b:
            self.assertEqual(a.namelist(), b.namelist())
            for name in a.namelist():
                if name != repair_pptx.PRES:
                    self.assertEqual(a.read(name), b.read(name), name)
            rid = repair_pptx.notes_master_rid(a.read(repair_pptx.RELS))
            added = '<p:notesMasterIdLst><p:notesMasterId r:id="%s"/></p:notesMasterIdLst>' % rid
            self.assertEqual(b.read(repair_pptx.PRES).decode().replace(added, ''),
                             a.read(repair_pptx.PRES).decode())
        from pptx import Presentation
        self.assertEqual(Presentation(str(dst)).slides[0].notes_slide.notes_text_frame.text, 'Some notes.')

    def test_repair_copies_a_good_deck_and_refuses_to_overwrite(self):
        good = self.kit_deck()
        self.assertEqual(repair_pptx.repair(good, self.dir / 'copy.pptx'), 'already fine')
        self.assertEqual(presentation_xml(self.dir / 'copy.pptx'), presentation_xml(good))
        with self.assertRaises(ValueError):
            repair_pptx.repair(good, good)

    # ---- review round: bad input, existing output, misplaced element, build.py's check

    def rewrite(self, src, name, edits=None, drop=()):
        """A copy of src with presentation-level parts edited ({part: fn(bytes) -> bytes}) or dropped."""
        dst = self.dir / name
        with zipfile.ZipFile(str(src)) as zin, zipfile.ZipFile(str(dst), 'w') as zout:
            for info in zin.infolist():
                if info.filename in drop:
                    continue
                data = zin.read(info.filename)
                if edits and info.filename in edits:
                    data = edits[info.filename](data)
                zout.writestr(info, data)
        return dst

    def misplaced_deck(self):
        """The element present with the right id, but after the slide list."""
        def move(xml):
            text = xml.decode()
            start = text.index('<p:notesMasterIdLst>')
            end = text.index('</p:notesMasterIdLst>') + len('</p:notesMasterIdLst>')
            el, text = text[start:end], text[:start] + text[end:]
            return text.replace('</p:sldIdLst>', '</p:sldIdLst>' + el).encode()
        return self.rewrite(self.kit_deck(), 'misplaced.pptx', {repair_pptx.PRES: move})

    def bad_inputs(self):
        raw = self.raw_deck()
        not_zip = self.dir / 'not-a-zip.pptx'
        not_zip.write_text('this is not a zip file')
        return {
            'not a zip': not_zip,
            'no such file': self.dir / 'absent.pptx',
            'broken xml': self.rewrite(raw, 'broken.pptx', {repair_pptx.PRES: lambda b: b[:200]}),
            'no presentation part': self.rewrite(raw, 'nopres.pptx', drop=(repair_pptx.PRES,)),
            'no rels part': self.rewrite(raw, 'norels.pptx', drop=(repair_pptx.RELS,)),
        }

    def assert_clean_exit(self, argv, label):
        with self.assertRaises(SystemExit, msg=label) as caught:
            repair_pptx.main(argv)
        code = caught.exception.code
        self.assertIsInstance(code, str, label)  # a message, so the exit status is 1
        self.assertTrue(code.startswith('repair_pptx.py: '), code)
        self.assertNotIn('\n', code)
        self.assertNotIn('Traceback', code)

    def test_misplaced_element_is_a_problem_and_is_not_repaired(self):
        bad = self.misplaced_deck()
        self.assertIn('wrong place', repair_pptx.notes_master_problem(bad))
        out = self.dir / 'out.pptx'
        with self.assertRaises(ValueError):
            repair_pptx.repair(bad, out)
        self.assertFalse(out.exists())

    def test_bad_input_gives_one_clean_line_and_no_output(self):
        for label, path in self.bad_inputs().items():
            out = self.dir / ('out-%s.pptx' % label.replace(' ', '-'))
            self.assert_clean_exit(['repair_pptx.py', '--check', str(path)], label)
            self.assert_clean_exit(['repair_pptx.py', str(path), str(out)], label)
            self.assertFalse(out.exists(), label)
        self.assertEqual([f.name for f in self.dir.iterdir() if f.name.endswith('.tmp')], [])

    def test_encrypted_entry_error_is_reported_cleanly(self):
        # zipfile raises RuntimeError for a password-protected entry; stand in for one.
        src, real = self.raw_deck(), repair_pptx.notes_master_rid
        def boom(_):
            raise RuntimeError('File is encrypted, password required for extraction')
        repair_pptx.notes_master_rid = boom
        self.addCleanup(setattr, repair_pptx, 'notes_master_rid', real)
        self.assert_clean_exit(['repair_pptx.py', '--check', str(src)], 'encrypted')
        self.assert_clean_exit(['repair_pptx.py', str(src), str(self.dir / 'o.pptx')], 'encrypted')
        self.assertFalse((self.dir / 'o.pptx').exists())

    def test_repair_refuses_an_output_that_already_exists(self):
        src, dst = self.raw_deck(), self.dir / 'there.pptx'
        dst.write_bytes(b'someone else made this')
        with self.assertRaises(ValueError) as caught:
            repair_pptx.repair(src, dst)
        self.assertIn('already exists', str(caught.exception))
        self.assertEqual(dst.read_bytes(), b'someone else made this')
        self.assert_clean_exit(['repair_pptx.py', str(src), str(dst)], 'exists')

    def test_failed_repair_leaves_nothing_behind(self):
        src, dst, real = self.raw_deck(), self.dir / 'never.pptx', repair_pptx.notes_master_problem
        # Make the final re-check of the written copy fail.
        repair_pptx.notes_master_problem = lambda path: 'pretend the copy is wrong'
        self.addCleanup(setattr, repair_pptx, 'notes_master_problem', real)
        before = sorted(f.name for f in self.dir.iterdir())
        with self.assertRaises(ValueError):
            repair_pptx.repair(src, dst)
        self.assertFalse(dst.exists())
        self.assertEqual(sorted(f.name for f in self.dir.iterdir()), before)

    def test_deck_without_notes_writes_no_file(self):
        src, dst = self.raw_deck(notes=False), self.dir / 'plain-out.pptx'
        self.assertEqual(repair_pptx.repair(src, dst), 'nothing to repair')
        self.assertFalse(dst.exists())
        self.assertEqual(repair_pptx.main(['repair_pptx.py', str(src), str(dst)]), 0)
        self.assertFalse(dst.exists())

    def test_unusual_prefixes_are_refused_by_name(self):
        def rename(xml):
            return xml.decode().replace('xmlns:r=', 'xmlns:rel=').replace('r:id=', 'rel:id=').encode()
        odd = self.rewrite(self.raw_deck(), 'odd.pptx', {repair_pptx.PRES: rename})
        with self.assertRaises(ValueError) as caught:
            repair_pptx.repair(odd, self.dir / 'odd-out.pptx')
        self.assertIn('prefix', str(caught.exception))
        self.assertFalse((self.dir / 'odd-out.pptx').exists())

    def package(self, pptx, slides):
        """The least a package folder needs for build.check to reach the pptx checks."""
        import shutil
        out = self.dir / 'Pkg'
        (out / 'slides').mkdir(parents=True)
        shutil.copy(str(pptx), str(out / 'Pkg.pptx'))
        (out / 'speaker-notes.md').write_text(NOTES_MD)
        for i in range(1, slides + 1):
            (out / 'slides' / ('slide-%02d.png' % i)).write_bytes(b'')
        for name in ['Pkg-speaker-notes.pdf', 'Pkg-research-outline.pdf']:
            (out / name).write_bytes(b'')
        return out

    def test_build_check_passes_a_built_deck(self):
        import build
        build.check(self.package(self.kit_deck(), 2), 'Pkg', 2)

    def test_build_check_reports_a_deck_lacking_the_element(self):
        import build
        from pptx import Presentation
        # A kit deck with the element taken out again: everything else passes the check.
        def strip(xml):
            text = xml.decode()
            start = text.index('<p:notesMasterIdLst>')
            end = text.index('</p:notesMasterIdLst>') + len('</p:notesMasterIdLst>')
            return (text[:start] + text[end:]).encode()
        bad = self.rewrite(self.kit_deck(), 'stripped.pptx', {repair_pptx.PRES: strip})
        self.assertEqual(len(Presentation(str(bad)).slides), 2)
        with self.assertRaises(SystemExit) as caught:
            build.check(self.package(bad, 2), 'Pkg', 2)
        message = str(caught.exception.code)
        self.assertIn('notes master is not listed', message)
        self.assertIn('Keynote', message)
        self.assertEqual(message.count('\n  - '), 1, message)  # the only problem reported

    def test_build_check_reports_an_unreadable_listing_without_crashing(self):
        import build
        real = repair_pptx.notes_master_problem
        def boom(path):
            raise RuntimeError('File is encrypted, password required for extraction')
        repair_pptx.notes_master_problem = boom
        self.addCleanup(setattr, repair_pptx, 'notes_master_problem', real)
        with self.assertRaises(SystemExit) as caught:
            build.check(self.package(self.kit_deck(), 2), 'Pkg', 2)
        self.assertIn('checks failed', str(caught.exception.code))
        self.assertIn('encrypted', str(caught.exception.code))


if __name__ == '__main__':
    unittest.main()
