# Legeni WebApp – chaîne CI/CD complète

Projet final DevOps B3 – CHAMEN NKONGMENECK Franck Ryan.
Application Flask + Redis testée, empaquetée, publiée et déployée automatiquement en *staging* puis en *production* sur Kubernetes (Minikube), du `git push` à la production.

```
git push ──▶ GitHub ──webhook──▶ Jenkins (multibranch)
                                   ├─ qualité en parallèle : pytest + couverture ≥ 80 %, flake8, hadolint, syntaxe Ansible
                                   ├─ build image franckryan/legeni-webapp:<VERSION>-<build>
                                   ├─ scan Trivy (0 CRITICAL corrigeable)
                                   └─ main uniquement : push Docker Hub → Ansible deploy.yml staging
                                                        → validation humaine → Ansible deploy.yml prod → tag v<VERSION>
```

| Dossier / fichier | Rôle | Lot |
|---|---|---|
| `Dockerfile`, `.dockerignore` | image multi-stage (test → runtime), non-root, HEALTHCHECK | 1 |
| `VERSION` | version sémantique de l'application | 0 / 1 |
| `ansible/provision.yml` + `roles/docker, reseau, minikube, jenkins` | installe toute l'infrastructure sur une machine Ubuntu vierge | 2 |
| `ansible/deploy.yml` + `templates/k8s/` + `vars/` | déploiement Kubernetes staging / prod, rollback automatique | 3 |
| `ansible/vars/vault.yml` | mots de passe Redis, **chiffrés** avec Ansible Vault | 2 |
| `Jenkinsfile` | pipeline CI/CD | 4 / 5 |
| `scripts/` | création du Vault, boucle `curl` de la soutenance, charge HPA | – |
| `docs/rapport.md` | rapport final | – |

## Démarrage rapide

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook provision.yml -K                 # Docker, réseau, Minikube, Jenkins
bash ../scripts/init_vault.sh                     # secrets chiffrés (une seule fois)
ansible-playbook deploy.yml -e target_env=staging \
    -e app_image=franckryan/legeni-webapp -e app_version=1.0.0-1 \
    --vault-password-file ~/.vault_pass_legeni
```

Accès : staging `http://$(minikube ip):30081` ou `https://staging.legeni.local`, production `http://$(minikube ip):30082` ou `https://legeni.local`.
