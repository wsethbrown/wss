#!/usr/bin/env bash
#
# Tests for bin/relaunch-production in its test mode (WSS_RELAUNCH_MODE=test):
# ssh, scp, kamal, docker, curl and gh are stubs that log each call, so the
# control flow, prompts, re-run detection, --from/--only, --dry-run and the
# refusal paths run here without a server. Two cases go further:
#   - the database load runs for real against a local Postgres
#     (PGHOST/PGUSER/PGPASSWORD, default 127.0.0.1 / wss / password);
#   - the master-key step runs the real Ruby (needs ruby + activesupport).
# Either is skipped, with a message, when its tool is not available.
#
#   test/bin/relaunch_production_test.sh
#
# Every run seeds fake secrets and finally checks that none of them ever
# appeared in any output, call log or state file.

set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO/bin/relaunch-production"
T="$(mktemp -d "${TMPDIR:-/tmp}/relaunch-test.XXXXXX")"
trap 'rm -rf "$T"' EXIT

PASSES=0; FAILS=0; SKIPS=0
pass() { PASSES=$((PASSES + 1)); printf '  ok    %s\n' "$1"; }
flunk() { FAILS=$((FAILS + 1)); printf '  FAIL  %s\n' "$1"; [ -z "${2:-}" ] || printf '%s\n' "$2" | sed 's/^/          /' | tail -n 25; }
skip() { SKIPS=$((SKIPS + 1)); printf '  skip  %s\n' "$1"; }
check() { local d="$1"; shift; if "$@"; then pass "$d"; else flunk "$d" "$(tail -n 25 "$OUT" 2>/dev/null)"; fi; }
has()   { grep -qF -- "$1" "${2:-$OUT}"; }
lacks() { ! grep -qF -- "$1" "${2:-$OUT}"; }

NEW_IP="51.81.10.20"
export PGHOST="${PGHOST:-127.0.0.1}" PGUSER="${DATABASE_USERNAME:-wss}" PGPASSWORD="${DATABASE_PASSWORD:-password}"

# ---------------------------------------------------------------- fixtures

FAKE_VARS="KAMAL_REGISTRY_PASSWORD WSS_DATABASE_PASSWORD AR_ENCRYPTION_PRIMARY_KEY AR_ENCRYPTION_DETERMINISTIC_KEY
AR_ENCRYPTION_KEY_DERIVATION_SALT STRIPE_PUBLISHABLE_KEY STRIPE_WEBHOOK_SECRET STRIPE_MONTHLY_PRICE_ID
STRIPE_QUARTERLY_PRICE_ID STRIPE_YEARLY_PRICE_ID R2_ENDPOINT R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_BUCKET
SMTP_ADDRESS SMTP_USERNAME SMTP_PASSWORD GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET SENTRY_DSN"
TURNSTILE_SITE="0x4AAAAAAAfakeSiteKey77"
TURNSTILE_SECRET="0x4AAAAAAAfakeSecretKey88"
fake_value() { printf 'FAKESECRET%s9q' "$(printf '%s' "$1" | tr -d '_' | tr '[:upper:]' '[:lower:]')"; }
ALL_FAKE_VALUES=""

write_env() {  # write_env FILE [NAME-TO-OMIT...]
  local f="$1"; shift
  : > "$f"; chmod 600 "$f"
  local v skipn
  for v in $FAKE_VARS; do
    for skipn in "$@"; do [ "$v" = "$skipn" ] && continue 2; done
    printf "export %s='%s'\n" "$v" "$(fake_value "$v")" >> "$f"
  done
  printf "export STRIPE_SECRET_KEY='sk_live_FAKESECRETstripe123'\n" >> "$f"
}
for v in $FAKE_VARS; do ALL_FAKE_VALUES="$ALL_FAKE_VALUES $(fake_value "$v")"; done
ALL_FAKE_VALUES="$ALL_FAKE_VALUES FAKESECRETstripe123 $TURNSTILE_SITE $TURNSTILE_SECRET"

# A fresh world per case: a git repo with a GitHub stand-in, HOME with an
# SSH key and the downloaded bucket, the env file, state and call log.
new_world() {
  W="$T/w$1"; mkdir -p "$W"
  export HOME="$W/home"; mkdir -p "$HOME/.ssh"; echo key > "$HOME/.ssh/id_ed25519"
  git init -q --bare "$W/remote.git"
  git init -q "$W/repo"
  ( cd "$W/repo" && mkdir -p bin config && cp "$REPO/config/deploy.yml" config/ && cp "$REPO/bin/kamal-deploy" bin/ \
    && printf '/config/master.key\n' > .gitignore && echo garbage > config/credentials.yml.enc \
    && git -c user.email=t@example.com -c user.name=t add -A && git -c user.email=t@example.com -c user.name=t commit -qm init \
    && git remote add origin "$W/remote.git" && git push -q -u origin HEAD 2>/dev/null )
  git -C "$W/repo" config user.email t@example.com; git -C "$W/repo" config user.name t
  write_env "$W/env"
  export WSS_RELAUNCH_MODE=test WSS_RELAUNCH_ROOT="$W/repo" WSS_RELAUNCH_ENV_FILE="$W/env" \
         WSS_RELAUNCH_STATE="$W/state" WSS_RELAUNCH_CALL_LOG="$W/calls"
  : > "$W/calls"
  # Clear stub answers left by the previous case.
  local name; for name in $(env | sed -n 's/^\(WSS_STUB_[A-Z0-9_]*\)=.*/\1/p'); do unset "$name"; done
}

# run_wizard "answer lines" ARGS... — runs the script, output in $OUT, status in $RC.
N=0
run_wizard() {
  local answers="$1"; shift
  N=$((N + 1)); OUT="$T/out.$N"
  printf '%s' "$answers" | "$SCRIPT" "$@" > "$OUT" 2>&1; RC=$?
  cp "$W/calls" "$T/calls.$N" 2>/dev/null || true
}

make_bucket() {  # make_bucket DIR — two small but real pg_dumps
  local dir="$1" db="relaunch_test_src_$$"
  mkdir -p "$dir/db-backups"
  psql -X -q -d postgres -c "DROP DATABASE IF EXISTS $db" -c "CREATE DATABASE $db" || return 1
  {
    echo "CREATE TABLE users (id bigserial PRIMARY KEY, email text, credits integer NOT NULL DEFAULT 0);"
    echo "CREATE TABLE presentations (id bigserial PRIMARY KEY, title text);"
    echo "CREATE TABLE user_presentations (id bigserial PRIMARY KEY, user_id bigint, presentation_id bigint);"
    echo "CREATE TABLE credit_transactions (id bigserial PRIMARY KEY, user_id bigint, amount integer);"
    local i; for i in $(seq 1 18); do echo "CREATE TABLE filler_$i (id serial PRIMARY KEY);"; done
    echo "INSERT INTO users (email, credits) VALUES ('a@example.com', 1), ('b@example.com', 0), ('c@example.com', 0);"
    echo "INSERT INTO presentations (title) VALUES ('Hakata'), ('Value vs. Prestige');"
    echo "INSERT INTO user_presentations (user_id, presentation_id) VALUES (1, 1);"
    echo "INSERT INTO credit_transactions (user_id, amount) VALUES (1, 2), (1, -1);"
  } | psql -X -q -v ON_ERROR_STOP=1 -d "$db" || return 1
  # Production's role is not the local one: rewrite the owner so an unfiltered
  # load would fail, and add the \restrict line newer pg_dump writes.
  pg_dump "$db" | sed 's/OWNER TO wss;/OWNER TO prod_owner_that_does_not_exist;/' |
    awk 'NR == 1 { print; print "\\restrict abc123"; next } { print }' | gzip > "$dir/db-backups/wss_20261027_090000.sql.gz"
  psql -X -q -d "$db" -c "DELETE FROM users WHERE id = 3"
  pg_dump "$db" | gzip > "$dir/db-backups/wss_20261026_090000.sql.gz"
  psql -X -q -d postgres -c "DROP DATABASE $db"
}

echo "bin/relaunch-production tests"

# ---------------------------------------------------------------- help
new_world help
run_wizard "" --help
check "--help lists all ten steps" sh -c "[ $RC = 0 ] && grep -q 'preflight' '$OUT' && grep -q 'aftercare' '$OUT' && grep -q -- '--from' '$OUT'"

# ---------------------------------------------------------------- preflight
new_world missing
write_env "$W/env" R2_BUCKET STRIPE_WEBHOOK_SECRET
run_wizard "" --only preflight
check "missing env vars: stops" test "$RC" = 1
check "missing env vars: named" sh -c "grep -q 'R2_BUCKET' '$OUT' && grep -q 'STRIPE_WEBHOOK_SECRET' '$OUT'"
check "missing env vars: nothing else named as missing" sh -c "! grep 'missing values' '$OUT' | grep -q 'R2_ENDPOINT'"

new_world mode
chmod 644 "$W/env"
run_wizard "" --only preflight
check "env file readable by others: refused" sh -c "[ $RC = 1 ] && grep -q 'chmod 600' '$OUT'"

new_world dirty
echo change >> "$W/repo/config/deploy.yml"
run_wizard "" --only preflight
check "uncommitted changes: refused" sh -c "[ $RC = 1 ] && grep -q 'uncommitted' '$OUT'"

new_world docker
export WSS_STUB_DOCKER_INFO_RC=1
run_wizard "" --only preflight
check "Docker not running: refused" sh -c "[ $RC = 1 ] && grep -q 'Docker Desktop is not running' '$OUT'"

new_world gh
export WSS_STUB_GH_AUTH_RC=1
run_wizard "" --only preflight
check "gh missing: warning only" sh -c "[ $RC = 0 ] && grep -q 'gh (the GitHub' '$OUT'"

# ---------------------------------------------------------------- server
new_world root
export WSS_STUB_ROOT=1
run_wizard "$NEW_IP
" --only server
check "root login works: no ubuntu fallback" sh -c "[ $RC = 0 ] && ! grep -q 'enable-root' '$W/calls' && grep -q 'logged in as root' '$OUT'"
check "IP remembered in the state file" grep -q "ip=$NEW_IP" "$W/state"

new_world ubuntu
export WSS_STUB_ROOT=0 WSS_STUB_UBUNTU=1
run_wizard "$NEW_IP
y
" --only server
check "ubuntu only: root enabled through ubuntu, then root works" sh -c "[ $RC = 0 ] && grep -q 'ssh:enable-root ssh ubuntu@' '$W/calls' && grep -q 'root login works' '$OUT'"

new_world nologin
export WSS_STUB_ROOT=0 WSS_STUB_UBUNTU=0
run_wizard "$NEW_IP
" --only server
check "no login at all: stops with ssh-copy-id fix" sh -c "[ $RC = 1 ] && grep -q 'ssh-copy-id ubuntu@$NEW_IP' '$OUT'"

new_world badip
export WSS_STUB_ROOT=1
run_wizard "not-an-ip
999.1.1.1
$NEW_IP
" --only server
check "bad IPs are asked again" sh -c "[ $RC = 0 ] && [ \$(grep -c 'not an IPv4' '$OUT') = 2 ]"

new_world swap
export WSS_STUB_SSH_FACTS="os=ubuntu 24.04
mem_kb=7950000
disk_kb=70000000
swaps=0
ufw=yes
ufw_active=no
ufw_rules="
run_wizard "$NEW_IP
" --only server
check "no swap, inactive firewall: both set up" sh -c "[ $RC = 0 ] && grep -q 'ssh:swap' '$W/calls' && grep -q 'ssh:ufw' '$W/calls'"

new_world oldip
run_wizard "178.156.251.37
y
" --only server
check "reusing the old IP clears its known_hosts entry" grep -q "ssh-keygen -R 178.156.251.37" "$W/calls"

# ---------------------------------------------------------------- config
new_world config
run_wizard "$NEW_IP
y
y
" --only config
check "config: IP replaced in all places, none of the old left" sh -c "[ $RC = 0 ] && [ \$(grep -c '$NEW_IP' '$W/repo/config/deploy.yml') -ge 3 ] && ! grep -q 178.156.251.37 '$W/repo/config/deploy.yml'"
check "config: the Postgres binding stays on 127.0.0.1" grep -qF '"127.0.0.1:5432:5432"' "$W/repo/config/deploy.yml"
check "config: committed and pushed" sh -c "git -C '$W/repo' diff --quiet HEAD && [ \$(git -C '$W/repo' rev-list --count @{u}..HEAD) = 0 ] && git -C '$W/repo' log -1 --format=%s | grep -q '$NEW_IP'"
run_wizard "" --only config
check "config: second run detects it is done" sh -c "[ $RC = 0 ] && grep -q 'already uses $NEW_IP' '$OUT'"

new_world config-no
run_wizard "$NEW_IP
n
" --only config
check "config: declining leaves the file untouched" sh -c "[ $RC = 1 ] && git -C '$W/repo' diff --quiet && grep -q 178.156.251.37 '$W/repo/config/deploy.yml'"

# ---------------------------------------------------------------- masterkey
if ruby -e 'require "active_support"; require "active_support/encrypted_configuration"' 2>/dev/null; then
  new_world key
  export WSS_STUB_RUBY=local WSS_STUB_MISSING_CMDS="security"
  run_wizard "y
n
" --only masterkey
  check "masterkey: lost key regenerated" sh -c "[ $RC = 0 ] && [ -f '$W/repo/config/master.key' ] && grep -q 'opens the new credentials' '$OUT'"
  check "masterkey: key is private and never tracked" sh -c "ls -l '$W/repo/config/master.key' | grep -q '^-rw-------' && ! git -C '$W/repo' ls-files | grep -q master.key"
  check "masterkey: new credentials.yml.enc committed" sh -c "git -C '$W/repo' diff --quiet HEAD && git -C '$W/repo' log -1 --format=%s | grep -q 'Regenerate Rails credentials'"
  check "masterkey: the key never appears in output" sh -c "! grep -qF \"\$(cat '$W/repo/config/master.key')\" '$OUT'"
  run_wizard "y
" --only masterkey
  check "masterkey: unpushed commit is offered for push" grep -q "not on GitHub yet" "$OUT"
  check "masterkey: second run detects a working key" sh -c "[ $RC = 0 ] && grep -q 'opens config/credentials.yml.enc' '$OUT'"
else
  skip "masterkey (ruby with activesupport not available)"
fi

# ---------------------------------------------------------------- database (stubbed)
new_world dbstub
mkdir -p "$HOME/Documents/wss/tmp/r2-backup/db-backups"
echo x | gzip > "$HOME/Documents/wss/tmp/r2-backup/db-backups/wss_20261027_090000.sql.gz"
export WSS_STUB_PSQL_TABLES=45 WSS_STUB_PSQL_COUNTS="users	120"
run_wizard "$NEW_IP
yes
" --only database
check "non-empty database: kept without the exact phrase" sh -c "[ $RC = 0 ] && grep -q 'kept the existing database' '$OUT' && ! grep -q 'psql:load' '$W/calls' && ! grep -q 'scp:' '$W/calls' && ! grep -q 'psql:recreate' '$W/calls'"

new_world dbboot
export WSS_STUB_SSH_DOCKER_PRESENT="no" WSS_STUB_SSH_DB_RUNNING="stopped" WSS_STUB_PSQL_TABLES=45
run_wizard "$NEW_IP

" --only database
check "Docker missing on the server: bootstrap, then the db accessory alone" sh -c "grep -q 'kamal:bootstrap kamal server bootstrap' '$W/calls' && grep -q 'kamal:accessory-boot kamal accessory boot db' '$W/calls' && ! grep -q 'kamal:setup' '$W/calls'"
check "kamal gets the env file (names only in the log)" grep -q "env: KAMAL_REGISTRY_PASSWORD" "$W/calls"

# ---------------------------------------------------------------- database (real Postgres)
if psql -X -q -d postgres -c 'select 1' >/dev/null 2>&1; then
  new_world dbreal
  BUCKET="$HOME/Documents/WSS-R2-backup-2026-11-21"
  if make_bucket "$BUCKET"; then
    export WSS_STUB_PSQL=local WSS_TEST_DB="relaunch_test_target_$$" WSS_STUB_SERVER_DIR="$W/server"
    mkdir -p "$WSS_STUB_SERVER_DIR"
    psql -X -q -d postgres -c "DROP DATABASE IF EXISTS $WSS_TEST_DB" -c "CREATE DATABASE $WSS_TEST_DB"

    # The second-known folder is found by default; pick the older dump (2).
    run_wizard "$NEW_IP

2
" --only database
    check "real load: older dump picked and loaded" sh -c "[ $RC = 0 ] && grep -q 'psql:load relaunch-wss_20261026_090000.sql.gz' '$W/calls'"
    check "real load: row counts printed" sh -c "grep -qE 'users +2' '$OUT' && grep -qE 'presentations +2' '$OUT' && grep -qE 'user_presentations +1' '$OUT' && grep -qE 'credit_transactions +2' '$OUT'"
    check "real load: ledger check ran" grep -q "every credit balance matches the ledger" "$OUT"
    check "real load: copy removed from the server afterwards" grep -q "ssh:cleanup" "$W/calls"

    # Now non-empty: replace it with the newest, which has foreign owners and \restrict.
    run_wizard "$NEW_IP
REPLACE PRODUCTION DATA

1
" --only database
    check "real load: phrase replaces the data with the newest dump" sh -c "[ $RC = 0 ] && grep -qE 'users +3' '$OUT' && grep -q 'kamal:app-stop' '$W/calls'"
    check "real load: foreign ownership lines skipped" grep -qE "skipped [1-9][0-9]* ownership" "$OUT"
    check "real load: tables owned by the local role" test "$(psql -X -At -d "$WSS_TEST_DB" -c "select count(*) from pg_tables where schemaname='public' and tableowner <> current_user")" = 0

    # A broken dump: every psql error is fatal and the load is one transaction.
    gunzip -c "$BUCKET/db-backups/wss_20261027_090000.sql.gz" | sed 's/^CREATE TABLE public.filler_9 /CREATE TABLEX public.filler_9 /' | gzip > "$BUCKET/db-backups/wss_20261028_090000.sql.gz"
    run_wizard "$NEW_IP
REPLACE PRODUCTION DATA

1
" --only database
    check "real load: an error stops the run" sh -c "[ $RC = 1 ] && grep -q 'loading the dump failed' '$OUT'"
    check "real load: nothing half-loaded" test "$(psql -X -At -d "$WSS_TEST_DB" -c "select count(*) from information_schema.tables where table_schema='public'")" = 0
    psql -X -q -d postgres -c "DROP DATABASE IF EXISTS $WSS_TEST_DB"
  else
    skip "real database load (could not build the fixture dumps)"
  fi
else
  skip "real database load (no local Postgres at $PGHOST)"
fi

# ---------------------------------------------------------------- deploy
new_world deployfail
export WSS_STUB_SSH_APP_UP="000" WSS_STUB_KAMAL_SETUP_RC=1 WSS_STUB_KAMAL_LOGS="boot failed: password=FAKESECRETsmtppassword9q at sk_live_FAKESECRETstripe123"
run_wizard "$NEW_IP
" --only deploy
check "deploy failure: stops and shows the masked log" sh -c "[ $RC = 1 ] && grep -q 'kamal setup failed' '$OUT' && grep -q 'MASKED' '$OUT'"

new_world deployed
run_wizard "$NEW_IP
" --only deploy
check "deploy: app already answering is detected, no setup" sh -c "[ $RC = 0 ] && ! grep -q 'kamal:setup' '$W/calls'"

# ---------------------------------------------------------------- purge
HISTO="89 unused accounts match.
Created per day:
  2026-08-03    40
  2026-10-14    49
user 5, created 2026-08-03
Dry run: nothing deleted. Run again with CONFIRM=1 to delete these accounts."
new_world purge
export WSS_STUB_KAMAL_PURGE_DRY="$HISTO"
run_wizard "$NEW_IP
yes
" --only purge
check "purge: histogram shown, wrong phrase deletes nothing" sh -c "[ $RC = 0 ] && grep -q '2026-08-03    40' '$OUT' && ! grep -q 'CONFIRM=1' '$W/calls'"
check "purge: dry run runs once, on the web role" grep -q 'kamal:purge-dry kamal app exec --roles=web --reuse bin/rails users:purge_unused' "$W/calls"

new_world purge-ok
export WSS_STUB_KAMAL_PURGE_DRY="$HISTO" WSS_STUB_KAMAL_PURGE="Deleted 89 unused accounts; skipped 0."
run_wizard "$NEW_IP
DELETE 89 ACCOUNTS
" --only purge
check "purge: typed phrase runs CONFIRM=1" sh -c "[ $RC = 0 ] && grep -q 'env CONFIRM=1 bin/rails users:purge_unused' '$W/calls'"

new_world purge-odd
WSS_STUB_KAMAL_PURGE_DRY="$(printf '%s\n' "$HISTO" | sed 's/^89 /900 /')"; export WSS_STUB_KAMAL_PURGE_DRY
run_wizard "$NEW_IP

" --only purge
check "purge: a count far from 89 is flagged" grep -q "recommend NOT deleting" "$OUT"

# ---------------------------------------------------------------- turnstile
new_world turnstile
export WSS_STUB_RUBY_TURNSTILE="wss-turnstile on"
run_wizard "$NEW_IP
y
$TURNSTILE_SITE
$TURNSTILE_SECRET
" --only turnstile
check "turnstile: keys saved, app rebooted" sh -c "[ $RC = 0 ] && grep -q \"^export TURNSTILE_SITE_KEY='$TURNSTILE_SITE'\" '$W/env' && grep -q \"^export TURNSTILE_SECRET_KEY='$TURNSTILE_SECRET'\" '$W/env' && grep -q 'kamal:app-boot kamal app boot' '$W/calls'"
check "turnstile: env file still private" sh -c "ls -l '$W/env' | grep -q '^-rw-------'"
check "turnstile: Kamal saw both keys (by name)" grep -q "TURNSTILE_SITE_KEY TURNSTILE_SECRET_KEY" "$W/calls"

new_world turnstile-skip
run_wizard "$NEW_IP
n
" --only turnstile
check "turnstile: skip warns and is remembered" sh -c "[ $RC = 0 ] && grep -q 'SKIPPED: sign-up has NO human check' '$OUT' && grep -q 'turnstile=skipped' '$W/state'"

# ---------------------------------------------------------------- --from and the full run
new_world from
run_wizard "$NEW_IP

" --from dns
check "--from dns: earlier steps not run" sh -c "[ $RC = 0 ] && ! grep -qE 'kamal:(setup|purge|bootstrap)|ssh:facts' '$W/calls' && grep -q 'Step 9 of 10' '$OUT' && grep -q 'Step 10 of 10' '$OUT'"

new_world full
export WSS_STUB_DOCKER_RUBY="wss-cred ok" WSS_STUB_KAMAL_PURGE_DRY="0 unused accounts match." WSS_STUB_RUBY_TURNSTILE="wss-turnstile on"
export WSS_STUB_RUBY_RECURRING="wss-recurring every day at 9am" WSS_STUB_PSQL_TABLES=45
write_env "$W/env"; printf "export TURNSTILE_SITE_KEY='%s'\nexport TURNSTILE_SECRET_KEY='%s'\n" "$TURNSTILE_SITE" "$TURNSTILE_SECRET" >> "$W/env"
( cd "$W/repo" && sed "s/178\.156\.251\.37/$NEW_IP/g" config/deploy.yml > d && mv d config/deploy.yml && git commit -qam ip && git push -q )
run_wizard "


"
check "full run on a finished relaunch: every step reports done" sh -c "[ $RC = 0 ] && grep -q 'Done.' '$OUT' && ! grep -qE 'kamal:(setup|app-boot|purge )|scp:|ssh:enable-root' '$W/calls'"

# ---------------------------------------------------------------- dry run
new_world dry
export WSS_STUB_SSH_APP_UP="000" WSS_STUB_SSH_DOCKER_PRESENT="no" WSS_STUB_CURL_DNS_UP="000" WSS_STUB_KAMAL_PURGE_DRY="$HISTO"
export WSS_STUB_DOCKER_RUBY="wss-cred no-key" WSS_STUB_ROOT=0 WSS_STUB_UBUNTU=1
export WSS_STUB_SSH_FACTS="os=ubuntu 24.04
mem_kb=7950000
disk_kb=70000000
swaps=0
ufw=yes
ufw_active=no
ufw_rules="
before_yml="$(cksum < "$W/repo/config/deploy.yml")"; before_env="$(cksum < "$W/env")"; before_head="$(git -C "$W/repo" rev-parse HEAD)"
run_wizard "$NEW_IP
" --dry-run
check "dry run: finishes" test "$RC" = 0
check "dry run: plans printed" sh -c "[ \$(grep -c 'would:' '$OUT') -ge 5 ]"
check "dry run: no changing call made" sh -c "! grep -qE 'kamal:(setup|bootstrap|accessory-boot|app-boot|purge |app-stop)|scp:|ssh:(enable-root|swap|ufw|mkdir)|psql:(load|recreate)|ssh-keygen' '$W/calls'"
check "dry run: files and commits unchanged, no state written" sh -c "[ '$before_yml' = \"\$(cksum < '$W/repo/config/deploy.yml')\" ] && [ '$before_env' = \"\$(cksum < '$W/env')\" ] && [ '$before_head' = \"\$(git -C '$W/repo' rev-parse HEAD)\" ] && [ ! -f '$W/state' ]"

# ---------------------------------------------------------------- secrets
leaks=""
for v in $ALL_FAKE_VALUES; do
  if grep -rqF -- "$v" "$T"/out.* "$T"/calls.* "$T"/w*/state 2>/dev/null; then leaks="$leaks $v"; fi
done
check "no secret value appears in any output, call log or state file" test -z "$leaks"
[ -z "$leaks" ] || echo "    leaked:$leaks"

echo
echo "$PASSES passed, $FAILS failed, $SKIPS skipped"
[ "$FAILS" = 0 ]
