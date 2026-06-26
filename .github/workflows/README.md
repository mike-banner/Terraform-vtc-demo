# Workflows GitHub Actions — Terraform CI/CD

Ce dossier contient les workflows GitOps automatisant le cycle Terraform pour le projet VTC.

| Workflow | Déclencheur | Action |
|---|---|---|
| `plan.yml` | PR vers `main` ou `staging` (chemins `terraform/**`) | fmt + validate + plan, résultat commenté dans la PR |
| `apply.yml` | Push/merge vers `main` ou `staging` (chemins `terraform/**`) | init + apply -auto-approve |

---

## 1. Secrets GitHub requis

Ajouter ces 7 secrets dans **Settings > Secrets and variables > Actions > Repository secrets** :

| Nom du secret | Source dans le dashboard | Usage dans le workflow |
|---|---|---|
| `CF_R2_ACCESS_KEY_ID` | Cloudflare Dashboard > R2 > Gérer les tokens API R2 > Access Key ID | `AWS_ACCESS_KEY_ID` sur le runner (auth backend S3) |
| `CF_R2_SECRET_ACCESS_KEY` | Cloudflare Dashboard > R2 > Gérer les tokens API R2 > Secret Access Key | `AWS_SECRET_ACCESS_KEY` sur le runner (auth backend S3) |
| `CF_R2_ENDPOINT` | `https://<account_id>.r2.cloudflarestorage.com` | `-backend-config="endpoint=..."` lors de l'init |
| `CF_API_TOKEN` | Cloudflare Dashboard > Mon profil > Tokens API (permissions Pages:Edit + Zone:Read) | `TF_VAR_cloudflare_api_token` |
| `CF_ACCOUNT_ID` | Cloudflare Dashboard > URL du dashboard ou sidebar (Account ID) | `TF_VAR_cloudflare_account_id` |
| `GH_OWNER` | Org ou utilisateur GitHub propriétaire du dépôt source VTC | `TF_VAR_github_owner` |
| `GH_REPO_NAME` | Nom du dépôt GitHub contenant le code source de l'application VTC | `TF_VAR_github_repo_name` |

> **Remarque :** `GH_OWNER`, `GH_REPO_NAME` et `CF_ACCOUNT_ID` ne sont pas strictement secrets
> (pas de credentials) mais les stocker dans les secrets GitHub simplifie la gestion et reste valide.

---

## 2. Mapping branche → workspace Terraform

| Branche cible | Workspace Terraform | Environnement |
|---|---|---|
| `main` | `production` | Infrastructure de production |
| `staging` | `staging` | Infrastructure de staging |
| *(autre)* | `dev` | Usage local uniquement |

Le workspace est sélectionné via la variable d'environnement `TF_WORKSPACE`, lue par Terraform
avant tout `init`. Dans `plan.yml`, la valeur est dérivée de `github.base_ref` (branche cible de
la PR). Dans `apply.yml`, elle est dérivée de `github.ref_name` (branche du push).

> **Note :** Le workspace `dev` est destiné à un usage local (via `terraform workspace select dev`).
> Les triggers CI ne couvrent que `main` et `staging` — la branche `dev` ne déclenchera jamais
> de run automatique.

---

## 3. Prérequis bloquants avant le premier run CI

Ces éléments doivent exister **avant** de pousser une PR qui déclenche les workflows.
Un run sans ces prérequis échoue dès `terraform init`.

### 3a. Bucket R2 `terraform-state-vtc`

Le backend Terraform pointe vers un bucket Cloudflare R2 nommé `terraform-state-vtc`.

Ce bucket doit être créé manuellement dans le dashboard Cloudflare avant le premier run :

1. Aller dans **Cloudflare Dashboard > R2 > Créer un bucket**
2. Nom : `terraform-state-vtc`
3. Région : `auto`

### 3b. Workspaces Terraform (`dev`, `staging`, `production`)

Les workflows utilisent `TF_WORKSPACE` pour sélectionner le workspace. Si le workspace
n'existe pas dans le backend, `terraform init` échoue avec :

```
The currently selected workspace (production) does not exist.
```

Créer les workspaces manuellement **en local** avant le premier run CI :

```bash
cd terraform/

# Init local avec l'endpoint R2
terraform init \
  -backend-config="endpoint=https://<ACCOUNT_ID>.r2.cloudflarestorage.com"

# Créer les 3 workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new production

# Vérifier
terraform workspace list
```

> **Alternative :** Si vous préférez que les workspaces soient créés automatiquement lors
> du premier run CI, remplacez `terraform init` par :
> ```bash
> terraform init -backend-config="endpoint=${{ secrets.CF_R2_ENDPOINT }}"
> terraform workspace select -or-create $TF_WORKSPACE
> ```
> Cette modification des workflows n'est pas appliquée par défaut — le prérequis
> documentaire est préféré pour garder les workflows simples et l'état des workspaces
> explicitement sous contrôle.

---

## 4. Branch protection rules (obligatoire pour éviter un apply accidentel en production)

Sans branch protection, un `git push` direct sur `main` déclenche immédiatement `apply.yml`
en `production` sans review. Pour éviter cela :

1. **GitHub repo > Settings > Branches > Add branch protection rule**
2. Configurer pour `main` **et** `staging` :
   - [x] Require a pull request before merging
   - [x] Require approvals (1 minimum recommandé)
   - [x] Require status checks to pass before merging (ajouter `plan` comme check requis)
3. Résultat : seul un merge de PR peut déclencher `apply.yml`, jamais un push direct.

> Cette règle est le garde-fou final contre un apply accidentel en production. Elle est
> hors scope des workflows eux-mêmes mais indispensable à la sécurité du pipeline.
