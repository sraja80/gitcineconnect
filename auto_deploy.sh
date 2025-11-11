#!/usr/bin/env bash
set -euo pipefail

# auto_deploy.sh
# Usage: run from repository root (where files are already present)
# Prereqs: you must be logged in to:
#   gh (GitHub CLI) -> gh auth login
#   vercel (optional) -> vercel login
#   supabase (optional) -> supabase login
#
# The script will:
# - initialize git (if not already)
# - create repo sraja80/gitcineconnect via gh
# - push main and demo/preview branches
# - create PR demo/preview -> main
#
# NOTE: This script does NOT set Vercel / Supabase env secrets. See manual steps below.

REPO_OWNER="${1:-sraja80}"
REPO_NAME="${2:-gitcineconnect}"
REMOTE="origin"
MAIN_BRANCH="main"
DEMO_BRANCH="demo/preview"
PR_TITLE="feat: initial CineConnect PoC — demo/preview"
PR_BODY="Initial PoC push: CineConnect (web + mobile + Supabase schema + functions + payment stubs)."

echo "Repo will be: ${REPO_OWNER}/${REPO_NAME}"
read -p "Proceed? (y/N): " confirm
if [[ "${confirm,,}" != "y" ]]; then
  echo "Aborted by user."
  exit 1
fi

# check CLI tools
for cmd in git gh; do
  if ! command -v $cmd >/dev/null 2>&1; then
    echo "ERROR: '$cmd' required. Install and authenticate before running this script."
    exit 2
  fi
done

# Ensure there's a git repo and commit
if [ ! -d .git ]; then
  git init
  echo "Initialized new git repository."
fi

git add --all
if git rev-parse --verify HEAD >/dev/null 2>&1; then
  git commit -m "chore: update files before deploy" || true
else
  git commit -m "$PR_TITLE" || true
fi

# Create repo on GitHub (if not exists)
if gh repo view "${REPO_OWNER}/${REPO_NAME}" >/dev/null 2>&1; then
  echo "GitHub repo ${REPO_OWNER}/${REPO_NAME} already exists."
else
  echo "Creating GitHub repo ${REPO_OWNER}/${REPO_NAME} (private)..."
  gh repo create "${REPO_OWNER}/${REPO_NAME}" --private --source=. --remote="${REMOTE}" --push
fi

# Ensure main branch exists locally and remotely
git branch -M "${MAIN_BRANCH}"
git push -u "${REMOTE}" "${MAIN_BRANCH}"

# Create demo branch and push
if git show-ref --verify --quiet "refs/heads/${DEMO_BRANCH}"; then
  echo "Branch ${DEMO_BRANCH} exists locally."
else
  git checkout -b "${DEMO_BRANCH}"
fi
git push -u "${REMOTE}" "${DEMO_BRANCH}"

# Create PR
echo "Creating PR ${DEMO_BRANCH} -> ${MAIN_BRANCH}..."
# gh pr create requires head and base; if a PR already exists, skip
EXIST_PR=$(gh pr list --repo "${REPO_OWNER}/${REPO_NAME}" --head "${DEMO_BRANCH}" --base "${MAIN_BRANCH}" --json number --jq '.[0].number' || true)
if [ -n "$EXIST_PR" ]; then
  echo "PR already exists: #$EXIST_PR"
else
  gh pr create --repo "${REPO_OWNER}/${REPO_NAME}" --title "${PR_TITLE}" --body "${PR_BODY}" --head "${DEMO_BRANCH}" --base "${MAIN_BRANCH}"
fi

echo ""
echo "DONE: Repository pushed and PR created (if not pre-existing)."
echo ""
echo "NEXT STEPS (manual):"
echo "1) Vercel: login locally (vercel login) and import the repo or run 'vercel' from this folder."
echo "   - In Vercel Dashboard, set environment variables from .env.example for PROD and Preview."
echo "   - Mark SUPABASE_SERVICE_ROLE_KEY, STRIPE_* and RAZORPAY_* as secret environment variables."
echo ""
echo "2) Supabase: deploy schema & RLS (two options):"
echo "   Option A (Supabase SQL editor): Open Supabase project -> SQL editor -> run supabase/schema.sql and supabase/rls_policies.sql"
echo "   Option B (supabase CLI):"
echo "      supabase login"
echo "      supabase link --project-ref <PROJECT_REF>"
echo "      supabase sql query --file supabase/schema.sql --project-ref <PROJECT_REF>"
echo "      supabase sql query --file supabase/rls_policies.sql --project-ref <PROJECT_REF>"
echo "      supabase functions deploy generate_hls_signed_url --project-ref <PROJECT_REF>  (requires supabase CLI functions support)"
echo ""
echo "3) Buckets: create Storage buckets in Supabase: 'showreels' and 'kyc', and upload demo HLS files if any."
echo ""
echo "4) Seed demo data: run the seed SQL snippet in the Supabase SQL editor (see README/seed_demo.sql)."
echo ""
echo "If you want, after you run this script and complete steps 1–3, paste the Vercel preview URL here and I will walk you through testing flows."