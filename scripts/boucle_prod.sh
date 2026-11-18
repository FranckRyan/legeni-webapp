#!/usr/bin/env bash
# Soutenance – scénario 1 : interroge la production toutes les 0,5 s pendant la mise à jour
# et compte les erreurs (attendu : 0). Ctrl+C pour arrêter et afficher le bilan.
#   bash scripts/boucle_prod.sh            (prod)   |   bash scripts/boucle_prod.sh staging
ENV=${1:-prod}
PORT=$([ "$ENV" = prod ] && echo 30082 || echo 30081)
URL="http://$(minikube ip):$PORT/api/info"
OK=0; KO=0
trap 'echo; echo "Bilan : $OK réponses OK, $KO erreurs"; exit 0' INT
echo "Boucle sur $URL"
while true; do
  if r=$(curl -sf -m 2 "$URL"); then OK=$((OK+1)); echo "$(date +%T) $r"
  else KO=$((KO+1)); echo "$(date +%T) ❌ ERREUR"; fi
  sleep 0.5
done
