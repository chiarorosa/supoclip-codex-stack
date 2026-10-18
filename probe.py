"""End-to-end probe, run INSIDE the supoclip-backend container with its own venv:

    dc.sh exec -T backend .venv/bin/python - < probe.py

Imports the REAL src.ai with the REAL container configuration (LLM / OLLAMA_BASE_URL
come from stack.env) and runs the real windowed analysis + rerank on a synthetic
28-minute transcript.  Only the transcript text is made up.
Prints counts, timings and HTTP status codes; never headers, bodies or keys.
"""
import asyncio
import collections
import logging
import random
import time

import httpx

from src import ai
from src.config import get_config

cfg = get_config()
print(f"LLM={cfg.llm}  base_url={cfg.resolve_ollama_base_url()}  api_key_set={bool(cfg.ollama_api_key)}")

random.seed(7)
TOPICS = ["hiring", "pricing", "fundraising", "customer calls", "product launches", "burnout", "remote teams", "sales"]
OPENERS = [
    "The biggest mistake I see founders make with {t} is waiting too long to ask for help.",
    "Honestly, nobody warned me that {t} would be the hardest part of the first two years.",
    "Here is a number that surprised me: eighty percent of our growth came from {t}, not ads.",
    "People always ask about {t}, and the honest answer is that it depends on your stage.",
    "We almost shut the company down because of {t}, and I want to explain what changed.",
    "If you remember one thing about {t}, make it this: measure it every single week.",
]
FILLERS = [
    "And so we sat down with the whole team and went through every assumption we had made that quarter.",
    "I think the lesson there is that you cannot outsource judgment, even when you trust the person completely.",
    "It sounds obvious in hindsight, but at the time every spreadsheet told us the opposite story.",
    "We tried three different approaches, and only the boring one actually survived contact with real customers.",
    "My co-founder pushed back hard, and honestly she was right, which is something I rarely admit on a podcast.",
    "The thing nobody tells you is how much of this job is just answering the same question calmly again and again.",
]


def make_transcript(minutes: int) -> str:
    lines, t = [], 0
    while t < minutes * 60:
        end = t + random.choice([8, 10, 12])
        topic = random.choice(TOPICS)
        text = random.choice(OPENERS if (t // 10) % 7 == 0 else FILLERS).format(t=topic)
        text += " " + random.choice(FILLERS)
        lines.append(f"[{t // 60:02d}:{t % 60:02d} - {end // 60:02d}:{end % 60:02d}] {text}")
        t = end
    return "\n".join(lines)


calls = []
_orig_send = httpx.AsyncClient.send


async def _send(self, request, **kw):
    t0 = time.perf_counter()
    status = -1
    try:
        resp = await _orig_send(self, request, **kw)
        status = resp.status_code
        return resp
    finally:
        calls.append((status, time.perf_counter() - t0))


httpx.AsyncClient.send = _send

warns = []


class _Cap(logging.Handler):
    def emit(self, record):
        if record.levelno >= logging.WARNING:
            warns.append(record.getMessage()[:150])


logging.getLogger("src.ai").addHandler(_Cap())


async def main():
    transcript = make_transcript(28)
    windows = ai.split_transcript_into_windows(transcript)
    print(f"transcript: 28 min, {len(transcript)} chars, {len(windows)} window(s)")
    t0 = time.perf_counter()
    try:
        result = await ai.get_most_relevant_parts_by_transcript(transcript)
        ok, err = True, ""
    except Exception as exc:  # noqa: BLE001
        result, ok, err = None, False, f"{type(exc).__name__}: {str(exc)[:240]}"
    dt = time.perf_counter() - t0
    hist = collections.Counter(s for s, _ in calls)
    print(f"\n{'PASS' if ok else 'FAIL'}  real pipeline in the backend container ({dt:.1f}s)" + (f" -- {err}" if err else ""))
    print(f"HTTP calls: {len(calls)}  status: {dict(hist)}  slowest: {max((d for _, d in calls), default=0):.1f}s")
    if result is not None:
        segs = result.most_relevant_segments
        print(f"segments: {len(segs)}  topics: {len(result.key_topics)}")
        for s in segs[:3]:
            print(f"  - {s.start_time}-{s.end_time} score={s.virality.total_score} title={s.hook_title!r}")
    if len(windows) > 1:
        print(f"{'FAIL' if any('rerank failed' in w for w in warns) else 'PASS'}  cross-window rerank")
    for w in warns[:5]:
        print("  *", w)


asyncio.run(main())
