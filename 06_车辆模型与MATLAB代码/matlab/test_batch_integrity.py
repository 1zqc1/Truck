import unittest
from pathlib import Path
import tempfile
from batch_integrity import replace_once, validate_solver_output, file_signature

class BatchIntegrityTests(unittest.TestCase):
    def test_replacement_requires_exactly_one_match(self):
        self.assertEqual(replace_once('a token b', 'token', 'new'), 'a new b')
        for text in ('a b', 'token token'):
            with self.assertRaises(ValueError):
                replace_once(text, 'token', 'new')

    def test_failed_or_stale_solver_output_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            p = Path(folder) / 'out.vsb'
            p.write_bytes(b'old')
            before = file_signature(p)
            with self.assertRaises(RuntimeError):
                validate_solver_output(1, p, before)
            with self.assertRaises(RuntimeError):
                validate_solver_output(0, p, before)
            p.write_bytes(b'new output')
            validate_solver_output(0, p, before)

if __name__ == '__main__':
    unittest.main()
