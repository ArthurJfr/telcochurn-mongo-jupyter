#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${PROJECT_DIR}/.env"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
fi

FILE="${FILE:-${1:-}}"
DB="${DB:-${MONGO_DEFAULT_DB:-}}"
COLLECTION="${COLLECTION:-${2:-}}"
DROP_FIRST="${DROP_FIRST:-false}"

if [[ -z "${FILE}" ]]; then
  echo "Erreur: fichier manquant."
  echo "Usage: FILE=./data/users.csv COLLECTION=users DB=app_db ./scripts/import-csv.sh"
  echo "Formats supportes: .csv, .json, .jsonl, .ndjson"
  exit 1
fi

if [[ -z "${DB}" ]]; then
  echo "Erreur: base de données manquante (DB)."
  exit 1
fi

if [[ ! -f "${FILE}" ]]; then
  echo "Erreur: fichier introuvable: ${FILE}"
  exit 1
fi

if [[ "${DROP_FIRST}" != "true" && "${DROP_FIRST}" != "false" ]]; then
  echo "Erreur: DROP_FIRST doit valoir true ou false."
  exit 1
fi

ABS_FILE="$(cd "$(dirname "${FILE}")" && pwd)/$(basename "${FILE}")"
FILE_DIR="$(dirname "${ABS_FILE}")"
FILE_NAME="$(basename "${ABS_FILE}")"
EXT="${FILE_NAME##*.}"
EXT_LOWER="$(printf '%s' "${EXT}" | tr '[:upper:]' '[:lower:]')"
BASE_NAME="${FILE_NAME%.*}"

if [[ -z "${COLLECTION}" ]]; then
  COLLECTION="$(printf '%s' "${BASE_NAME}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//')"
fi

if [[ -z "${COLLECTION}" ]]; then
  echo "Erreur: impossible de deduire un nom de collection a partir du fichier."
  echo "Ajoute COLLECTION=<nom>."
  exit 1
fi

MONGOIMPORT_ARGS=()
case "${EXT_LOWER}" in
  csv)
    MONGOIMPORT_ARGS+=(--type=csv --headerline)
    ;;
  json)
    MONGOIMPORT_ARGS+=(--type=json --jsonArray)
    ;;
  jsonl|ndjson)
    MONGOIMPORT_ARGS+=(--type=json)
    ;;
  *)
    echo "Erreur: extension non supportee: .${EXT_LOWER}"
    echo "Formats supportes: .csv, .json, .jsonl, .ndjson"
    exit 1
    ;;
esac

URI="mongodb://${MONGO_ROOT_USERNAME:-admin}:${MONGO_ROOT_PASSWORD:-admin123}@host.docker.internal:${MONGO_PORT:-27017}/?authSource=admin"

echo "Import fichier vers MongoDB..."
echo "- FILE: ${ABS_FILE}"
echo "- TYPE: ${EXT_LOWER}"
echo "- DB: ${DB}"
echo "- COLLECTION: ${COLLECTION}"
echo "- DROP_FIRST: ${DROP_FIRST}"

if [[ "${DROP_FIRST}" == "true" ]]; then
  docker run --rm \
    -v "${FILE_DIR}:/work" \
    mongo:7 \
    mongoimport \
    --uri="${URI}" \
    --db="${DB}" \
    --collection="${COLLECTION}" \
    --drop \
    "${MONGOIMPORT_ARGS[@]}" \
    --file="/work/${FILE_NAME}"
else
  docker run --rm \
    -v "${FILE_DIR}:/work" \
    mongo:7 \
    mongoimport \
    --uri="${URI}" \
    --db="${DB}" \
    --collection="${COLLECTION}" \
    "${MONGOIMPORT_ARGS[@]}" \
    --file="/work/${FILE_NAME}"
fi

echo "Import termine."
