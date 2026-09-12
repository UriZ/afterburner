---
name: youtube-reference
description: Turn YouTube gameplay footage into local frame sequences any agent can read. Produces motion bursts (consecutive frames showing speed, scaling, and timing) plus a stage spread (terrain and palette variety). Use before any visual design, implementation, or review work.
user-invocable: true
argument-hint: "--url URL --name SLUG [--bursts \"150,420,700\"] [--burst-fps 4] [--force] [--list]"
allowed-tools: Bash, Read
---

# YouTube Reference Frames

Converts reference gameplay video into stills on disk, so motion can be studied by any agent — including those with no web tools.

## Why this exists

CLAUDE.md requires watching After Burner II gameplay video before any visual work. That was impossible in practice:

- `developer`, `judge`, `qa`, and `visual-qa` are granted only `Read, Write, Edit, Glob, Grep, Bash` — no web access whatsoever
- `architect` and `ui-designer` have `WebFetch`, but WebFetch returns page HTML and text. It does not decode video

For a long time every agent told to "watch the videos" quietly fell back to the static screenshots, and the requirement was ceremonial. This skill makes it real: video becomes **files**, and every agent can read files.

## Why frames instead of watching

A model cannot stream video. Consecutive stills at a known interval are the faithful representation of motion available to it, and they answer motion questions directly:

- **How fast does an object grow as it approaches?** Compare the same enemy across a burst.
- **How quickly does the ground rush past?** Track a ground feature between consecutive frames.
- **How long between enemy waves?** Count frames between appearances.
- **How do flames animate?** Consecutive frames show the cycle.

This is exactly the class of defect that stills-only review kept missing. Issue #105 — enemy sprites plateauing at a fixed size for the entire near half of their approach — is invisible in any single screenshot and obvious across a burst.

## Usage

```bash
bash .claude/skills/youtube-reference/fetch-reference.sh \
  --url "https://www.youtube.com/watch?v=VIDEOID" \
  --name ab2-longplay
```

See what has already been extracted:

```bash
bash .claude/skills/youtube-reference/fetch-reference.sh --list
```

Target specific moments, with finer motion sampling:

```bash
bash .claude/skills/youtube-reference/fetch-reference.sh \
  --url "https://www.youtube.com/watch?v=VIDEOID" \
  --name ab2-night --bursts "300,900" --burst-fps 8
```

## Output

Frames land in `assets/reference/motion/<name>/`:

- `burst-a-01.jpg` … `burst-a-12.jpg` — consecutive frames, 0.25s apart by default. **Read these in order.** This is where motion lives.
- `stage-01.jpg` … — spread across the run, for stage, terrain, and palette variety.

Read them with the Read tool like any other image.

## How to actually use the frames

1. Read a full burst **in sequence**, not one frame in isolation
2. Pick one object and track it across consecutive frames — its size, screen position, and how both change
3. Compare that rate of change against your own build's captured frames from the `game-capture` skill
4. State what you measured, not just what you saw. "The enemy roughly doubles in width over four frames" is reviewable; "the scaling looks right" is not

## Requirements

- `ffmpeg` on PATH (`brew install ffmpeg`)
- Network access on first run

`yt-dlp` is fetched automatically into `.reference-cache/bin/` on first use. It is **not** installed system-wide and does not enter version control.

## Caching

- Downloaded video is cached in `.reference-cache/video/` and reused
- Extraction is skipped if frames already exist — pass `--force` to redo
- The whole `.reference-cache/` directory is gitignored

## Licensing — important

Extracted frames are **local development reference and are gitignored**. Do not commit them and do not publish them. This repository is public; committing frames from copyrighted arcade footage would be redistribution rather than reference use. Any agent needing them regenerates them with this skill.

## Reference sources for this project

The three After Burner II gameplay recordings named in CLAUDE.md. Pass one of those URLs with `--url`; use `--list` first to check whether a set has already been extracted, since the cache is shared across agents.
