import csv
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name('analyze_trucksim_f30_v70.py')
COLS = ['Time', 'Vx_2', 'Ay_2', 'Roll_2', 'AVz_2', 'AVx_2', 'Art_H', 'Fz_H', 'Steer_SW',
        'Fz_L4', 'Fz_L5', 'Fz_L6', 'Fz_R4', 'Fz_R5', 'Fz_R6']

class InputValidationTests(unittest.TestCase):
    def run_case(self, times, missing=False):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'run.csv'
            with path.open('w', newline='') as out:
                writer = csv.DictWriter(out, fieldnames=COLS)
                writer.writeheader()
                for i, t in enumerate(times):
                    row = dict.fromkeys(COLS, 1)
                    row['Time'] = t
                    if missing and i == 1: row['Fz_L4'] = ''
                    writer.writerow(row)
            return subprocess.run([sys.executable, str(SCRIPT), '--csv', str(path)],
                                  capture_output=True, text=True)

    def test_missing_wheel_load_is_rejected(self):
        result = self.run_case([10, 11, 12], missing=True)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn('Fz_L4', result.stderr)

    def test_nonmonotonic_time_is_rejected(self):
        result = self.run_case([10, 11, 11])
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn('strictly increasing', result.stderr)

    def test_complete_data_is_accepted(self):
        result = self.run_case([10, 11, 12])
        self.assertEqual(result.returncode, 0, result.stderr)

if __name__ == '__main__':
    unittest.main()
