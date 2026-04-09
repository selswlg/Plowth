import asyncio
import unittest
from datetime import datetime, timedelta, timezone
from uuid import uuid4

from app.services.ai_orchestrator import CostController, ModelRouter, PromptManager
from app.services.job_runner import JobRunner
from app.services.review_scheduler import calculate_schedule


class OrchestratorTests(unittest.TestCase):
    def test_model_router_uses_high_model_for_large_generation_tasks(self):
        router = ModelRouter(high_model="high-model", low_model="low-model")

        self.assertEqual(
            router.select_model(task_type="card_generation", content_length=1200),
            "high-model",
        )
        self.assertEqual(
            router.select_model(task_type="summary", content_length=1200),
            "low-model",
        )

    def test_cost_controller_estimates_tokens_from_prompt_bundle(self):
        prompt = PromptManager().build_card_generation_prompt(
            title="Biology Notes",
            raw_text="Cells divide through mitosis and meiosis.",
        )
        usage = CostController().estimate_generation_cost(
            model_used="heuristic-phase2-v1",
            prompt=prompt,
            output_text="Card: What is mitosis?",
        )

        self.assertEqual(usage["model_used"], "heuristic-phase2-v1")
        self.assertGreater(usage["input_tokens"], 0)
        self.assertGreater(usage["output_tokens"], 0)
        self.assertEqual(usage["cost_usd"], 0.0)


class ReviewSchedulerTests(unittest.TestCase):
    def test_again_creates_relearning_state_and_lapse(self):
        now = datetime.now(timezone.utc)
        update = calculate_schedule(
            reps=3,
            lapses=1,
            state="review",
            stability=5.0,
            difficulty=5.0,
            last_review_at=now - timedelta(days=2),
            rating="again",
            response_time_ms=9000,
            seed_difficulty=3,
            now=now,
        )

        self.assertEqual(update.state, "relearning")
        self.assertEqual(update.lapses, 2)
        self.assertLess(update.next_review_at, now + timedelta(hours=1))

    def test_easy_pushes_review_further_than_good(self):
        now = datetime.now(timezone.utc)
        good = calculate_schedule(
            reps=4,
            lapses=0,
            state="review",
            stability=8.0,
            difficulty=4.0,
            last_review_at=now - timedelta(days=4),
            rating="good",
            response_time_ms=2500,
            seed_difficulty=3,
            now=now,
        )
        easy = calculate_schedule(
            reps=4,
            lapses=0,
            state="review",
            stability=8.0,
            difficulty=4.0,
            last_review_at=now - timedelta(days=4),
            rating="easy",
            response_time_ms=2500,
            seed_difficulty=3,
            now=now,
        )

        self.assertGreater(easy.next_review_at, good.next_review_at)
        self.assertGreaterEqual(easy.stability, good.stability)


class JobRunnerTests(unittest.IsolatedAsyncioTestCase):
    async def test_schedule_dedupes_active_job(self):
        started = asyncio.Event()
        release = asyncio.Event()
        calls: list[str] = []

        async def handler(job_id):
            calls.append(str(job_id))
            started.set()
            await release.wait()

        runner = JobRunner(card_generation_handler=handler)
        job_id = uuid4()

        first = await runner.schedule(job_id)
        second = await runner.schedule(job_id)

        self.assertTrue(first)
        self.assertFalse(second)

        await asyncio.wait_for(started.wait(), timeout=1)
        release.set()
        await runner.shutdown()

        self.assertEqual(calls, [str(job_id)])


if __name__ == "__main__":
    unittest.main()
