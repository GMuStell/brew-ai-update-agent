#!/bin/zsh
set -u
PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
BREW="$(command -v brew || true)"; COPILOT="$(command -v copilot || true)"; PYTHON="$(command -v python3 || true)"
STATE_DIR="$HOME/Projects/tools/brew-ai-update-agent/state"
CACHE_DIR="$STATE_DIR/cache"
RAW="$STATE_DIR/outdated.txt"; PENDING="$STATE_DIR/pending.txt"; REPORT="$STATE_DIR/latest-report.md"
LOG="$STATE_DIR/agent.log"; PROMPT="$STATE_DIR/prompt.txt"; AI_JSON="$STATE_DIR/ai-output.json"
mkdir -p "$CACHE_DIR"; exec >>"$LOG" 2>&1
printf '\n[%s] Start v2.5\n' "$(date '+%Y-%m-%d %H:%M:%S')"
notify(){ /usr/bin/osascript -e "display notification \"$1\" with title \"Brew AI Update Agent\"" 2>/dev/null || true; }
fail(){ printf '# Brew AI Update Agent\n\nError: %s\n' "$1" > "$REPORT"; notify "$1"; printf '[ERROR] %s\n' "$1"; exit 1; }
[[ -n "$BREW" ]] || fail "Homebrew not found"; [[ -n "$COPILOT" ]] || fail "GitHub Copilot CLI not found"; [[ -n "$PYTHON" ]] || fail "python3 not found"
"$BREW" update || fail "brew update failed; see agent.log"
{
 "$BREW" outdated --formula --verbose 2>/dev/null || true
 "$BREW" outdated --cask --greedy --verbose 2>/dev/null || true
} > "$STATE_DIR/outdated-raw.txt"
"$PYTHON" - "$STATE_DIR/outdated-raw.txt" "$RAW" <<'PY'
import re,sys,pathlib
src,dst=map(pathlib.Path,sys.argv[1:])
s=src.read_text(errors='replace')
s=re.sub(r'\x1b\][^\x07]*(?:\x07|\x1b\\)','',s)
s=re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]','',s)
seen=[]
for line in s.splitlines():
 line=' '.join(line.split())
 if line and line not in seen: seen.append(line)
dst.write_text('\n'.join(seen)+'\n')
PY
: > "$PENDING"; TOTAL=0; FRESH=0
while IFS= read -r line; do
 [[ -z "$line" ]] && continue; TOTAL=$((TOTAL+1)); key=$(printf '%s' "$line" | /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}'); cache="$CACHE_DIR/$key.json"
 if [[ ! -f "$cache" ]] || ! /usr/bin/find "$cache" -mtime -28 -print -quit | /usr/bin/grep -q .; then printf '%s\t%s\n' "$key" "$line" >> "$PENDING"; FRESH=$((FRESH+1)); fi
done < "$RAW"
if (( TOTAL==0 )); then printf '# Homebrew AI Update Report\n\nGenerated: %s\n\nEverything is up to date.\n' "$(date '+%Y-%m-%d %H:%M:%S')" > "$REPORT"; notify "Everything is up to date"; exit 0; fi
if (( FRESH>0 )); then
 ITEMS=$(cut -f2- "$PENDING")
 cat > "$PROMPT" <<PROMPT_TEXT
Analyze EVERY listed Homebrew update for a macOS development workstation.
Context: Java 17 is used with Scala/Metals/sbt; Databricks CLI with Asset Bundles; Terraform/TFLint; Node/pnpm; Docker Desktop; pyenv/pipx.
Research official release notes, changelogs, security advisories, and compatibility information when available. Prefer official project, vendor, GitHub release, and Homebrew sources. Do not run shell commands, edit files, or install anything.
Separate verified package-specific facts from general precautions. If you cannot verify a package-specific fact, state exactly: "No package-specific finding verified."
Return ONLY a valid compact JSON array, with no Markdown fences and no surrounding text. Escape all newlines inside strings.
One object per input, same order, exactly these string fields:
{"package":"exact clean package name","version_change":"old -> new","classification":"UPDATE|REVIEW|HOLD","emoji":"🟢|🟡|🔴","confirmed_findings":"verified release/security/compatibility facts or No package-specific finding verified.","why":"recommendation reason","benefits":"concrete verified benefit or clearly labeled general expected benefit","risks":"verified risk plus clearly labeled general precaution","checks_before":"specific commands/checks before update; use semicolons between commands","checks_after":"specific commands/checks after update; use semicolons between commands"}
Classification: UPDATE for low-risk patch/routine app update; REVIEW for toolchain, dependency-sensitive, minor/major change, unclear evidence, or meaningful compatibility checks; HOLD only for a concrete established blocker or known incompatibility.
Updates:
$ITEMS
PROMPT_TEXT
 "$COPILOT" -p "$(cat "$PROMPT")" -s --no-ask-user --no-custom-instructions --no-color --stream off --allow-all-tools --allow-all-urls --deny-tool='shell' --deny-tool='write' > "$AI_JSON" || fail "Copilot analysis failed; see agent.log"
 "$PYTHON" - "$AI_JSON" "$PENDING" "$CACHE_DIR" <<'PY'
import json,sys,pathlib,re
ai,pending,cache=map(pathlib.Path,sys.argv[1:]); raw=ai.read_text(errors='replace').strip()
if raw.startswith('```'): raw=raw.split('\n',1)[1].rsplit('```',1)[0].strip()
data=json.loads(raw,strict=False); rows=[x.split('\t',1) for x in pending.read_text().splitlines() if '\t' in x]
if not isinstance(data,list) or len(data)!=len(rows): raise SystemExit(f'Invalid item count: expected {len(rows)}, got {len(data) if isinstance(data,list) else "non-list"}')
req={'package','version_change','classification','emoji','confirmed_findings','why','benefits','risks','checks_before','checks_after'}; emojis={'UPDATE':'🟢','REVIEW':'🟡','HOLD':'🔴'}
for (key,item),obj in zip(rows,data):
 if not isinstance(obj,dict) or set(obj)!=req or obj.get('classification') not in emojis: raise SystemExit(f'Invalid schema for {item}')
 for k in req: obj[k]=re.sub(r'\s+',' ',re.sub(r'\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b\[[0-?]*[ -/]*[@-~]|\x07','',str(obj[k]))).strip()
 obj['emoji']=emojis[obj['classification']]; (cache/f'{key}.json').write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
PY
 [[ $? -eq 0 ]] || fail "Copilot returned invalid JSON; cache not replaced"
fi
"$PYTHON" - "$RAW" "$CACHE_DIR" "$REPORT" "$FRESH" <<'PY'
import sys,json,pathlib,hashlib,datetime
raw,cache,report=map(pathlib.Path,sys.argv[1:4]); fresh=int(sys.argv[4]); items=[]
for line in raw.read_text().splitlines():
 if not line.strip(): continue
 p=cache/f'{hashlib.sha256(line.encode()).hexdigest()}.json'
 if p.exists(): items.append(json.loads(p.read_text()))
 else: items.append({'package':line.split(' ',1)[0],'version_change':line,'classification':'REVIEW','emoji':'🟡','confirmed_findings':'Assessment unavailable.','why':'Manual review required.','benefits':'Unknown.','risks':'Manual review required.','checks_before':'Review package details.','checks_after':'Verify version and dependent workflows.'})
order={'UPDATE':0,'REVIEW':1,'HOLD':2}; items.sort(key=lambda x:(order[x['classification']],x['package'].lower())); counts={k:sum(x['classification']==k for x in items) for k in order}
out=['# Homebrew AI Update Report','',f'Generated: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}  ',f'Pending updates: {len(items)}  ',f'AI analyses refreshed: {fresh}  ',f"Summary: 🟢 {counts['UPDATE']} | 🟡 {counts['REVIEW']} | 🔴 {counts['HOLD']}",'','> No updates were installed automatically. Recommendations are shown weekly and refreshed after 28 days.','']
for cls,title in [('UPDATE','🟢 UPDATE'),('REVIEW','🟡 REVIEW'),('HOLD','🔴 HOLD')]:
 group=[x for x in items if x['classification']==cls]
 if not group: continue
 out += [f'## {title} ({len(group)})','']
 for x in group:
  out += [f"### {x['emoji']} {x['package']}",'',x['version_change'],'',f"**Recommendation:** {x['classification']}  ",f"**Confirmed findings:** {x['confirmed_findings']}  ",f"**Why:** {x['why']}  ",f"**Benefits:** {x['benefits']}  ",f"**Risks:** {x['risks']}  ",f"**Checks before:** `{x['checks_before']}`  ",f"**Checks after:** `{x['checks_after']}`",'','---','']
report.write_text('\n'.join(out)+'\n')
PY
GREEN=$(/usr/bin/grep -c '^### 🟢' "$REPORT" || true); YELLOW=$(/usr/bin/grep -c '^### 🟡' "$REPORT" || true); RED=$(/usr/bin/grep -c '^### 🔴' "$REPORT" || true)
notify "$TOTAL updates: 🟢 $GREEN  🟡 $YELLOW  🔴 $RED"; printf '[%s] Complete v2.5: total=%d refreshed=%d green=%s yellow=%s red=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$TOTAL" "$FRESH" "$GREEN" "$YELLOW" "$RED"
