#!/usr/bin/env bash
set -euo pipefail
: "${TA:?}" "${GA:?}"
BASE=http://127.0.0.1:5080
HIST=$(curl -fsS -X POST "$BASE/api/v1/clients" -H "Authorization: Bearer $TA" -H 'Content-Type: application/json' -d '{"name":"Cliente Histórico","phone":"27999990103"}')
HIST_ID=$(echo "$HIST" | jq -r .id)
USER_A=$(psql -h localhost -U bck -d bck_agenda -Atc "SELECT id FROM bck_user WHERE group_id='$GA' AND is_owner=true LIMIT 1")
SERVICE_A=$(curl -fsS -X POST "$BASE/api/v1/services" -H "Authorization: Bearer $TA" -H 'Content-Type: application/json' -d '{"groupId":"00000000-0000-0000-0000-000000000000","name":"Corte EP04","standardPrice":50,"standardDurationMinutes":30}' | jq -r .id)
START=$(date -u -d '+2 days' '+%Y-%m-%dT%H:%M:%SZ')
APPT=$(jq -nc --arg p "$USER_A" --arg c "$HIST_ID" --arg s "$SERVICE_A" --arg t "$START" '{groupId:"00000000-0000-0000-0000-000000000000",professionalUserId:$p,createdByUserId:$p,clientId:$c,walkInName:null,walkInPhone:null,startsAt:$t,durationMinutes:30,serviceId:$s,isFitIn:false,notes:"histórico EP04",forceConflict:false}')
curl -fsS -X POST "$BASE/api/v1/appointments" -H "Authorization: Bearer $TA" -H 'Content-Type: application/json' -d "$APPT" >/dev/null
DELETE_BODY=$(mktemp)
test "$(curl -s -o "$DELETE_BODY" -w '%{http_code}' -X DELETE "$BASE/api/v1/clients/$HIST_ID" -H "Authorization: Bearer $TA")" = 200
test "$(jq -r .result "$DELETE_BODY")" = INACTIVATED
INACTIVE=$(curl -fsS "$BASE/api/v1/clients/$HIST_ID" -H "Authorization: Bearer $TA")
test "$(echo "$INACTIVE" | jq -r .active)" = false
OLD_VERSION=$(echo "$INACTIVE" | jq -r .version)
ACTIVE_LIST=$(curl -fsS "$BASE/api/v1/clients" -H "Authorization: Bearer $TA")
test "$(echo "$ACTIVE_LIST" | jq --arg id "$HIST_ID" '[.[]|select(.id==$id)]|length')" = 0
ALL_LIST=$(curl -fsS "$BASE/api/v1/clients?includeInactive=true" -H "Authorization: Bearer $TA")
test "$(echo "$ALL_LIST" | jq --arg id "$HIST_ID" '[.[]|select(.id==$id and .active==false)]|length')" = 1
HISTORY=$(curl -fsS "$BASE/api/v1/clients/$HIST_ID/history" -H "Authorization: Bearer $TA")
test "$(echo "$HISTORY" | jq 'length')" -ge 1
test "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/clients/$HIST_ID/reactivate" -H "Authorization: Bearer $TA")" = 204
REACTIVE=$(curl -fsS "$BASE/api/v1/clients/$HIST_ID" -H "Authorization: Bearer $TA")
test "$(echo "$REACTIVE" | jq -r .active)" = true
test "$(echo "$REACTIVE" | jq -r .version)" -gt "$OLD_VERSION"
