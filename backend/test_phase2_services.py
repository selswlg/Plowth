import asyncio
import unittest
from datetime import datetime, timedelta, timezone
from uuid import uuid4

from app.services.ai_orchestrator import CostController, ModelRouter, PromptManager
from app.services.card_generation import infer_domain_hint, infer_source_title
from app.services.csv_import import (
    CsvImportError,
    build_csv_card_drafts,
    build_csv_preview,
)
from app.services.cognitive_update import (
    append_enrichment_history,
    concept_similarity,
    merge_card_answer,
    suggested_update_action,
)
from app.services.daily_review_queue import _priority_for_card
from app.services.insight_service import build_coaching_tip, calculate_streaks
from app.services.job_runner import JobRunner
from app.services.link_ingest import (
    LinkIngestError,
    extract_text_from_html,
    validate_link_url,
)
from app.services.pdf_ingest import PdfIngestError, extract_text_from_pdf
from app.services.review_scheduler import calculate_schedule
from app.services.tutor_service import TutorContext, build_tutor_payload
from app.schemas import DailyInsight, WeakConcept


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

    def test_infer_source_title_uses_first_meaningful_sentence(self):
        title = infer_source_title(
            "Cellular respiration: cells convert glucose into ATP through staged reactions. "
            "The process includes glycolysis and oxidative phosphorylation."
        )

        self.assertEqual(title, "Cellular respiration")

    def test_infer_domain_hint_detects_code_material(self):
        domain = infer_domain_hint(
            "def calculate_schedule(rating): return next_review_at"
        )

        self.assertEqual(domain, "code")


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

    def test_daily_queue_priority_boosts_weak_concepts(self):
        now = datetime.now(timezone.utc)
        baseline = _priority_for_card(
            memory_state=None,
            relation_count=0,
            weakness_count=0,
            now=now,
        )
        boosted = _priority_for_card(
            memory_state=None,
            relation_count=0,
            weakness_count=3,
            now=now,
        )

        self.assertGreater(boosted, baseline)


class CsvImportTests(unittest.TestCase):
    def test_build_csv_preview_returns_columns_and_sample_rows(self):
        preview = build_csv_preview(
            "Question,Answer,Tag\nATP,Cell energy molecule,Biology\n".encode()
        )

        self.assertEqual(preview["columns"], ["Question", "Answer", "Tag"])
        self.assertEqual(preview["row_count"], 1)
        self.assertEqual(preview["sample_rows"][0]["Question"], "ATP")

    def test_build_csv_card_drafts_maps_columns_and_tags(self):
        table, drafts, skipped = build_csv_card_drafts(
            (
                "Term,Definition,Deck\n"
                "Osmosis,Water movement across a membrane,Biology\n"
                ",Missing question,Biology\n"
            ).encode(),
            question_column=0,
            answer_column=1,
            tag_columns=[2],
        )

        self.assertEqual(table.columns, ["Term", "Definition", "Deck"])
        self.assertEqual(len(drafts), 1)
        self.assertEqual(drafts[0].question, "Osmosis")
        self.assertEqual(drafts[0].tags, ["Biology"])
        self.assertEqual(skipped, 1)

    def test_build_csv_card_drafts_rejects_same_question_and_answer_column(self):
        with self.assertRaises(CsvImportError):
            build_csv_card_drafts(
                "Question,Answer\nA,B\n".encode(),
                question_column=0,
                answer_column=0,
            )


class LinkIngestTests(unittest.TestCase):
    def test_validate_link_url_rejects_private_network_urls(self):
        with self.assertRaises(LinkIngestError):
            validate_link_url("http://127.0.0.1/internal")

    def test_extract_text_from_html_uses_title_and_ignores_scripts(self):
        extraction = extract_text_from_html(
            """
            <html>
              <head><title>Biology Notes</title><script>ignore me</script></head>
              <body>
                <nav>Skip navigation</nav>
                <article>
                  <h1>Cellular respiration</h1>
                  <p>Cells convert glucose into ATP through staged reactions.</p>
                  <p>The process includes glycolysis and oxidative phosphorylation.</p>
                </article>
              </body>
            </html>
            """,
            url="https://example.com/biology",
        )

        self.assertEqual(extraction.title, "Biology Notes")
        self.assertIn("Cellular respiration", extraction.text)
        self.assertNotIn("ignore me", extraction.text)
        self.assertNotIn("Skip navigation", extraction.text)


class CognitiveUpdateTests(unittest.TestCase):
    def test_concept_similarity_detects_related_concepts(self):
        score = concept_similarity(
            incoming_name="Cellular respiration",
            incoming_description="Cells convert glucose into ATP.",
            existing_name="Cell respiration",
            existing_description="ATP production from glucose in cells.",
        )

        self.assertGreaterEqual(score, 0.25)
        self.assertEqual(suggested_update_action(score), "keep_separate")

    def test_merge_card_answer_appends_new_evidence_once(self):
        merged = merge_card_answer(
            "Cells convert glucose into ATP.",
            "Oxygen helps maximize ATP output.",
        )
        repeated = merge_card_answer(merged, "Oxygen helps maximize ATP output.")

        self.assertIn("Update: Oxygen helps maximize ATP output.", merged)
        self.assertEqual(repeated, merged)

    def test_append_enrichment_history_keeps_latest_events(self):
        tags = {"enrichment_history": [{"index": index} for index in range(10)]}
        updated = append_enrichment_history(tags, event={"index": 10})

        self.assertEqual(len(updated["enrichment_history"]), 10)
        self.assertEqual(updated["enrichment_history"][0]["index"], 1)
        self.assertEqual(updated["enrichment_history"][-1]["index"], 10)


class PdfIngestTests(unittest.TestCase):
    def test_extract_text_from_pdf_reads_selectable_text(self):
        import fitz

        document = fitz.open()
        page = document.new_page()
        page.insert_text(
            (72, 72),
            "Cell biology notes explain how cells convert nutrients into usable energy.",
        )
        content = document.write()
        document.close()

        extraction = extract_text_from_pdf(content, filename="biology_notes.pdf")

        self.assertEqual(extraction.title, "biology_notes")
        self.assertEqual(extraction.metadata["page_count"], 1)
        self.assertIn("usable energy", extraction.text)

    def test_extract_text_from_pdf_rejects_invalid_pdf(self):
        with self.assertRaises(PdfIngestError):
            extract_text_from_pdf(b"not a pdf", filename="broken.pdf")


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


class InsightServiceTests(unittest.TestCase):
    def test_calculate_streaks_tracks_current_and_longest_runs(self):
        current, longest = calculate_streaks(
            [
                "2026-04-05",
                "2026-04-06",
                "2026-04-08",
                "2026-04-09",
            ],
            reference_date=datetime(2026, 4, 9, tzinfo=timezone.utc).date(),
        )

        self.assertEqual(current, 2)
        self.assertEqual(longest, 2)

    def test_build_coaching_tip_prioritizes_weak_concept_focus(self):
        overview = DailyInsight(
            total_due_today=12,
            completed_today=3,
            accuracy_today=0.42,
            streak_days=4,
            memory_strength=0.56,
        )
        weak_concepts = [
            WeakConcept(
                concept_name="Cellular Respiration",
                failure_count=4,
                last_failed_at=datetime.now(timezone.utc),
            )
        ]

        tip = build_coaching_tip(overview=overview, weak_concepts=weak_concepts)

        self.assertEqual(tip.title, "Target one concept")
        self.assertEqual(tip.focus_topic, "Cellular Respiration")
        self.assertIn("Cellular Respiration", tip.message)


class TutorServiceTests(unittest.TestCase):
    def setUp(self):
        self.context = TutorContext(
            card_id=uuid4(),
            question="What is cellular respiration?",
            answer="Cells convert glucose into ATP through a staged energy pathway.",
            card_type="definition",
            difficulty=3,
            source_title="Biology Unit 2",
            concept_name="Cellular respiration",
            concept_description="A process that releases stored chemical energy for the cell.",
            related_concepts=["ATP", "Mitochondria", "Metabolism"],
            sibling_questions=["How does ATP store energy?", "Where does glycolysis happen?"],
        )

    def test_build_explain_payload_includes_source_and_concept(self):
        payload = build_tutor_payload(context=self.context, request_type="explain")

        self.assertIn("Cellular respiration", payload["title"])
        self.assertIn("ATP", " ".join(payload["related_concepts"]))
        self.assertIn("Source: Biology Unit 2", payload["bullets"])

    def test_build_related_payload_prefers_related_concepts(self):
        payload = build_tutor_payload(context=self.context, request_type="related")

        self.assertIn("ATP", payload["content"])
        self.assertEqual(payload["related_concepts"][0], "ATP")
        self.assertTrue(str(payload["bullets"][0]).startswith("Review next:"))

    def test_build_related_payload_falls_back_to_sibling_questions(self):
        context = TutorContext(
            card_id=uuid4(),
            question="What is osmosis?",
            answer="Osmosis is passive water movement across a selective membrane.",
            card_type="definition",
            difficulty=2,
            source_title="Cell Transport",
            concept_name="Osmosis",
            concept_description=None,
            related_concepts=[],
            sibling_questions=["How is diffusion different?", "What is active transport?"],
        )

        payload = build_tutor_payload(context=context, request_type="related")

        self.assertEqual(payload["related_concepts"], [])
        self.assertIn("neighboring cards", payload["content"])
        self.assertEqual(payload["bullets"][0], "How is diffusion different?")


if __name__ == "__main__":
    unittest.main()
