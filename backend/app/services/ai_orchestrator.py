"""
Phase 2 AI orchestration primitives.

The current implementation uses deterministic heuristics, but the surrounding
interfaces match the structure needed for a real model-backed pipeline.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class PromptBundle:
    system_prompt: str
    user_prompt: str


class ModelRouter:
    """Select a model alias for a given workload."""

    def __init__(self, *, high_model: str, low_model: str) -> None:
        self._high_model = high_model
        self._low_model = low_model

    def select_model(self, *, task_type: str, content_length: int) -> str:
        if task_type == "card_generation" and content_length > 800:
            return self._high_model
        return self._low_model


class PromptManager:
    """Construct reusable prompt bundles for Phase 2 tasks."""

    def build_card_generation_prompt(self, *, title: str | None, raw_text: str) -> PromptBundle:
        title_line = title.strip() if title else "Untitled source"
        return PromptBundle(
            system_prompt=(
                "You are Plowth's card-generation orchestrator. "
                "Extract coherent concepts, preserve factual phrasing, and "
                "prefer concise flashcards over exhaustive notes."
            ),
            user_prompt=(
                f"Source title: {title_line}\n"
                "Task: chunk the material, infer concepts, add lightweight "
                "relations, and draft spaced-repetition flashcards.\n\n"
                f"{raw_text.strip()}"
            ),
        )


class CostController:
    """Estimate usage for deterministic and model-backed pipelines."""

    def estimate_tokens(self, value: str) -> int:
        return max(1, (len(value) + 3) // 4)

    def estimate_generation_cost(
        self,
        *,
        model_used: str,
        prompt: PromptBundle,
        output_text: str,
    ) -> dict[str, int | float | str]:
        input_tokens = self.estimate_tokens(
            f"{prompt.system_prompt}\n{prompt.user_prompt}"
        )
        output_tokens = self.estimate_tokens(output_text)
        return {
            "model_used": model_used,
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
            "cost_usd": 0.0,
        }
