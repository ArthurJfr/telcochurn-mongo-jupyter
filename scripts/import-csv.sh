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
  echo "Erreur: fichier CSV manquant."
  echo "Usage: FILE=./data/users.csv COLLECTION=users DB=app_db ./scripts/import-csv.sh"
  exit 1
fi

if [[ -z "${COLLECTION}" ]]; then
  echo "Erreur: collection manquante."
  echo "Ajoute COLLECTION=<nom> ou passe-la en 2e argument."
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

if [[ "${FILE##*.}" != "csv" ]]; then
  echo "Erreur: le fichier doit avoir l'extension .csv"
  exit 1
fi

if [[ "${DROP_FIRST}" != "true" && "${DROP_FIRST}" != "false" ]]; then
  echo "Erreur: DROP_FIRST doit valoir true ou false."
  exit 1
fi

ABS_FILE="$(cd "$(dirname "${FILE}")" && pwd)/$(basename "${FILE}")"
CSV_DIR="$(dirname "${ABS_FILE}")"
CSV_NAME="$(basename "${ABS_FILE}")"

URI="mongodb://${MONGO_ROOT_USERNAME:-admin}:${MONGO_ROOT_PASSWORD:-admin123}@host.docker.internal:${MONGO_PORT:-27017}/?authSource=admin"

echo "Import CSV vers MongoDB..."
echo "- FILE: ${ABS_FILE}"
echo "- DB: ${DB}"
echo "- COLLECTION: ${COLLECTION}"
echo "- DROP_FIRST: ${DROP_FIRST}"

if [[ "${DROP_FIRST}" == "true" ]]; then
  docker run --rm \
    -v "${CSV_DIR}:/work" \
    mongo:7 \
    mongoimport \
    --uri="${URI}" \
    --db="${DB}" \
    --collection="${COLLECTION}" \
    --type=csv \
    --headerline \
    --drop \
    --file="/work/${CSV_NAME}"
else
  docker run --rm \
    -v "${CSV_DIR}:/work" \
    mongo:7 \
    mongoimport \
    --uri="${URI}" \
    --db="${DB}" \
    --collection="${COLLECTION}" \
    --type=csv \
    --headerline \
    --file="/work/${CSV_NAME}"
fi

echo "Import termine."
