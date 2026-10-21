#!/usr/bin/env bash
# TIER 2 — the product a bootstrap produces builds, deploys (dry) and serves.
#
# placement.test.sh proves the tree a bootstrap ends with is the right tree.
# This proves it WORKS, by doing to it what its own pipelines will:
#
#   1. at the 01-product landing (the commit its one pull request merges),
#      run what `checks.yml` runs on that PR — install with the lockfile the
#      phase confirmed, render the wrangler fixture and check the committed
#      config IS that render, typecheck, lint, test, build. The landing WAITS
#      on those checks, so a product they refuse is a bootstrap that never
#      merges;
#   2. the stage lane's own steps, rendered by `orun plan` in the product for
#      a pull request (the verify profile: the deploy profile has no dry run)
#      — `verify-app-structure` (which checks the wrangler config exists
#      BEFORE anything is built), `build-app` (the component's buildCommand:
#      the live wiring render, then the build), `verify-build-output` and
#      `deploy-dry-run` (`wrangler deploy --dry-run --name <reponame>-web-stage`).
#      They run IN THE TREE THE RUNNER STAGES for the job
#      (testing/lib/stage-job.py), with the dependency layout the pinned
#      composition produces, and with the stage wiring document in the job's
#      environment as the platform resolves it (the component's secretEnv) —
#      so the bucket name in the built config is asserted to be the
#      document's, not the fixture's;
#   3. serve the built Worker with `wrangler dev` and run the component's OWN
#      `smokeCommand` against it, verbatim — the check the real deploy ends
#      with — and then read every route the page promises: the heading and
#      title carry the product's name, the links its repository, the Open
#      Graph image is absolute on the origin it was asked on, the uploader is
#      rendered, the static assets are served, an unknown path is a 404 — and
#      the upload, which only the Worker answers: an image PUT to
#      /api/upload is stored in the BLOB bucket under a name with a random
#      suffix (a different one on every request) and streamed back
#      byte-for-byte from /api/blob under a CSP that sandboxes it, while a
#      non-image, an SVG, a missing name and an unknown object are refused.
#      wrangler dev provides the bucket locally, with nothing but the build:
#      no storage key, no third-party service.
#
# What it cannot do is the platform's half: create the repository, mint the
# brokered Cloudflare tokens, apply the bucket, deploy for real and probe
# workers.dev. The R2 root is verified to `terraform validate` (BL2) and its
# plan is part of every pull request's lanes; the apply needs an account.
#
# Needs: orun, node, pnpm, python3 (+PyYAML), git, curl, and the network for
# `pnpm install` and the build's Google Font (or a warm store). A few minutes:
# two installs and builds.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
# shellcheck source=lib/bootstrap.sh
source "$here/lib/bootstrap.sh"

for bin in orun node pnpm python3 git curl; do
  command -v "$bin" >/dev/null || { echo "e2e.test.sh needs $bin on PATH" >&2; exit 1; }
done

scratch="$(mktemp -d)"
dev_pid=""
# wrangler dev runs under pnpm, node and two workerd processes; a TERM to the
# first does not reach the rest, and waiting on it then never returns. So it is
# started as its own process group (setsid) and the whole group is stopped.
cleanup() {
  if [ -n "$dev_pid" ]; then
    kill -TERM -- "-$dev_pid" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 -- "-$dev_pid" 2>/dev/null || break; sleep 0.5; done
    kill -KILL -- "-$dev_pid" 2>/dev/null || true
  fi
  rm -rf "$scratch"
}
trap cleanup EXIT
values="$here/fixtures/acme.json"
repo="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['reponame'])" "$values")"
export CI=1 WRANGLER_SEND_METRICS=false NEXT_TELEMETRY_DISABLED=1 TURBO_TELEMETRY_DISABLED=1

# What checks.yml runs, step for step, read out of the workflow the product
# carries so the two cannot drift: every `run:` of its one job, in order.
checks() { # DIR LOG
  local dir="$1" log="$2" cmd
  while IFS= read -r cmd; do
    echo "   \$ $cmd" | tee -a "$log"
    if ! (cd "$dir" && bash -c "$cmd") >> "$log" 2>&1; then
      echo "FAIL: \`$cmd\` failed in $dir" >&2; tail -40 "$log" >&2; return 1
    fi
  done < <(python3 - "$dir/.github/workflows/checks.yml" <<'PY'
import sys, yaml
wf = yaml.safe_load(open(sys.argv[1]))
for job in wf["jobs"].values():
    for step in job["steps"]:
        if "run" in step:
            print(step["run"].strip())
PY
)
}

echo "── the offline bootstrap (testing/lib/bootstrap.sh)"
tree="$scratch/$repo"
bootstrap_offline "$root" "$tree" "$values" "$scratch/logs" > "$scratch/bootstrap.log" 2>&1 || {
  echo "FAIL: the offline bootstrap stopped" >&2; tail -40 "$scratch/bootstrap.log" >&2; exit 1; }
echo "   2 phases placed and landed"
s01="$(git -C "$tree" rev-parse HEAD~1)"

# ── 1. the product's one pull request ──────────────────────────────────────
echo "── 01-product's landing, under the checks its PR waits on"
git -C "$tree" worktree add -q "$scratch/at-01" "$s01"
checks "$scratch/at-01" "$scratch/checks-01.log"
# The first Checks build is done; its tree is not needed again, and the disk is shared.
git -C "$tree" worktree remove --force "$scratch/at-01"

# ── 2. the stage lane's steps, in the job's own tree ──────────────────────
echo "── the stage lane: verify-app-structure, build-app, verify-build-output, deploy-dry-run"
# A pull request that changes the page: the lane `orun plan` gives it.
git -C "$tree" checkout -q -b e2e-pr
echo "<!-- a change to the page's component -->" >> "$tree/apps/web/README.md"
git -C "$tree" -c user.email=e2e@example.invalid -c user.name=e2e commit -qam "a pull request"
(cd "$tree" && orun plan --intent intent.yaml --trigger github-pull-request --changed \
   --base main --head HEAD --env stage --output "$scratch/plan.json") > "$scratch/plan.log" 2>&1 \
  || { echo "FAIL: orun plan" >&2; tail -15 "$scratch/plan.log" >&2; exit 1; }
python3 - "$scratch/plan.json" "$scratch/steps" <<'PY'
import json, pathlib, sys
plan = json.load(open(sys.argv[1]))
out = pathlib.Path(sys.argv[2]); out.mkdir()
job = next(j for j in plan["jobs"] if j["component"] == "web" and j["environment"] == "stage")
for s in job["steps"]:
    if s["id"] in ("verify-app-structure", "build-app", "verify-build-output", "deploy-dry-run"):
        (out / f"{s['id']}.sh").write_text(s.get("run") or "")
    if s["id"] == "install-workspace-dependencies":
        (out / "install.sh").write_text(s.get("run") or "")
        (out / "install.wd").write_text(s.get("working-directory") or ".")
        (out / "install.scope").write_text(s.get("scope") or "job")
(out / "path").write_text(job.get("path") or "apps/web")
for k, v in (job.get("env") or {}).items():
    (out / "env").open("a").write(f"export {k}={json.dumps(v)}\n")
(out / "secrets").write_text("\n".join(r["asEnv"] for r in job.get("secretRefs") or []))
PY
# The job's private tree, staged as orun stages it. The source checkout
# carries no build output (nothing was built in it), and its dependencies are
# what the pinned composition says: a lane-scoped install ran once in the
# source tree and is linked in, or the job installs its own.
work="$tree/.orun/runs/e2e/web.stage.verify-deploy/work"
[ -f "$scratch/steps/install.sh" ] || { echo "FAIL: the stage lane has no install step" >&2; exit 1; }
if [ "$(cat "$scratch/steps/install.scope")" = lane ]; then
  (cd "$tree" && bash -e "$scratch/steps/install.sh") > "$scratch/install.log" 2>&1 \
    || { echo "FAIL: the lane's install step" >&2; tail -30 "$scratch/install.log" >&2; exit 1; }
  python3 "$here/lib/stage-job.py" "$tree" "$work" --shared-deps
  [ -L "$work/node_modules" ] || { echo "FAIL: the staged tree's node_modules is not the lane's symlink" >&2; exit 1; }
  echo "   staged: $(realpath --relative-to="$tree" "$work"); install scope: lane — node_modules → the source tree's"
else
  python3 "$here/lib/stage-job.py" "$tree" "$work"
  echo "   staged: $(realpath --relative-to="$tree" "$work"); install scope: job — installing inside it"
  echo "   ▸ install-workspace-dependencies"
  (cd "$work/$(cat "$scratch/steps/path")/$(cat "$scratch/steps/install.wd")" && bash -e "$scratch/steps/install.sh") \
    > "$scratch/install.log" 2>&1 || { echo "FAIL: the lane's install step" >&2; tail -30 "$scratch/install.log" >&2; exit 1; }
  [ -d "$work/node_modules" ] && [ ! -L "$work/node_modules" ] \
    || { echo "FAIL: the job's install did not land inside its own tree" >&2; exit 1; }
fi
[ ! -e "$work/apps/web/.open-next" ] || { echo "FAIL: the staged tree carries build output" >&2; exit 1; }
# What the platform resolves into the job before its first step: the wiring
# documents the R2 root lease-published (the component's secretEnv), shaped as
# its `output "wiring"` is. Names no fixture carries, so the built config
# proves which one it was rendered from.
for env in stage prod; do
  key="WIRING_CLOUDFLARE_R2_$(echo "$env" | tr a-z A-Z)"
  grep -qx "$key" "$scratch/steps/secrets" || { echo "FAIL: the stage lane does not resolve $key" >&2; exit 1; }
done
stage_bucket="stg-$repo-stage-5ca1ab1e"
export WIRING_CLOUDFLARE_R2_STAGE='{"r2_bucket_name":"'"$stage_bucket"'"}'
export WIRING_CLOUDFLARE_R2_PROD='{"r2_bucket_name":"prod-'"$repo"'-prod-5ca1ab1e"}'
for step in verify-app-structure build-app verify-build-output deploy-dry-run; do
  [ -f "$scratch/steps/$step.sh" ] || { echo "FAIL: the stage verify lane has no $step step" >&2; exit 1; }
  echo "   ▸ $step"
  # The runner's per-job environment: the job's env (intent environment
  # `env:`), its resolved secrets, and ORUN_ENVIRONMENT; the step runs in the
  # component's directory.
  if ! (cd "$work/$(cat "$scratch/steps/path")" && \
        { [ -f "$scratch/steps/env" ] && source "$scratch/steps/env"; true; } && \
        export ORUN_ENVIRONMENT=stage && bash -e "$scratch/steps/$step.sh") > "$scratch/$step.log" 2>&1; then
    echo "FAIL: the deploy lane's $step step" >&2; tail -40 "$scratch/$step.log" >&2; exit 1
  fi
done
grep -q "\"bucket_name\": \"$stage_bucket\"" "$work/apps/web/wrangler.jsonc" \
  || { echo "FAIL: the lane's build did not render the stage bucket name from its wiring document" >&2; exit 1; }
grep -q 'BLOB' "$scratch/deploy-dry-run.log" && grep -q "$stage_bucket" "$scratch/deploy-dry-run.log" \
  || { echo "FAIL: the dry run does not bind BLOB to the stage bucket" >&2; tail -20 "$scratch/deploy-dry-run.log" >&2; exit 1; }
echo "   the built config binds BLOB to the stage document's bucket; the dry run accepts it"

# ── 3. serve it, and smoke it as the deploy does ───────────────────────────
echo "── wrangler dev over the built Worker"
port=$(python3 -c "import socket;s=socket.socket();s.bind(('127.0.0.1',0));print(s.getsockname()[1]);s.close()")
(cd "$work/apps/web" && exec setsid pnpm exec wrangler dev --config wrangler.jsonc --ip 127.0.0.1 --port "$port" \
   --name "$repo-web-stage" --show-interactive-dev-session=false) > "$scratch/dev.log" 2>&1 < /dev/null &
dev_pid=$!
url="http://127.0.0.1:$port"
for _ in $(seq 1 90); do
  curl -s -o /dev/null "$url/favicon.ico" && break
  kill -0 "$dev_pid" 2>/dev/null || { echo "FAIL: wrangler dev exited" >&2; tail -30 "$scratch/dev.log" >&2; exit 1; }
  sleep 1
done
curl -s -o /dev/null "$url/favicon.ico" || { echo "FAIL: wrangler dev never answered" >&2; tail -30 "$scratch/dev.log" >&2; exit 1; }

echo "   ▸ the component's own smokeCommand, DEPLOYED_URL=$url"
smoke="$(python3 -c "import yaml,sys;print(yaml.safe_load(open(sys.argv[1]))['spec']['parameters']['smokeCommand'])" "$tree/apps/web/component.yaml")"
DEPLOYED_URL="$url" bash -c "$smoke" || { echo "FAIL: the deploy's smoke refused the page" >&2; exit 1; }

echo "   ▸ every route the page promises"
python3 - "$url" "$values" <<'PY'
import html, json, re, struct, sys, urllib.error, urllib.request, zlib
from urllib.parse import quote
base, values = sys.argv[1], json.load(open(sys.argv[2]))
name, repo, org = values["productname"], values["reponame"], values["githuborg"]
problems = []
def bad(m): problems.append(m)
def req(path, method="GET", body=None, headers=None):
    r = urllib.request.Request(base + path, data=body, method=method, headers=headers or {})
    try:
        with urllib.request.urlopen(r, timeout=30) as resp:
            return resp.status, resp.headers, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.headers, e.read()
def get(path):
    s, h, b = req(path)
    return s, h.get("content-type", ""), b

status, _, body = get("/")
page = body.decode()
if status != 200:
    bad(f"/ answered {status}")
h1 = re.search(r"<h1[^>]*>(.*?)</h1>", page, re.S)
if not h1 or html.unescape(re.sub(r"<[^>]+>", "", h1.group(1))).strip() != name:
    bad(f"the page's heading is {h1 and h1.group(1)!r}, not {name!r}")
title = re.search(r"<title>(.*?)</title>", page, re.S)
if not title or html.unescape(title.group(1)) != name:
    bad(f"the page's <title> is {title and title.group(1)!r}, not {name!r}")
links = re.findall(r'href="(https://github\.com/[^"]*)"', page)
if links != [f"https://github.com/{org}/{repo}"] * 2:
    bad(f"the page's repository links are {links}, not github.com/{org}/{repo} twice")
if "blob-starter" in page or "R2 on Cloudflare" in page:
    bad("the page still carries the baseline's name")
og = re.search(r'<meta property="og:image" content="([^"]+)"', page)
if not og or not og.group(1).startswith(f"{base}/opengraph-image.png"):
    bad(f"og:image is {og and og.group(1)!r} — not absolute on the origin it was asked on ({base})")
RASTER = "image/png,image/jpeg,image/gif,image/webp,image/avif"
if "Upload an image" not in page or f'accept="{RASTER}"' not in page:
    bad(f"the page does not render the uploader, offering {RASTER} (raster images only)")

# THE ROUTES ONLY THE WORKER ANSWERS: an image stored in the BLOB bucket and
# streamed back. A real 1×1 PNG, so the bytes that come back can be compared.
def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(b"\x00\x00\x00\x00\x00")) + chunk(b"IEND", b""))
def upload(pathname, data, ctype):
    q = f"?pathname={quote(pathname)}" if pathname is not None else ""
    return req("/api/upload" + q, "PUT", data, {"content-type": ctype})
stored = []
for _ in range(2):
    s, h, b = upload("e2e photo.png", png, "image/png")
    if s != 200:
        bad(f"PUT /api/upload answered {s}: {b[:200]!r}")
        continue
    j = json.loads(b)
    if not re.fullmatch(r"e2e photo-[0-9a-f]{30}\.png", j.get("pathname", "")):
        bad(f"the upload was stored as {j.get('pathname')!r}, not the name plus a random suffix")
    if j.get("contentType") != "image/png" or j.get("size") != len(png):
        bad(f"the upload answered {j}, not image/png of {len(png)} bytes")
    stored.append(j.get("pathname"))
if len(stored) == 2 and stored[0] == stored[1]:
    bad(f"two uploads of one name were stored under one key ({stored[0]}) — the suffix must change per request")
for key in stored:
    s, h, b = req(f"/api/blob?pathname={quote(key)}")
    if s != 200 or b != png:
        bad(f"GET /api/blob for {key!r} answered {s} with {len(b)} bytes, not the {len(png)} uploaded")
    if h.get("content-type") != "image/png" or h.get("x-content-type-options") != "nosniff" or not h.get("etag"):
        bad(f"GET /api/blob for {key!r} answered content-type {h.get('content-type')!r}, "
            f"nosniff {h.get('x-content-type-options')!r}, etag {h.get('etag')!r}")
    # Served from the product's own origin: whatever an object is, it must
    # not run script there.
    if h.get("content-security-policy") != "default-src 'none'; sandbox":
        bad(f"GET /api/blob for {key!r} answered CSP {h.get('content-security-policy')!r}, "
            f"not \"default-src 'none'; sandbox\"")
# …and what the routes refuse: the template's refusals, and an SVG — an image
# the template accepted, and a document whose script would run on this origin.
refused = "We only accept PNG, JPEG, GIF, WebP and AVIF images"
s, h, b = upload("notes.pdf", b"%PDF-1.4", "application/pdf")
if s != 400 or json.loads(b or b"{}").get("error") != refused:
    bad(f"a PDF upload answered {s} {b[:120]!r}, not 400 {refused!r}")
svg = b'<svg xmlns="http://www.w3.org/2000/svg"><script>alert(document.domain)</script></svg>'
s, h, b = upload("logo.svg", svg, "image/svg+xml")
if s != 400 or json.loads(b or b"{}").get("error") != refused:
    bad(f"an SVG upload answered {s} {b[:120]!r}, not 400 {refused!r}")
s, h, b = upload(None, png, "image/png")
if s != 400:
    bad(f"an upload with no pathname answered {s}, not 400")
s, _, b = get("/api/blob")
if s != 400:
    bad(f"GET /api/blob with no pathname answered {s}, not 400")
s, _, b = get("/api/blob?pathname=no-such-object.png")
if s != 404 or b != b"Not found":
    bad(f"GET /api/blob for an unknown object answered {s} {b[:80]!r}, not the route's own 404")

for path, want, ctype in (("/opengraph-image.png", 200, "image/png"), ("/favicon.ico", 200, "image/"),
                          ("/vercel.svg", 200, "image/svg+xml"), ("/github.svg", 200, "image/svg+xml"),
                          ("/no-such-page", 404, "text/html")):
    s, ct, b = get(path)
    if s != want or not ct.startswith(ctype):
        bad(f"{path} answered {s} {ct}, want {want} {ctype}")
    if path.endswith(".png") and b[:8] != b"\x89PNG\r\n\x1a\n":
        bad(f"{path} is not a PNG")

if problems:
    for p in problems:
        print(f"  ✕ {p}", file=sys.stderr)
    sys.exit(1)
print(f"   / (the product's name, links, origin and uploader); one image uploaded twice, stored as")
print(f"   {stored[0]!r} and {stored[1]!r}, streamed back byte for byte, sandboxed;")
print(f"   a PDF, an SVG, a missing name and an unknown object refused; the Open Graph image, the static")
print(f"   assets and a 404 — the product's own")
PY

echo "e2e.test.sh: ok"
