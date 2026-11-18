#!/usr/bin/env bash
# Bonus HPA : génère de la charge sur la production et affiche la montée du nombre de réplicas.
kubectl -n legeni-prod delete pod charge --ignore-not-found >/dev/null
kubectl -n legeni-prod run charge --image=busybox:1.36 --restart=Never -- \
  sh -c 'while true; do wget -q -O- http://webapp/ >/dev/null; done'
echo "Charge lancée. Observation (Ctrl+C pour arrêter) :"
trap 'kubectl -n legeni-prod delete pod charge --wait=false; exit 0' INT
kubectl -n legeni-prod get hpa webapp -w
