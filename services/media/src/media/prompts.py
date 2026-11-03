"""Image prompts, read from docs/design/avatar-prompts.md (T-AVT-08 section 1).

Nothing is hard-coded here: the file is the single source, and only values from
the fixed option lists (content/avatar/options.json) fill its placeholders.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path

#: The frame names and their [EXPRESSION] text, from Appendix B.
FRAMES = (
    "neutral",
    "happy",
    "waving",
    "listening",
    "calm",
    "celebrating",
    "blink",
    "mouth_A",
    "mouth_I",
    "mouth_U",
    "mouth_E",
    "mouth_O",
    "mouth_closed",
)


class PromptError(ValueError):
    """The prompts file or an option choice is not usable."""


@dataclass(frozen=True)
class PromptBook:
    """The prompts from avatar-prompts.md."""

    master: str
    avoid: str
    selfie: str
    build: str
    adjust: str
    frame_base: str
    frame_mouth: str
    frame_expressions: dict[str, str]

    @staticmethod
    def parse(markdown: str) -> PromptBook:
        def quote_after(title: str) -> str:
            m = re.search(
                rf"\*\*{re.escape(title)}\*\*[^\n]*\n+((?:>.*\n?)+)",
                markdown,
            )
            if m is None:
                raise PromptError(f"No prompt under '{title}'")
            return " ".join(line.lstrip("> ").strip() for line in m.group(1).splitlines())

        def quote_after_line(start: str) -> str:
            m = re.search(rf"^{re.escape(start)}[^\n]*\n+((?:>.*\n?)+)", markdown, re.M)
            if m is None:
                raise PromptError(f"No prompt after '{start}'")
            return " ".join(line.lstrip("> ").strip() for line in m.group(1).splitlines())

        rows = dict(re.findall(r"^\| ([a-zA-Z_]+) \| (.+?) \|$", markdown, re.M))
        expressions = {f: rows[f] for f in FRAMES if f in rows}
        missing = [f for f in FRAMES if f not in expressions]
        if missing:
            raise PromptError(f"Frame prompts missing: {missing}")
        return PromptBook(
            master=quote_after("Master style"),
            avoid=quote_after("Avoid list"),
            selfie=quote_after("From a selfie"),
            build=quote_after("Build my own (from options)"),
            adjust=quote_after("Adjust (from options)"),
            frame_base=quote_after_line("Base:"),
            frame_mouth=quote_after_line("Mouth frames add:"),
            frame_expressions=expressions,
        )

    @staticmethod
    def load(path: Path) -> PromptBook:
        return PromptBook.parse(path.read_text(encoding="utf-8"))

    def frame_prompt(self, frame: str) -> str:
        """The edit prompt that turns the approved portrait into [frame]."""
        if frame not in self.frame_expressions:
            raise PromptError(f"Unknown frame: {frame}")
        text = self.frame_base.replace("[EXPRESSION]", self.frame_expressions[frame])
        if frame.startswith("mouth_"):
            text = f"{text} {self.frame_mouth}"
        return text


@dataclass(frozen=True)
class Option:
    id: str
    label: str
    prompt: str


@dataclass(frozen=True)
class Category:
    id: str
    placeholder: str
    options: tuple[Option, ...]

    def get(self, option_id: str) -> Option:
        for o in self.options:
            if o.id == option_id:
                return o
        raise PromptError(f"'{option_id}' is not a {self.id} option")


@dataclass(frozen=True)
class OptionBook:
    """content/avatar/options.json: the only words a user's choice can add."""

    categories: dict[str, Category]

    @staticmethod
    def load(path: Path) -> OptionBook:
        data = json.loads(path.read_text(encoding="utf-8"))
        return OptionBook(
            {
                c["id"]: Category(
                    id=c["id"],
                    placeholder=c["placeholder"],
                    options=tuple(Option(o["id"], o["label"], o["prompt"]) for o in c["options"]),
                )
                for c in data["categories"]
            }
        )

    def check(self, choices: dict[str, str]) -> dict[str, Option]:
        """The chosen options; any unknown category or value is refused."""
        out: dict[str, Option] = {}
        for key, value in choices.items():
            category = self.categories.get(key)
            if category is None:
                raise PromptError(f"Unknown option category: {key}")
            out[key] = category.get(value)
        return out

    def fill(self, template: str, choices: dict[str, str], master: str) -> str:
        """[template] with [MASTER STYLE] and each placeholder filled from
        [choices]; accessories (cap, head covering, glasses, accessories) are
        joined. Placeholders with no choice get a neutral default."""
        chosen = self.check(choices)
        by_placeholder: dict[str, list[str]] = {}
        for key, option in chosen.items():
            if option.prompt:
                ph = self.categories[key].placeholder
                by_placeholder.setdefault(ph, []).append(option.prompt)
        text = template.replace("[MASTER STYLE]", master.rstrip("."))
        # Adjust: every change chosen, in one list.
        changes = [o.prompt for o in chosen.values() if o.prompt]
        if "[CHANGES]" in text:
            if not changes:
                raise PromptError("Nothing to change")
            text = text.replace("[CHANGES]", "; ".join(changes))
        defaults = {
            "OUTFIT": "a soft green knit crew-neck sweater",
            "OUTFIT COLOUR": "soft green",
            "ACCESSORIES": "none",
            "FACIAL HAIR": "none",
            "BODY TYPE": "average build",
        }
        for ph in re.findall(r"\[([A-Z ]+)\]", text):
            values = by_placeholder.get(ph)
            if values:
                text = text.replace(f"[{ph}]", ", ".join(values))
            elif ph in defaults:
                text = text.replace(f"[{ph}]", defaults[ph])
            else:
                raise PromptError(f"Missing a choice for [{ph}]")
        return text
