// PROJET FINAL – Chaîne CI/CD complète « du commit à la production » (Lots 4 et 5)
//
// Toutes les branches et pull requests : contrôles qualité en parallèle → build → scan Trivy
// Branche main uniquement : push Docker Hub → déploiement staging (Ansible) → validation humaine
//                           → déploiement prod (Ansible, rollback auto) → tag Git v<VERSION>
//
// Credentials Jenkins utilisés (aucun secret dans ce fichier) :
//   registry-credentials (Username/password Docker Hub)   kubeconfig (Secret file)
//   ansible-vault-pass   (Secret file)                     discord-webhook (Secret text)
//   github               (Username/token, pour pousser le tag)
pipeline {
    agent any

    environment {
        REGISTRY_USER = 'franckryan'
        IMAGE         = "${REGISTRY_USER}/legeni-webapp"
    }

    options {
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
        disableConcurrentBuilds()               // jamais deux déploiements en même temps
        buildDiscarder(logRotator(numToKeepStr: '15'))
    }

    stages {
        stage('Version') {
            steps {
                script {
                    // Tag d'image traçable : <VERSION>-<numéro de build>, ex. 1.1.0-37 (jamais "latest")
                    env.APP_VERSION = "${readFile('VERSION').trim()}-${env.BUILD_NUMBER}"
                    currentBuild.displayName = "#${env.BUILD_NUMBER} ${env.APP_VERSION}"
                }
                echo "Version construite : ${env.APP_VERSION} (branche ${env.BRANCH_NAME})"
            }
        }

        stage('Qualité') {
            parallel {
                stage('Tests + couverture') {
                    agent { docker { image 'python:3.12-slim'; args '-e HOME=/tmp'; reuseNode true } }
                    steps {
                        sh '''
                            python -m venv /tmp/venv
                            /tmp/venv/bin/pip install -q -r requirements.txt -r requirements-dev.txt
                            mkdir -p reports
                            /tmp/venv/bin/pytest --junitxml=reports/junit.xml \
                                --cov=app --cov-report=xml:reports/coverage.xml --cov-fail-under=80
                        '''
                    }
                    post {
                        always {
                            junit 'reports/junit.xml'
                            recordCoverage(tools: [[parser: 'COBERTURA', pattern: 'reports/coverage.xml']])
                        }
                    }
                }
                stage('Lint Python') {
                    agent { docker { image 'python:3.12-slim'; args '-e HOME=/tmp'; reuseNode true } }
                    steps {
                        sh '''
                            python -m venv /tmp/venv-lint
                            /tmp/venv-lint/bin/pip install -q flake8==7.1.1
                            mkdir -p reports
                            /tmp/venv-lint/bin/flake8 --output-file=reports/flake8.txt --tee .
                        '''
                    }
                    post { always { recordIssues(tools: [flake8(pattern: 'reports/flake8.txt')]) } }
                }
                stage('Lint Dockerfile') {
                    steps { sh 'docker run --rm -i hadolint/hadolint:v2.12.0 < Dockerfile' }
                }
                stage('Syntaxe Ansible') {
                    steps {
                        dir('ansible') {
                            sh 'ansible-playbook --syntax-check provision.yml deploy.yml'
                        }
                    }
                }
            }
        }

        stage('Build image') {
            steps {
                sh 'docker build --build-arg APP_VERSION=$APP_VERSION -t $IMAGE:$APP_VERSION .'
            }
        }

        stage('Scan Trivy') {
            steps {
                // Base de vulnérabilités en cache (volume trivy_cache) : téléchargée une seule fois,
                // la connexion de la machine étant trop lente pour la retélécharger à chaque build.
                sh '''
                    if docker run --rm -v trivy_cache:/root/.cache --entrypoint sh aquasec/trivy:0.57.1 \
                         -c 'test -f /root/.cache/trivy/db/trivy.db'; then SKIP=--skip-db-update; else SKIP=; fi
                    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy_cache:/root/.cache \
                        aquasec/trivy:0.57.1 image $SKIP --timeout 20m \
                        --severity CRITICAL --ignore-unfixed --exit-code 1 $IMAGE:$APP_VERSION
                '''
            }
        }

        stage('Push Docker Hub') {
            when { branch 'main' }
            steps {
                withCredentials([usernamePassword(credentialsId: 'registry-credentials',
                                                  usernameVariable: 'REG_USER', passwordVariable: 'REG_TOKEN')]) {
                    sh '''
                        echo "$REG_TOKEN" | docker login -u "$REG_USER" --password-stdin
                        docker push $IMAGE:$APP_VERSION
                        docker logout
                    '''
                }
            }
        }

        stage('Déploiement staging') {
            when { branch 'main' }
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG'),
                                 file(credentialsId: 'ansible-vault-pass', variable: 'VAULT_PASS')]) {
                    dir('ansible') {
                        sh '''
                            ansible-playbook deploy.yml -e target_env=staging \
                                -e app_image=$IMAGE -e app_version=$APP_VERSION \
                                --vault-password-file "$VAULT_PASS"
                        '''
                    }
                }
            }
        }

        stage('Validation production') {
            when { branch 'main' }
            steps {
                timeout(time: 30, unit: 'MINUTES') {
                    input message: "Déployer la version ${env.APP_VERSION} en production ?", ok: 'Déployer'
                }
            }
        }

        stage('Déploiement production') {
            when { branch 'main' }
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG'),
                                 file(credentialsId: 'ansible-vault-pass', variable: 'VAULT_PASS')]) {
                    dir('ansible') {
                        sh '''
                            ansible-playbook deploy.yml -e target_env=prod \
                                -e app_image=$IMAGE -e app_version=$APP_VERSION \
                                --vault-password-file "$VAULT_PASS"
                        '''
                    }
                }
            }
        }

        stage('Tag Git') {
            when { branch 'main' }
            steps {
                withCredentials([usernamePassword(credentialsId: 'github',
                                                  usernameVariable: 'GH_USER', passwordVariable: 'GH_TOKEN')]) {
                    sh '''
                        TAG="v$(cat VERSION)"
                        REPO="https://$GH_USER:$GH_TOKEN@${GIT_URL#https://}"
                        if git ls-remote --tags "$REPO" | grep -q "refs/tags/$TAG$"; then
                            echo "Tag $TAG déjà présent (version déjà mise en production)"
                        else
                            git tag "$TAG" && git push "$REPO" "$TAG"
                            echo "Tag $TAG créé pour la mise en production de $APP_VERSION"
                        fi
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "✅ ${env.JOB_NAME} #${env.BUILD_NUMBER} : ${env.APP_VERSION} OK"
        }
        failure {
            withCredentials([string(credentialsId: 'discord-webhook', variable: 'HOOK')]) {
                sh '''
                    MSG="❌ Échec de $JOB_NAME #$BUILD_NUMBER (version $APP_VERSION) : ${BUILD_URL}console"
                    curl -s -H "Content-Type: application/json" \
                         -d "{\\"content\\": \\"$MSG\\"}" "$HOOK" || true
                '''
            }
        }
        cleanup {
            sh 'docker image rm $IMAGE:$APP_VERSION >/dev/null 2>&1 || true'
        }
    }
}
