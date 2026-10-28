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
    def test_missing_wheel_load_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'run.csv'
            with path.open('w', newline='') as out:
                writer = csv.DictWriter(out, fieldnames=COLS)
                writer.writeheader()
                for t in (10, 11, 12):
                    row = dict.fromkeys(COLS, 1)
                    row['Time'] = t
                    if t == 11: row['Fz_L4'] = ''
                    writer.writerow(row)
            result = subprocess.run([sys.executable, str(SCRIPT), '--csv', str(path)],
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn('Fz_L4', result.stderr)

if __name__ == '__main__':
    unittest.main()
