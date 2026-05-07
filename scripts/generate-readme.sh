#!/usr/bin/env bash
# Fills the auto-managed sections of README.md from `gh` API queries.
# Empty sections render an empty marker block, so the heading disappears
# when there's nothing to show.
#
# Required env: GH_TOKEN, OWNER
#
# Local run: OWNER=MrEhbr GH_TOKEN=$(gh auth token) bash scripts/generate-readme.sh

set -euo pipefail

README="${README:-README.md}"
: "${OWNER:?OWNER must be set}"
: "${GH_TOKEN:?GH_TOKEN must be set}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# --- Public projects -------------------------------------------------
# Non-fork, non-archived owned repos with a description, sorted by latest
# push, top 8.
gh repo list "$OWNER" \
  --no-archived \
  --source \
  --limit 100 \
  --json name,description,url,pushedAt,isFork |
  jq -r '
    [.[] | select(.isFork == false) | select(.description != null and .description != "")]
    | sort_by(.pushedAt) | reverse
    | .[0:8]
    | if length == 0 then ""
      else
        "## Projects\n\n" +
        ([.[] | "- **[\(.name)](\(.url))** — \(.description)"] | join("\n"))
      end
  ' >"$TMPDIR/repos.md"

# --- Recent activity -----------------------------------------------
# Public events, deduplicated, top 5.
gh api "users/$OWNER/events/public" --paginate |
  jq -s 'add // []' |
  jq '
    [ .[] | select(.type == "PushEvent" or .type == "PullRequestEvent"
                or .type == "IssuesEvent" or .type == "IssueCommentEvent"
                or .type == "PullRequestReviewEvent"
                or .type == "PullRequestReviewCommentEvent"
                or .type == "CreateEvent" or .type == "ReleaseEvent") ]
    | sort_by(.created_at) | reverse
    | unique_by(
        .type + "|" + .repo.name + "|"
          + (.payload.action // "") + "|"
          + (.payload.ref_type // "") + "|"
          + ((.payload.issue.number // .payload.pull_request.number // 0) | tostring)
      )
    | sort_by(.created_at) | reverse
    | .[0:5]
    | [ .[] | {
        type,
        repo:     .repo.name,
        action:   (.payload.action // null),
        ref_type: (.payload.ref_type // null),
        tag:      (.payload.release.tag_name // null),
        number:   (.payload.pull_request.number // .payload.issue.number // null),
        merged:   (.payload.pull_request.merged // false)
      } ]
  ' >"$TMPDIR/activity.json"

# --- Render: substitute markers ------------------------------------
README="$README" TMPDIR="$TMPDIR" python3 <<'PY'
import json, os, re
from pathlib import Path

readme_path = Path(os.environ["README"])
tmpdir      = Path(os.environ["TMPDIR"])

EMOJI = {
    "PushEvent":   "⬆️",
    "CreateEvent": "🌱",
    "DeleteEvent": "🗑️",
    "IssuesEvent": {
        "opened": "🆕", "edited": "📝", "closed": "❌", "reopened": "🔄",
        "assigned": "👤", "unassigned": "👤", "labeled": "🏷️", "unlabeled": "🏷️",
    },
    "PullRequestEvent": {
        "opened": "📥", "edited": "📝", "closed": "❌", "merged": "🔀",
        "reopened": "🔄", "assigned": "👤", "unassigned": "👤",
        "review_requested": "🔍", "review_request_removed": "🔍",
        "labeled": "🏷️", "unlabeled": "🏷️", "synchronize": "🔄",
    },
    "ReleaseEvent": { "draft": "✏️", "published": "🚀" },
    "ForkEvent": "🍴",
    "CommitCommentEvent":            "🗣",
    "IssueCommentEvent":             "🗣",
    "PullRequestReviewEvent":        "🔎",
    "PullRequestReviewCommentEvent": "🗣",
    "PullRequestReviewThreadEvent":  "🧵",
    "RepositoryEvent": "📦",
    "WatchEvent":      "⭐",
    "StarEvent":       "⭐",
    "PublicEvent":     "🌍",
    "GollumEvent":     "📝",
}

def cap(s):
    return s[0].upper() + s[1:] if s else s

def emoji(e):
    m = EMOJI.get(e["type"])
    if isinstance(m, str):
        return m
    if isinstance(m, dict):
        action = "merged" if (e["type"] == "PullRequestEvent" and e.get("merged")) else (e.get("action") or "")
        return m.get(action, "")
    return ""

def body(e):
    t      = e["type"]
    repo   = e["repo"]
    rurl   = f"https://github.com/{repo}"
    rlink  = f"[{repo}]({rurl})"
    n      = e.get("number")
    if t == "PushEvent":
        return f"Pushed to {rlink}"
    if t == "PullRequestEvent":
        action = "Merged" if e.get("merged") else cap(e.get("action") or "Updated")
        return f"{action} PR [#{n}]({rurl}/pull/{n}) in {rlink}"
    if t == "IssuesEvent":
        return f"{cap(e.get('action') or 'Updated')} issue [#{n}]({rurl}/issues/{n}) in {rlink}"
    if t == "IssueCommentEvent":
        return f"Commented on [#{n}]({rurl}/issues/{n}) in {rlink}"
    if t == "PullRequestReviewCommentEvent":
        return f"Commented on PR [#{n}]({rurl}/pull/{n}) in {rlink}"
    if t == "PullRequestReviewEvent":
        return f"Reviewed PR [#{n}]({rurl}/pull/{n}) in {rlink}"
    if t == "CreateEvent":
        return f"Created {e.get('ref_type') or 'ref'} in {rlink}"
    if t == "ReleaseEvent":
        tag = e.get("tag")
        if tag:
            return f"Released [{tag}]({rurl}/releases/tag/{tag}) in {rlink}"
        return f"Released in {rlink}"
    return None

def line(e):
    b = body(e)
    if b is None:
        return None
    em = emoji(e)
    return f"- {em} {b}" if em else f"- {b}"

events = json.loads((tmpdir / "activity.json").read_text())
bullets = [b for b in (line(e) for e in events) if b]
activity_md = (
    "## Recent activity\n\n" + "\n".join(bullets)
) if bullets else ""

repos_md = (tmpdir / "repos.md").read_text().rstrip()

text = readme_path.read_text()
for tag, content in (("repos", repos_md), ("activity", activity_md)):
    body = f"\n{content}\n" if content else ""
    text = re.sub(
        rf"(<!--START_SECTION:{tag}-->)(.*?)(<!--END_SECTION:{tag}-->)",
        lambda m: m.group(1) + body + m.group(3),
        text,
        flags=re.DOTALL,
    )
readme_path.write_text(text)
PY
