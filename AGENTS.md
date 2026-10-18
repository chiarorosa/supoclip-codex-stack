# Instructions for AI agents

Goal: install and verify this stack on the user's machine. Follow the steps in order. Every step has a check; do not continue if a check fails, report the output instead.

## Rules

- Work only inside this repository's folder. Never touch Docker containers, images or volumes that this stack did not create (everything here is named `supoclip-*` or `codex-proxy`).
- Never print, log or commit `stack.env` or anything from the `codex_auth` volume.
- Do not work around permission prompts or security denials from your harness. If an action is blocked, tell the user which command to run themselves.
- Do not modify files under `supoclip/` (the upstream clone).

## Human-only steps

1. **Consent.** Before step 4, tell the user that this stack uses their ChatGPT subscription as an API through an unofficial gateway, that it counts toward their plan limits and may conflict with the plan's terms (see "Risks and terms of use" in `README.md`), and get an explicit yes.
2. **ChatGPT login.** `./login.sh` is an interactive device login. Ask the user to run it in their own terminal (in Claude Code: `! ./login.sh`). You cannot complete it for them.

## Steps

1. **Prerequisites.** Check: `docker compose version` succeeds, `docker info` succeeds (daemon running), `git --version`, `python3 --version` (or `python`). On Windows use Git Bash.
2. **Fetch and build.** Run `./setup.sh`. It is idempotent. It clones SupoClip at a pinned commit, writes `stack.env`, builds the images (several minutes: allow a long timeout or run it in the background) and then checks the login.
   - Exit code 2 means the login step is needed: go to the human-only step 2, then re-run `./setup.sh`.
   - Check: it ends with `Done. Open http://localhost:3107 ...`.
3. **Account.** Ask the user to open the printed URL and create a local account (no email verification is needed in self-host mode).
4. **Verify.** Run `./verify.sh`. It makes a few real LLM calls on the user's plan (tell them first).
   - Check: the output ends with `ALL CHECKS PASSED`.
5. **First video.** Suggest a short video (2 to 5 minutes). The first transcription downloads the Whisper `small` model (about 461 MB) and CPU transcription is slow; the progress bar stays at 30% during it. Check `docker stats supoclip-worker` before concluding that it is stuck.

## Everyday commands

- `./dc.sh ps` / `./dc.sh logs -f worker` / `./dc.sh up -d` / `./dc.sh down`
- Remove the stored ChatGPT login: `./dc.sh down && docker volume rm supoclip-stack_codex_auth`

## If something fails

- Containers not healthy: `./dc.sh logs <service>` for `backend`, `worker`, `codex-proxy`.
- `codex login` TLS error: rebuild with `./dc.sh build codex-proxy`.
- HTTP 429 from the gateway: the user's plan limit was reached; wait and retry.
- "Open in editor" failing for a YouTube source is a known upstream limitation (see README), not an installation problem.
