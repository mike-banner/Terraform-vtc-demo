# Phase 02: Pipeline CI/CD & GitOps — Research

**Researched:** 2026-06-25
**Domain:** GitHub Actions, Terraform CLI, Cloudflare R2 backend S3-compatible
**Confidence:** HIGH

---

## Résumé

Phase de création de deux workflows GitHub Actions (`plan.yml` et `apply.yml`) automatisant le cycle Terraform sur un backend Cloudflare R2. Le pattern central est `hashicorp/setup-terraform@v4` avec `terraform_wrapper: true` pour capturer stdout du plan et le coller en commentaire de PR via `actions/github-script@v7`.

L'enjeu principal est l'injection de l'endpoint R2 (absent de `backend.tf` par design) via `-backend-config=endpoint=...` et des credentials via les variables d'environnement standard AWS (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`). La sélection de workspace est pilotée par `github.base_ref` (PR) ou `github.ref_name` (push), mappée sur `dev / staging / production`.

**Recommandation principale :** Utiliser `TF_WORKSPACE` pour la sélection de workspace plutôt que `terraform workspace select` explicite — Terraform le lit automatiquement avant tout init/plan/apply.

---

## Architectural Responsibility Map

| Capability | Tier principal | Tier secondaire | Rationale |
|---|---|---|---|
| Sélection du workspace | GitHub Actions runner | Terraform CLI | `TF_WORKSPACE` env var lue par Terraform |
| Injection credentials R2 | GitHub Secrets → env | Terraform S3 backend | AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY standards |
| Injection endpoint R2 | `-backend-config=` CLI flag | — | L'endpoint varie par compte, absent de backend.tf par design |
| Injection variables TF (api_token, account_id) | `TF_VAR_*` env vars | — | Convention officielle Terraform pour les variables sensitives |
| Capture et commentaire du plan | `terraform_wrapper: true` + github-script | — | stdout capturé via `steps.<id>.outputs.stdout` |
| Approbation du apply | Trigger push/merge vers main/staging | — | Pas de manual approval gate en scope (YAGNI) |

---

## Stack Standard

### Actions GitHub

| Action | Version | Usage | Source |
|---|---|---|---|
| `actions/checkout` | `v4` | Checkout du dépôt | [VERIFIED: github.com/actions/checkout] — v4 stable, v7 sorti en juin 2026 mais breaking pour fork PRs |
| `hashicorp/setup-terraform` | `v4` (v4.0.1) | Install TF CLI + wrapper stdout | [VERIFIED: github.com/hashicorp/setup-terraform] |
| `actions/github-script` | `v7` | Commenter le plan dans la PR | [CITED: setup-terraform README] |

> **Note sur `actions/checkout` :** La v7 (juin 2026) bloque le checkout des fork PRs — pour un projet privé/non-fork, c'est sans impact. Rester sur `v4` par conservatisme jusqu'à stabilisation.

### Variables d'environnement à configurer dans GitHub Secrets

| Secret name | Valeur | Usage |
|---|---|---|
| `CF_R2_ACCESS_KEY_ID` | Clé d'accès R2 | `AWS_ACCESS_KEY_ID` env du runner |
| `CF_R2_SECRET_ACCESS_KEY` | Secret R2 | `AWS_SECRET_ACCESS_KEY` env du runner |
| `CF_R2_ENDPOINT` | `https://<account_id>.r2.cloudflarestorage.com` | `-backend-config=endpoint=` |
| `CF_API_TOKEN` | Token Cloudflare Pages:Edit | `TF_VAR_cloudflare_api_token` |
| `CF_ACCOUNT_ID` | Account ID Cloudflare | `TF_VAR_cloudflare_account_id` |
| `GH_OWNER` | org ou user GitHub | `TF_VAR_github_owner` |
| `GH_REPO_NAME` | nom du repo source VTC | `TF_VAR_github_repo_name` |

Les variables non-sensitives (`GH_OWNER`, `GH_REPO_NAME`, `CF_ACCOUNT_ID`) peuvent être des GitHub Variables (non secrets) — mais les stocker en secrets est aussi valide et plus simple à gérer.

---

## Architecture Patterns

### Sélection dynamique du workspace

**PR workflow (`plan.yml`) — déclenché sur `pull_request` :**
- `github.base_ref` = branche cible (ex: `main`, `staging`)
- Mapping : `main` → `production`, `staging` → `staging`, sinon `dev`

**Apply workflow (`apply.yml`) — déclenché sur `push` :**
- `github.ref_name` = branche poussée (`main`, `staging`)
- Même mapping

Deux approches pour appliquer le workspace :

**Option A — `TF_WORKSPACE` (recommandée) :**
```yaml
env:
  TF_WORKSPACE: ${{ github.base_ref == 'main' && 'production' || github.base_ref == 'staging' && 'staging' || 'dev' }}
```
Terraform lit `TF_WORKSPACE` avant `init` — pas besoin de `terraform workspace select` explicite. [CITED: developer.hashicorp.com/terraform/cli/config/environment-variables]

**Option B — `terraform workspace select -or-create` :**
```bash
terraform workspace select -or-create $WORKSPACE
```
Plus verbeux mais visible dans les logs. Le flag `-or-create` évite l'échec si le workspace n'existe pas encore. [VERIFIED: developer.hashicorp.com/terraform/cli/commands/workspace/select]

### Injection du backend R2 dynamique

Le `backend.tf` n'a pas d'`endpoint` ni de credentials hardcodés (design Phase 1). En CI :

```yaml
- name: Terraform Init
  id: init
  run: |
    terraform init \
      -input=false \
      -backend-config="endpoint=${{ secrets.CF_R2_ENDPOINT }}"
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.CF_R2_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.CF_R2_SECRET_ACCESS_KEY }}
```

`AWS_ENDPOINT_URL_S3` est une alternative moderne à `-backend-config=endpoint=` depuis Terraform >= 1.6 avec le provider AWS backend mis à jour — mais `-backend-config=` reste la méthode la plus universelle et testée sur R2. [CITED: developer.hashicorp.com/terraform/language/settings/backends/s3]

### Capture du plan et commentaire PR

Le `terraform_wrapper: true` (défaut) expose `steps.<id>.outputs.stdout`. Pattern recommandé par le README officiel :

```yaml
- name: Terraform Plan
  id: plan
  run: terraform plan -no-color -input=false
  continue-on-error: true

- name: Update PR comment
  uses: actions/github-script@v7
  env:
    PLAN: ${{ steps.plan.outputs.stdout }}
  with:
    script: |
      const output = `### Terraform Plan
      \`\`\`
      ${process.env.PLAN}
      \`\`\``;
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: output
      })
```

**Limite importante :** GitHub truncate les commentaires à 65 535 caractères. Si le plan est long, utiliser `$GITHUB_STEP_SUMMARY` en complément ou à la place. [CITED: setup-terraform README v4]

---

## Structure des fichiers à créer

```
.github/
└── workflows/
    ├── plan.yml    # PR vers main ou staging
    └── apply.yml   # Push/merge vers main ou staging
```

---

## Patterns — Workflows complets (squelette)

### plan.yml

```yaml
name: Terraform Plan

on:
  pull_request:
    branches: [main, staging]
    paths:
      - 'terraform/**'

permissions:
  contents: read
  pull-requests: write

jobs:
  plan:
    runs-on: ubuntu-latest
    env:
      TF_WORKSPACE: ${{ github.base_ref == 'main' && 'production' || github.base_ref == 'staging' && 'staging' || 'dev' }}
      TF_VAR_cloudflare_api_token: ${{ secrets.CF_API_TOKEN }}
      TF_VAR_cloudflare_account_id: ${{ secrets.CF_ACCOUNT_ID }}
      TF_VAR_github_owner: ${{ secrets.GH_OWNER }}
      TF_VAR_github_repo_name: ${{ secrets.GH_REPO_NAME }}
      AWS_ACCESS_KEY_ID: ${{ secrets.CF_R2_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.CF_R2_SECRET_ACCESS_KEY }}

    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v4
        with:
          terraform_version: "~> 1.5"

      - name: Terraform Format Check
        id: fmt
        run: terraform fmt -check -recursive
        working-directory: terraform
        continue-on-error: true

      - name: Terraform Init
        id: init
        run: terraform init -input=false -backend-config="endpoint=${{ secrets.CF_R2_ENDPOINT }}"
        working-directory: terraform

      - name: Terraform Validate
        id: validate
        run: terraform validate -no-color
        working-directory: terraform

      - name: Terraform Plan
        id: plan
        run: terraform plan -no-color -input=false
        working-directory: terraform
        continue-on-error: true

      - name: Post Plan to PR
        uses: actions/github-script@v7
        env:
          PLAN: ${{ steps.plan.outputs.stdout }}
        with:
          script: |
            const fmt = '${{ steps.fmt.outcome }}' === 'failure' ? '⚠️ fmt check failed' : '✅ fmt ok';
            const validate = '${{ steps.validate.outcome }}' === 'failure' ? '❌' : '✅';
            const plan = '${{ steps.plan.outcome }}' === 'failure' ? '❌ Plan failed' : '✅';
            const output = [
              `#### Workspace: \`${{ env.TF_WORKSPACE }}\``,
              `#### Format ${fmt} | Validate ${validate} | Plan ${plan}`,
              '<details><summary>Show Plan</summary>',
              '',
              '```terraform',
              process.env.PLAN,
              '```',
              '</details>'
            ].join('\n');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            });

      - name: Fail if plan failed
        if: steps.plan.outcome == 'failure'
        run: exit 1
```

### apply.yml

```yaml
name: Terraform Apply

on:
  push:
    branches: [main, staging]
    paths:
      - 'terraform/**'

permissions:
  contents: read

jobs:
  apply:
    runs-on: ubuntu-latest
    env:
      TF_WORKSPACE: ${{ github.ref_name == 'main' && 'production' || github.ref_name == 'staging' && 'staging' || 'dev' }}
      TF_VAR_cloudflare_api_token: ${{ secrets.CF_API_TOKEN }}
      TF_VAR_cloudflare_account_id: ${{ secrets.CF_ACCOUNT_ID }}
      TF_VAR_github_owner: ${{ secrets.GH_OWNER }}
      TF_VAR_github_repo_name: ${{ secrets.GH_REPO_NAME }}
      AWS_ACCESS_KEY_ID: ${{ secrets.CF_R2_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.CF_R2_SECRET_ACCESS_KEY }}

    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v4
        with:
          terraform_version: "~> 1.5"

      - name: Terraform Init
        run: terraform init -input=false -backend-config="endpoint=${{ secrets.CF_R2_ENDPOINT }}"
        working-directory: terraform

      - name: Terraform Apply
        run: terraform apply -auto-approve -input=false
        working-directory: terraform
```

---

## Ne pas recoder soi-même

| Problème | Ne pas faire | Utiliser à la place | Pourquoi |
|---|---|---|---|
| Capture stdout du plan | Rediriger vers fichier + cat | `terraform_wrapper: true` (défaut) + `steps.plan.outputs.stdout` | Intégré dans setup-terraform@v4 |
| Auth HCP Terraform | Script custom | `cli_config_credentials_token` dans setup-terraform | Géré nativement, mais inutile ici (self-hosted) |
| Sélection workspace | Script bash avec conditions | `TF_WORKSPACE` env var | Terraform le lit avant init |
| Variables Terraform | Fichier tfvars en CI | `TF_VAR_*` env vars | Convention officielle, pas de fichier secret en repo |

---

## Pièges courants

### Piège 1 : `terraform init` sans `-reconfigure` entre workspaces

**Ce qui se passe :** Le cache `.terraform/` retient la config du workspace précédent. Sur un runner éphémère (ubuntu-latest), ce n'est pas un problème car le workspace est fixé via `TF_WORKSPACE` avant le premier `init`. Mais en cas de réutilisation de runner, l'init peut pointer vers le mauvais state.

**Comment éviter :** Ajouter `-reconfigure` ou s'assurer que `TF_WORKSPACE` est défini **avant** `terraform init`. Avec GitHub Actions runners éphémères, ce n'est pas bloquant.

**Signe d'alerte :** Erreur `workspace does not exist` ou apply qui écrase le mauvais environnement.

---

### Piège 2 : `paths:` filter manquant sur les triggers

**Ce qui se passe :** Sans `paths: ['terraform/**']`, le workflow se déclenche sur tout push, y compris les modifications de `.github/` ou de docs. En phase 3, l'ajout de fichiers Supabase pourrait déclencher inutilement le plan Cloudflare.

**Comment éviter :** Ajouter `paths: - 'terraform/**'` dès maintenant.

---

### Piège 3 : `continue-on-error: true` sans `Fail if plan failed`

**Ce qui se passe :** `continue-on-error: true` sur le step `plan` est nécessaire pour que le step de commentaire PR s'exécute même en cas d'échec. Mais sans un step final qui `exit 1` si le plan a échoué, le job se termine en succès et la PR semble verte alors qu'elle ne l'est pas.

**Comment éviter :** Toujours ajouter un step `if: steps.plan.outcome == 'failure'` qui force l'échec.

---

### Piège 4 : `permissions: pull-requests: write` manquant

**Ce qui se passe :** Sans cette permission, `actions/github-script` ne peut pas poster de commentaire sur la PR. Le step échoue avec `Resource not accessible by integration`.

**Comment éviter :** Déclarer explicitement `permissions: pull-requests: write` dans `plan.yml`. `apply.yml` n'en a pas besoin (pas de commentaire PR).

---

### Piège 5 : `TF_WORKSPACE=production` sur une branche feature

**Ce qui se passe :** Si le mapping branch → workspace est mal configuré, un push accidentel sur `main` d'une feature non testée s'applique directement en production sans gate.

**Comment éviter :** Le trigger `push: branches: [main, staging]` limite déjà l'apply. La branche `main` étant protégée (branch protection rule recommandée), seules les PRs mergées déclenchent l'apply. Activer la branch protection rule `main` + `staging` est hors scope workflow mais à documenter dans les prérequis.

---

## Audit de légitimité des packages

Aucun package npm ou Python n'est installé dans cette phase. Les actions GitHub utilisées sont des actions officielles de dépôts vérifiés :

| Action | Éditeur | Repo officiel | Statut |
|---|---|---|---|
| `actions/checkout@v4` | GitHub Inc. | github.com/actions/checkout | [VERIFIED: github.com/actions/checkout/releases] |
| `hashicorp/setup-terraform@v4` | HashiCorp Inc. | github.com/hashicorp/setup-terraform | [VERIFIED: github.com/hashicorp/setup-terraform/releases] |
| `actions/github-script@v7` | GitHub Inc. | github.com/actions/github-script | [CITED: setup-terraform README officiel] |

---

## Disponibilité de l'environnement

| Dépendance | Requise par | Disponible | Fallback |
|---|---|---|---|
| GitHub Actions runners (ubuntu-latest) | Tous les workflows | ✓ (SaaS GitHub) | — |
| Bucket R2 `terraform-state-vtc` | `terraform init` | Dépend du setup Phase 1 | Créer manuellement avant le premier run CI |
| Workspaces `dev`, `staging`, `production` | `TF_WORKSPACE` | Dépend du setup Phase 1 | `terraform workspace select -or-create` comme fallback |
| GitHub Secrets configurés | Tous les steps | A configurer | Workflow échoue proprement si absent |

**Prérequis bloquants avant le premier run CI :**
- Le bucket R2 doit exister (setup Phase 1)
- Les 7 secrets GitHub doivent être configurés dans Settings > Secrets and variables > Actions
- Si les workspaces ne sont pas encore créés, utiliser `-or-create` dans le workflow

---

## Architecture de validation

Pas de framework de test automatisé pour les workflows GitHub Actions. La validation se fait par :

| Type | Commande | Quand |
|---|---|---|
| Lint YAML (local) | `yamllint .github/workflows/` | Avant push |
| Dry-run plan | Ouvrir une PR de test vers `staging` | Après création des workflows |
| Apply staging | Merger la PR vers `staging` | Validation end-to-end |

`yamllint` n'est pas dans le scope de cette phase — s'il est installé, l'utiliser. Sinon, l'IDE suffit.

---

## Journal des hypothèses

| # | Hypothèse | Section | Risque si faux |
|---|---|---|---|
| A1 | `actions/checkout@v4` reste la version à privilégier malgré la sortie de v7 | Stack standard | v7 est compatible pour les non-fork PRs — upgrade possible sans impact |
| A2 | `paths: ['terraform/**']` suffit à filtrer les triggers | Workflows | Si la structure de dossier change en Phase 3, le path devra être mis à jour |
| A3 | Les workspaces `dev/staging/production` existent avant le premier run CI | Env availability | Sans `-or-create`, le workflow échoue au `terraform init` avec workspace inconnu |

---

## Questions ouvertes

1. **Workspace `dev` déclenché par quoi ?**
   - Ce qu'on sait : `plan.yml` est déclenché sur PR vers `main` (→ production) et `staging` (→ staging)
   - Ce qui est flou : aucune branche `dev` n'est mentionnée dans les contraintes
   - Recommandation : Le workspace `dev` peut être utilisé manuellement en local. Si une branche `dev` est souhaitée en CI, ajouter `dev` aux branches déclenchées. En l'état, le mapping `else → dev` dans l'expression conditionnelle ne sera jamais atteint (les triggers sont limités à `main` et `staging`).

2. **Commentaire PR : créer ou mettre à jour ?**
   - Ce qu'on sait : Chaque run crée un nouveau commentaire, ce qui pollue la PR sur force-push
   - Ce qui est flou : Niveau d'acceptabilité pour ce projet
   - Recommandation : Commencer par `createComment` (simple). Le pattern update-existing-comment est documenté dans le README de setup-terraform et peut être ajouté si gênant.

3. **`terraform_version` : fixer à `>= 1.5.0` ou à une version exacte ?**
   - Ce qu'on sait : `providers.tf` déclare `required_version = ">= 1.5.0"`
   - Recommandation : Utiliser `"~> 1.5"` dans le workflow pour rester compatible avec les mises à jour patch/minor sans risquer de breaking changes majeurs. Une version exacte (ex: `"1.12.0"`) est plus reproductible mais nécessite une maintenance.

---

## Sources

### Primaires (HIGH confidence)
- [github.com/hashicorp/setup-terraform](https://github.com/hashicorp/setup-terraform) — README v4, inputs, outputs, exemples PR comment
- [developer.hashicorp.com/terraform/cli/config/environment-variables](https://developer.hashicorp.com/terraform/cli/config/environment-variables) — TF_WORKSPACE, TF_VAR_*, TF_CLI_ARGS
- [developer.hashicorp.com/terraform/cli/commands/workspace/select](https://developer.hashicorp.com/terraform/cli/commands/workspace/select) — flag `-or-create`
- [developer.hashicorp.com/terraform/language/settings/backends/s3](https://developer.hashicorp.com/terraform/language/settings/backends/s3) — -backend-config, AWS_ENDPOINT_URL_S3
- [docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions](https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions) — syntaxe secrets context
- [docs.github.com/en/actions/.../events-that-trigger-workflows#pull_request](https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/events-that-trigger-workflows#pull_request) — github.base_ref vs github.ref_name
- [github.com/hashicorp/setup-terraform/releases](https://github.com/hashicorp/setup-terraform/releases) — version v4.0.1 vérifiée
- [github.com/actions/checkout/releases](https://github.com/actions/checkout/releases) — version v4 confirmée (v7 sorti juin 2026)

### Secondaires (MEDIUM confidence)
- Tutorial HashiCorp GitHub Actions (HCP Terraform) — pattern général mais orienté Terraform Cloud, non applicable directement

---

## Métadonnées

**Décomposition de la confiance :**
- Stack (actions, versions) : HIGH — vérifié sur les pages de releases officielles
- Pattern backend-config R2 : HIGH — documenté officiellement par HashiCorp
- Pattern workspace via TF_WORKSPACE : HIGH — documenté officiellement
- Commentaire PR via github-script : HIGH — exemple officiel dans le README setup-terraform
- Sélection workspace via github.base_ref/ref_name : MEDIUM — comportement GitHub Actions vérifié, mais l'expression conditionnelle ternaire est une convention non testée sur ce repo spécifique

**Date de recherche :** 2026-06-25
**Valide jusqu'à :** 2026-09-25 (90 jours — stack stable)
