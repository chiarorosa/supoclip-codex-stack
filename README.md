# SupoClip Codex Stack

**A Dockerized stack to self-host [SupoClip](https://github.com/FujiwaraChoki/supoclip) (AI video clipping) with your own ChatGPT / Codex subscription instead of paid LLM API keys.**

It adds an OpenAI-compatible gateway container next to the official SupoClip `docker compose` setup and points SupoClip's LLM calls at it. Transcription runs locally with Whisper, so the whole pipeline (upload or YouTube link → transcript → viral-moment selection → rendered vertical clips) works with **no OpenAI, Anthropic, Google or AssemblyAI API key**. You still need a ChatGPT plan that includes Codex.

> **Unofficial.** This project is not affiliated with SupoClip, OpenAI or the gateway project it builds on. Read [Risks and terms of use](#risks-and-terms-of-use) before using it.

Keywords: SupoClip self-host, SupoClip Docker, SupoClip without API key, ChatGPT subscription as OpenAI-compatible API, Codex OAuth gateway, local Whisper, AI video clipping, short-form clips, docker compose.

## How it works

```
 browser ──► frontend ──► backend ──► worker ──► ffmpeg clips
                            │            │
                            │            └─ Whisper (local, CPU) → transcript
                            ▼
                    LLM calls (OpenAI-compatible, provider "ollama:")
                            │
                            ▼
                    codex-proxy  ── ChatGPT OAuth (stored only in a Docker volume) ──► ChatGPT / Codex
```

- `codex-proxy` builds [`EvanZhouDev/openai-oauth`](https://github.com/EvanZhouDev/openai-oauth) **pinned to a reviewed commit** and the official Codex CLI, which is used only for the one-time login.
- SupoClip believes it talks to an Ollama-style server (`LLM=ollama:...`, `OLLAMA_BASE_URL=http://codex-proxy:10531/v1`), which is its existing way to use any OpenAI-compatible endpoint. **No SupoClip code is modified**: the upstream repo is cloned at a pinned commit and left untouched.
- The gateway has **no `ports:` entry**, so it is reachable only from other containers on the compose network, never from your LAN.
- The ChatGPT login lives only in the Docker volume `supoclip-stack_codex_auth`, not in your home directory.

## Requirements

- Docker with Compose v2 (Docker Desktop or Docker Engine), `git`, `bash`, `curl`, `python3`
- About 4 CPU cores, 8 GB of free RAM and several GB of disk (images, Whisper model, clips)
- A ChatGPT plan that includes Codex

## Quick start

```bash
git clone https://github.com/chiarorosa/supoclip-codex-stack.git
cd supoclip-codex-stack

./setup.sh      # clones SupoClip, generates secrets, builds images; stops at the login step (exit code 2)
./login.sh      # one-time ChatGPT device login (interactive: open the URL, enter the code)
./setup.sh      # re-run: starts the stack and waits until every container is healthy
./verify.sh     # end-to-end check, including a real LLM pipeline run
```

Then open <http://localhost:3107>, create a local account and upload a video. `setup.sh` is idempotent and safe to re-run.

On Windows, use Git Bash (Docker Desktop with the Linux engine).

### Install it with an AI agent

Point your coding agent (Claude Code, Codex, Cursor, ...) at [`AGENTS.md`](AGENTS.md). It lists the exact steps, how to verify each one, and the two steps that must stay with a human (the ChatGPT login and the decision to use your subscription this way).

## Configuration

`gen_env.py` writes `stack.env` with random local secrets (it refuses to overwrite an existing file). Useful settings:

| Variable | Default | Meaning |
|---|---|---|
| `LLM` | `ollama:gpt-6-luna` | Model name sent to the gateway. Run `./dc.sh exec -T codex-proxy node -e "fetch('http://127.0.0.1:10531/v1/models').then(r=>r.text()).then(console.log)"` to list the models your plan exposes. |
| `TRANSCRIPTION_PROVIDER` | `whisper` | `whisper` (local, no key), `youtube_captions` (YouTube links only) or `assemblyai` (needs a key). |
| `WHISPER_MODEL_SIZE` | `small` | `tiny`/`base` are faster and less accurate; `medium`/`large` are slower on CPU. |
| `FRONTEND_PORT` | `3107` | Host port of the web UI. |

After editing `stack.env`, recreate the services: `./dc.sh up -d`.

`./dc.sh` is a thin wrapper around `docker compose` with the right project name and both compose files, e.g. `./dc.sh ps`, `./dc.sh logs -f worker`, `./dc.sh down`.

## Risks and terms of use

- **Unofficial use of a subscription.** Using a ChatGPT login as an API through a third-party gateway is not an officially supported OpenAI integration and may conflict with the terms of your plan. You use it at your own risk and are responsible for complying with the terms that apply to you.
- **Usage limits.** Every analysis counts toward your plan's usage limits. A video of a few minutes needs a handful of LLM calls; longer videos are analysed in several windows. If you hit limits you will see HTTP 429 errors.
- **Credentials.** The login token is stored in the `codex_auth` volume and refreshed by the gateway. Anyone with access to that volume or to the compose network can use your plan. Do not publish port 10531 and do not run this on a shared server. To remove it: `./dc.sh down && docker volume rm supoclip-stack_codex_auth` (you can also sign out sessions from your ChatGPT account settings).
- **Local only.** The stack is meant for a personal machine. Generated secrets protect the local database and backend, not an internet-facing deployment.
- **SupoClip licence.** SupoClip is AGPL-3.0 and is not redistributed here; `setup.sh` clones it from its own repository. The files in this repo are under the MIT licence.

## Troubleshooting

- **Progress sits at 30% for minutes.** Whisper on CPU gives no progress output while it works. Check `docker stats supoclip-worker`: high CPU means it is working. See upstream [issue #67](https://github.com/FujiwaraChoki/supoclip/issues/67).
- **"Open in editor" fails for YouTube sources.** SupoClip deletes the downloaded video after a task and the editor downloads it again; YouTube can answer with a bot check. Uploads are not affected. See upstream [issue #205](https://github.com/FujiwaraChoki/supoclip/issues/205).
- **Login fails with `error sending request for url (https://auth.openai.com/...)`.** The Codex CLI needs system CA certificates; the `codex-proxy` image installs them, so rebuild it with `./dc.sh build codex-proxy`.
- **`variable is not set` warnings** for Stripe, AWS, etc. are expected: those features are disabled in self-host mode.

## Tested with

Windows 11, Docker Desktop (Linux engine), Git Bash; SupoClip `a1db8c3`; Codex CLI `0.163.0`; `openai-oauth` `9079e62`. The scripts are plain bash and should work on Linux and macOS, but those platforms have not been tested yet. Reports and pull requests are welcome.

## Credits

- [SupoClip](https://github.com/FujiwaraChoki/supoclip) by FujiwaraChoki
- [openai-oauth](https://github.com/EvanZhouDev/openai-oauth) by EvanZhouDev
- [OpenAI Codex CLI](https://github.com/openai/codex)
