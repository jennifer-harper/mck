#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# ==========================================
# CONFIGURATION
# ==========================================
SSH_USER="mck"
SSH_HOST="deploy.eu2.frbit.com"
REMOTE_PATH="/srv/app/mck/htdocs"

# Relative path from Craft root to your local uploaded assets folder
# Update this if your assets folder is named differently (e.g., "public/uploads" or "web/assets")
REMOTE_ASSETS_PATH="web/uploads/images"
LOCAL_ASSETS_PATH="web/uploads/images"

LOCAL_DUMP_FILE="storage/prod-dump.sql"
LOCAL_PRE_SYNC_FILE="storage/local-pre-sync-backup.sql"

# ==========================================
# SYNC PROCESS
# ==========================================

echo "🚀 Starting Production -> Local Full Sync..."

# 1. Trigger remote Craft 5 DB backup with explicit output path
echo "📦 1. Triggering remote Craft DB backup on Production..."
ssh "${SSH_USER}@${SSH_HOST}" "cd ${REMOTE_PATH} && php craft db/backup storage/backups/prod-dump.sql --overwrite"

# 2. Safety backup of local DDEV DB
echo "💾 2. Creating safety backup of current LOCAL database..."
ddev export-db --file="${LOCAL_PRE_SYNC_FILE}" --gzip=false

# 3. Download the dump from Production
echo "📥 3. Downloading database dump..."
scp "${SSH_USER}@${SSH_HOST}:${REMOTE_PATH}/storage/backups/prod-dump.sql" "${LOCAL_DUMP_FILE}"

# 4. Import the Production database into local DDEV
echo "🗄️ 4. Importing Production database into local DDEV..."
ddev import-db --file="${LOCAL_DUMP_FILE}"

# 5. Clean up temporary download file locally
echo "🧹 5. Cleaning up local download dump..."
rm -f "${LOCAL_DUMP_FILE}"

# 6. Download uploaded Assets / Images
echo "🖼️ 6. Syncing remote assets to local environment..."
mkdir -p "${LOCAL_ASSETS_PATH}"
rsync -avz --progress "${SSH_USER}@${SSH_HOST}:${REMOTE_PATH}/${REMOTE_ASSETS_PATH}/" "${LOCAL_ASSETS_PATH}/"

# 7. OVERWRITE local YAML files with the schema from the freshly imported Prod DB
echo "🔄 7. Exporting Production Project Config schema to local YAML files..."
ddev exec php craft project-config/write

# 8. Apply migrations/project-config to verify local integrity
echo "⚙️ 8. Running Craft up locally..."
ddev exec php craft up --interactive=0

echo "🎉 Full Sync (DB + Assets) complete!"