"""Проверяет структуру сайта, чтобы загрузка релизов не удаляла его разделы."""
import importlib.util
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/project'))
spec = importlib.util.spec_from_file_location('site_check', ROOT / 'scripts/project/site_check.py')
site_check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(site_check)


class SiteStructureTest(unittest.TestCase):
    def test_rejects_release_feed_sharing_section_id(self):
        html = '<section id="news"><h2>Что нового</h2><div id="news"></div></section>'
        self.assertEqual(site_check.check_structure(html), ['site/index.html: повторяется id="news"'])

    def test_accepts_separate_section_and_feed(self):
        html = '<a href="#news">Обновления</a><section id="news"><div id="releaseFeed"></div></section>'
        self.assertEqual(site_check.check_structure(html), [])

    def test_rejects_link_to_missing_section(self):
        self.assertEqual(site_check.check_structure('<a href="#themes">Темы</a>'), ['site/index.html: якорь #themes не найден'])


if __name__ == '__main__':
    unittest.main()
