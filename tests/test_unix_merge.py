import importlib.util, tempfile, unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SPEC=importlib.util.spec_from_file_location('merge',ROOT/'scripts/merge-skills.py')
M=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(M)
class MergeTests(unittest.TestCase):
    def test_repeat_upgrade_custom_and_backup(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);src=root/'source/skill';dst=root/'target/skill';src.mkdir(parents=True)
            (src/'SKILL.md').write_text('version one')
            for _ in range(3):M.merge(src,dst,root,'test-agent')
            self.assertEqual(len(list(dst.rglob('SKILL.md'))),1)
            (src/'SKILL.md').write_text('version two');M.merge(src,dst,root,'test-agent')
            self.assertEqual((dst/'SKILL.md').read_text(),'version two')
            (dst/'SKILL.md').write_text('buyer edit');M.merge(src,dst,root,'test-agent')
            self.assertEqual((dst/'SKILL.md').read_text(),'buyer edit')
            self.assertTrue(any('buyer edit'==f.read_text() for f in (root/'_backup').rglob('SKILL.md')))
if __name__=='__main__':unittest.main()
