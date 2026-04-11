import asyncio
import os
import tempfile
import unittest
from uuid import uuid4

from pydantic import ValidationError

from app.config import Settings
from app.services.job_runner import ExternalJobRunner, JobRunner, build_job_runner


class SettingsHardeningTests(unittest.TestCase):
    def test_parses_comma_separated_cors_origins(self):
        settings = Settings(
            CORS_ALLOW_ORIGINS="http://localhost:3000, https://app.plowth.com",
        )

        self.assertEqual(
            settings.CORS_ALLOW_ORIGINS,
            ["http://localhost:3000", "https://app.plowth.com"],
        )

    def test_parses_comma_separated_cors_origins_from_dotenv(self):
        with tempfile.NamedTemporaryFile("w+", suffix=".env", delete=False) as env_file:
            env_file.write(
                "CORS_ALLOW_ORIGINS=http://localhost:3000,http://127.0.0.1:3000\n"
            )
            env_file.flush()
            env_file_path = env_file.name

        self.addCleanup(lambda: os.remove(env_file_path))
        settings = Settings(_env_file=env_file_path)

        self.assertEqual(
            settings.CORS_ALLOW_ORIGINS,
            ["http://localhost:3000", "http://127.0.0.1:3000"],
        )

    def test_rejects_wildcard_cors_in_production(self):
        with self.assertRaises(ValidationError):
            Settings(
                APP_ENV="production",
                APP_DEBUG=False,
                JWT_SECRET_KEY="super-secure-production-secret",
                CORS_ALLOW_ORIGINS="*",
            )

    def test_rejects_placeholder_secret_in_production(self):
        with self.assertRaises(ValidationError):
            Settings(
                APP_ENV="production",
                APP_DEBUG=False,
                JWT_SECRET_KEY="change-me-in-production",
                CORS_ALLOW_ORIGINS="https://app.plowth.com",
            )


class JobRunnerModeTests(unittest.TestCase):
    def test_build_job_runner_returns_in_process_runner_by_default(self):
        async def handler(job_id):
            _ = job_id

        runner = build_job_runner(mode="in_process", card_generation_handler=handler)

        self.assertIsInstance(runner, JobRunner)

    def test_external_runner_is_a_noop_scheduler(self):
        async def handler(job_id):
            _ = job_id

        runner = build_job_runner(mode="external", card_generation_handler=handler)

        self.assertIsInstance(runner, ExternalJobRunner)
        self.assertFalse(asyncio.run(runner.schedule(uuid4())))
        self.assertEqual(asyncio.run(runner.schedule_recoverable_jobs()), 0)
        self.assertIsNone(asyncio.run(runner.shutdown()))


if __name__ == "__main__":
    unittest.main()
