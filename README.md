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

## Contributing

Contributions from the community are welcome and encouraged: bug reports, fixes, documentation, and testing on other setups. This project is small on purpose, so the bar is simple: it should stay easy to read, safe by default and verifiable.

**Where help is most useful**

- Testing on **Linux and macOS** (and Windows with WSL2), and reporting what you saw.
- A **clean-machine install** run of `setup.sh` / `login.sh` / `verify.sh`, including the "login still pending" path (exit code 2).
- Making the install work better for AI agents: clearer steps in [`AGENTS.md`](AGENTS.md), better checks in `verify.sh`.
- Support for **other OpenAI-compatible gateways** or newer pinned versions of the gateway, the Codex CLI or SupoClip.
- README improvements, translations and troubleshooting notes from your own experience.

**How to contribute**

1. Open an [issue](https://github.com/chiarorosa/supoclip-codex-stack/issues) first for anything bigger than a small fix, so we can agree on the approach.
2. Fork the repo, create a branch and keep the change small and focused (one topic per pull request).
3. Run `./verify.sh` against a working stack and say in the pull request what you tested and on which OS and Docker version.
4. Explain the *why* in the description, and update the README or `AGENTS.md` when behaviour changes.

**Ground rules**

- **Never commit secrets**: no `stack.env`, tokens, `auth.json` or logs containing them. If you find a leak, open a private security report instead of a public issue.
- Keep the gateway **private**: no `ports:` for `codex-proxy`, nothing that exposes it beyond the compose network.
- Keep external code **pinned** (a commit hash or exact version) and mention what you reviewed when you bump one.
- Do not patch SupoClip from this repo. Bugs and features in SupoClip itself belong in [its repository](https://github.com/FujiwaraChoki/supoclip); link them here if they affect the stack.
- Scripts stay plain **bash** and idempotent, with LF line endings.
- Be kind and constructive. Maintainers may close issues or pull requests that are off-topic, unsafe or abusive.

By contributing, you agree that your contribution is licensed under the MIT licence of this repository.

## Tested with

Windows 11, Docker Desktop (Linux engine), Git Bash; SupoClip `a1db8c3`; Codex CLI `0.163.0`; `openai-oauth` `9079e62`. The scripts are plain bash and should work on Linux and macOS, but those platforms have not been tested yet. Reports and pull requests are welcome.

## Credits

- [SupoClip](https://github.com/FujiwaraChoki/supoclip) by FujiwaraChoki
- [openai-oauth](https://github.com/EvanZhouDev/openai-oauth) by EvanZhouDev
- [OpenAI Codex CLI](https://github.com/openai/codex)
