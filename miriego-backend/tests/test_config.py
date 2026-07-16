import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.config import Settings


class ConfigTests(unittest.TestCase):
    def test_settings_loads_env_from_backend_root(self):
        repo_root = Path(__file__).resolve().parents[1]
        env_path = repo_root / ".env"
        self.assertTrue(env_path.exists(), "Expected .env to exist in backend root")

        with tempfile.TemporaryDirectory() as tmpdir:
            os.chdir(tmpdir)
            settings = Settings()  # should still read .env from backend root
            self.assertTrue(settings.DATABASE_URL.startswith("postgresql"))


if __name__ == "__main__":
    unittest.main()
