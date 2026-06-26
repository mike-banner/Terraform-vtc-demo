---
phase: "03"
reviewed: "2026-06-26T14:18:00+02:00"
depth: standard
files_reviewed: 11
files_reviewed_list:
  - terraform/providers.tf
  - terraform/variables.tf
  - terraform/main.tf
  - terraform/outputs.tf
  - terraform/modules/supabase_project/main.tf
  - terraform/modules/supabase_project/variables.tf
  - terraform/modules/supabase_project/outputs.tf
  - terraform/modules/cloudflare_pages/main.tf
  - terraform/modules/cloudflare_pages/variables.tf
  - .github/workflows/plan.yml
  - .github/workflows/apply.yml
findings:
  critical: 2
  warning: 3
  info: 2
  total: 7
status: issues_found
---

# Phase 03 : Rapport de revue de code

**Revue :** 2026-06-26T14:18:00+02:00
**Profondeur :** standard
**Fichiers examinés :** 11
**Statut :** issues_found

## Résumé

Revue de l'infrastructure Terraform (Supabase + Cloudflare Pages) et des workflows GitHub Actions associés. La structure modulaire est saine, les secrets ne sont jamais codés en dur, et les variables sensibles sont correctement typées. Deux problèmes bloquants ont été identifiés : le workflow `plan.yml` est cassé par des variables Supabase manquantes, et la construction manuelle de l'URL de connexion PostgreSQL peut produire une URL invalide si le mot de passe contient des caractères spéciaux.

---

## Problèmes critiques

### CR-01 : Variables Supabase absentes du workflow `plan.yml`

**Fichier :** `.github/workflows/plan.yml:31-39`
**Problème :** Le workflow `plan.yml` n'injecte pas `TF_VAR_supabase_access_token`, `TF_VAR_supabase_organization_id`, ni `TF_VAR_supabase_database_password`. Ces trois variables sont **requises** (aucune valeur par défaut) dans `terraform/variables.tf`. Résultat : `terraform plan` échoue systématiquement sur chaque PR avec `No value for required variable`, rendant la protection de branche inopérante.

Par comparaison, `apply.yml` les déclare correctement (lignes 35-37). L'asymétrie confirme un oubli.

**Correction :**
```yaml
# .github/workflows/plan.yml — bloc env du job plan
env:
  TF_WORKSPACE: ${{ github.base_ref == 'main' && 'production' || github.base_ref == 'staging' && 'staging' || 'dev' }}
  TF_VAR_cloudflare_api_token:        ${{ secrets.CF_API_TOKEN }}
  TF_VAR_cloudflare_account_id:       ${{ secrets.CF_ACCOUNT_ID }}
  TF_VAR_github_owner:                ${{ secrets.GH_OWNER }}
  TF_VAR_github_repo_name:            ${{ secrets.GH_REPO_NAME }}
  # Ajouts manquants :
  TF_VAR_supabase_access_token:       ${{ secrets.SUPABASE_ACCESS_TOKEN }}
  TF_VAR_supabase_organization_id:    ${{ secrets.SUPABASE_ORG_ID }}
  TF_VAR_supabase_database_password:  ${{ secrets.SUPABASE_DB_PASSWORD }}
  AWS_ACCESS_KEY_ID:    ${{ secrets.CF_R2_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.CF_R2_SECRET_ACCESS_KEY }}
```

---

### CR-02 : Mot de passe non encodé dans l'URL PostgreSQL construite manuellement

**Fichier :** `terraform/modules/supabase_project/outputs.tf:9`
**Problème :** La `database_url` est construite par interpolation de chaîne :
```hcl
value = "postgresql://postgres:${var.database_password}@db.${supabase_project.this.id}.supabase.co:5432/postgres"
```
Si `database_password` contient un caractère réservé dans une URI (`@`, `#`, `:`, `/`, `?`, `%`, `+`, etc.), l'URL produite est malformée. Les clients PostgreSQL qui parsent l'URL (Prisma, SQLAlchemy, `pg`, etc.) échoueront à la connexion ou se connecteront à un mauvais host — une panne silencieuse difficile à diagnostiquer en production.

**Correction :** Encoder les caractères réservés. En Terraform, l'encodage URL n'est pas natif dans le langage HCL, mais on peut déléguer la construction à une `local` avec `urlencode` via la fonction `replace` ou contraindre le mot de passe à un jeu de caractères sûr via une validation de variable.

Option A — contrainte de validation (recommandée, sans code supplémentaire) :
```hcl
# modules/supabase_project/variables.tf
variable "database_password" {
  description = "Mot de passe administrateur PostgreSQL du projet"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Za-z0-9!$^*()_+\\-=\\[\\]{};',.]+$", var.database_password))
    error_message = "Le mot de passe ne doit pas contenir de caractères réservés URI (@, #, :, /, ?, %, +, &, espace)."
  }
}
```

Option B — utiliser l'attribut natif du provider si disponible. Vérifier si `supabase_project.this` expose un attribut `database_url` ou `connection_string` directement (évite la construction manuelle).

---

## Avertissements

### WR-01 : Step `Fail if plan failed` dupliqué dans `plan.yml`

**Fichier :** `.github/workflows/plan.yml:110-115`
**Problème :** Le step est défini deux fois à l'identique. Le second ne s'exécute jamais (le premier `exit 1` arrête le job). Artefact de copier-coller.

**Correction :** Supprimer les lignes 113-115.

---

### WR-02 : Pas de `prevent_destroy` sur le projet Supabase

**Fichier :** `terraform/modules/supabase_project/main.tf:18-23`
**Problème :** La ressource `supabase_project` n'a pas de bloc `lifecycle { prevent_destroy = true }`. Un `terraform destroy` accidentel, ou un changement de nom de projet (qui force un destroy+recreate), détruirait la base de données PostgreSQL et toutes ses données — sans avertissement supplémentaire.

**Correction :**
```hcl
resource "supabase_project" "this" {
  name              = var.project_name
  organization_id   = var.organization_id
  database_password = var.database_password
  region            = var.region

  lifecycle {
    prevent_destroy = true
  }
}
```

---

### WR-03 : Pas de contrôle de concurrence dans `apply.yml`

**Fichier :** `.github/workflows/apply.yml:19`
**Problème :** Deux merges successifs rapides vers `main` (ou `staging`) déclenchent deux jobs `apply` simultanés sur le même workspace Terraform. Si le backend R2 ne supporte pas le state locking (ou si le lock expire), les deux jobs peuvent corrompre le state.

**Correction :** Ajouter un groupe de concurrence au niveau du job ou du workflow :
```yaml
# .github/workflows/apply.yml — au niveau du job apply
jobs:
  apply:
    runs-on: ubuntu-latest
    concurrency:
      group: terraform-apply-${{ github.ref_name }}
      cancel-in-progress: false  # attendre, ne pas annuler un apply en cours
```

---

## Informations

### IN-01 : `depends_on` redondant dans `main.tf`

**Fichier :** `terraform/main.tf:46`
**Problème :** `depends_on = [module.supabase_project]` est superflu — `env_vars` référence déjà `module.supabase_project.database_url` et `module.supabase_project.api_url`, ce qui crée une dépendance implicite que Terraform résout automatiquement.

**Correction :** Supprimer la ligne 46. (Fonctionnellement neutre, mais le `depends_on` explicite masque la dépendance réelle et complique les lectures futures.)

---

### IN-02 : `NEXT_PUBLIC_SUPABASE_URL` stockée comme `secret_text`

**Fichier :** `terraform/modules/cloudflare_pages/main.tf:55`
**Problème :** Toutes les variables d'environnement sont injectées avec `type = "secret_text"`, y compris `NEXT_PUBLIC_SUPABASE_URL`. Par convention Next.js, toute variable préfixée `NEXT_PUBLIC_` est intégrée dans le bundle client et donc visible publiquement. La stocker comme `secret_text` dans Cloudflare la masque dans le dashboard mais ne l'empêche pas d'être publique dans le build — crée une fausse impression de confidentialité.

**Correction :** Utiliser `type = "plain_text"` pour `NEXT_PUBLIC_*` ou documenter explicitement que le `secret_text` ne protège que la visibilité dans le dashboard Cloudflare, pas la visibilité réseau :
```hcl
environment_variables = {
  for k, v in var.env_vars : k => {
    value = v
    type  = startswith(k, "NEXT_PUBLIC_") ? "plain_text" : "secret_text"
  }
}
```

---

_Revue : 2026-06-26T14:18:00+02:00_
_Reviewer : Claude (gsd-code-reviewer)_
_Profondeur : standard_
