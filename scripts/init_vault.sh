#!/usr/bin/env bash
# Crée ansible/vars/vault.yml avec des mots de passe Redis aléatoires et le CHIFFRE avec Ansible Vault.
# Le mot de passe Vault est rangé HORS du dépôt : ~/.vault_pass_legeni (à déposer dans Jenkins
# comme credential « ansible-vault-pass », type Secret file).
#   bash scripts/init_vault.sh
set -euo pipefail
cd "$(dirname "$0")/../ansible"
PASS="$HOME/.vault_pass_legeni"
if [ ! -f "$PASS" ]; then
  openssl rand -base64 24 > "$PASS" && chmod 600 "$PASS"
  echo "✅ Mot de passe Vault créé : $PASS (ne jamais le commiter)"
fi
if [ -f vars/vault.yml ] && head -1 vars/vault.yml | grep -q ANSIBLE_VAULT; then
  echo "vars/vault.yml est déjà chiffré :"; head -1 vars/vault.yml; exit 0
fi
printf -- '---\nredis_password_staging: "%s"\nredis_password_prod: "%s"\n' "$(openssl rand -hex 16)" "$(openssl rand -hex 16)" > vars/vault.yml
ansible-vault encrypt vars/vault.yml --vault-password-file "$PASS"
head -1 vars/vault.yml
echo "✅ vars/vault.yml chiffré (il peut être commité). Lecture : ansible-vault view vars/vault.yml --vault-password-file $PASS"
