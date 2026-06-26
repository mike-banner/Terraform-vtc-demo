---
phase: 02-cicd-gitops
reviewed: 2026-06-26T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - .github/workflows/plan.yml
  - .github/workflows/apply.yml
  - .github/workflows/README.md
findings:
  critical: 1
  warning: 4
  info: 2
  total: 7
status: issues_found
---

# Phase 02 : Rapport de revue de code — CI/CD GitOps

**Reviewé le :** 2026-06-26
**Profondeur :** standard
**Fichiers reviewés :** 3
**Statut :** issues_found

---

## Résumé

Revue des deux workflows GitHub Actions (plan + apply) et de leur documentation.
L'architecture globale est correcte : `github.base_ref` pour `plan.yml`, `github.ref_name`
pour `apply.yml`, injection via `TF_VAR_*` et `AWS_*`, scopes de permissions minimaux.

Un bug fonctionnel critique a été identifié dans `plan.yml` : l'appel à l'API GitHub pour
poster le commentaire de plan n'est pas `await`-é, ce qui signifie que l'étape se termine
**avant** que la requête HTTP soit envoyée — le commentaire PR n'est jamais affiché de
façon fiable, sans aucune erreur visible. Le reste des findings concerne des risques de
sécurité (injection de secrets en ligne de commande) et des lacunes opérationnelles
(concurrence, épinglage des actions).

---

## Problèmes critiques

### CR-01 : `createComment` appelé sans `await` — commentaire PR silencieusement perdu

**Fichier :** `.github/workflows/plan.yml:100`

**Problème :** `github.rest.issues.createComment({...})` retourne une `Promise`. Sans
`await`, la fonction utilisateur retourne immédiatement après avoir *lancé* l'appel
réseau, sans attendre sa résolution. L'action `github-script` await la fonction utilisateur,
mais les Promises internes non-await-ées sont fire-and-forget : la requête HTTP vers l'API
GitHub peut ne jamais être envoyée avant la fin du step. L'étape s'affiche en vert alors
que le commentaire n'a pas été posté. C'est le défaut fonctionnel le plus grave : le
pipeline entier tourne pour rien si le commentaire plan n'arrive jamais dans la PR.

**Correctif :**

```javascript
// Ligne 100 — ajouter await
await github.rest.issues.createComment({
  issue_number: context.issue.number,
  owner:        context.repo.owner,
  repo:         context.repo.repo,
  body:         output
});
```

---

## Avertissements

### WR-01 : Secret interpolé directement dans la commande shell (`run:`)

**Fichiers :** `.github/workflows/plan.yml:63`, `.github/workflows/apply.yml:52`

**Problème :** La syntaxe `${{ secrets.CF_R2_ENDPOINT }}` est interpolée dans le YAML
avant que le shell ne reçoive la commande. Si la valeur du secret contient un guillemet
double, un dollar, ou un backtick, le shell interprétera ces caractères et le résultat
sera imprévisible. Plus fondamentalement, le [guide de sécurité GitHub Actions](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#understanding-the-risk-of-script-injections)
recommande explicitement de passer les secrets via des variables d'environnement
intermédiaires pour garantir le masquage et éviter l'injection shell.

```yaml
# Avant (risqué)
run: terraform init -input=false -backend-config="endpoint=${{ secrets.CF_R2_ENDPOINT }}"

# Après (recommandé)
env:
  TF_BACKEND_ENDPOINT: ${{ secrets.CF_R2_ENDPOINT }}
run: terraform init -input=false -backend-config="endpoint=$TF_BACKEND_ENDPOINT"
```

Appliquer la même correction dans `apply.yml:52`.

---

### WR-02 : Absence de contrôle de concurrence — risque de lock state Terraform

**Fichiers :** `.github/workflows/plan.yml` (niveau job), `.github/workflows/apply.yml` (niveau job)

**Problème :** Deux merges rapprochés sur `main` ou `staging` déclenchent deux runs
`apply.yml` en parallèle sur le même workspace. Terraform pose un verrou sur le state
backend (R2) au moment de l'apply. Le second run entre en conflit et échoue avec une
erreur de lock, ce qui laisse l'infrastructure dans un état partiellement appliqué ou
force une intervention manuelle pour débloquer le state.

**Correctif :** Ajouter un bloc `concurrency` dans chaque workflow :

```yaml
# Dans plan.yml, au niveau racine (après `on:`)
concurrency:
  group: terraform-${{ github.base_ref }}
  cancel-in-progress: true

# Dans apply.yml — ne PAS cancel-in-progress (risque d'apply interrompu)
concurrency:
  group: terraform-${{ github.ref_name }}
  cancel-in-progress: false
```

---

### WR-03 : Actions épinglées sur des tags mutables, pas des SHAs de commit

**Fichiers :** `.github/workflows/plan.yml:43,47,82`, `.github/workflows/apply.yml:42,45`

**Problème :** `actions/checkout@v4`, `hashicorp/setup-terraform@v4`, et
`actions/github-script@v7` sont référencés par tag de version majeure. Un tag comme
`@v4` est un pointeur mutable : si le dépôt upstream est compromis ou si le tag est
réécrit, un contenu malveillant est exécuté avec accès aux secrets du runner sans
aucune modification visible dans ce repo. C'est un vecteur d'attaque supply-chain
documenté.

**Correctif :** Épingler sur le SHA du commit correspondant au tag :

```yaml
# Exemple
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
- uses: hashicorp/setup-terraform@b9cd54a3c349d3f38e8881555d616ced269ef065  # v3.1.2
- uses: actions/github-script@60a0d83039c74a4aee543508d2ffcb1c3799cdea  # v7.0.1
```

Vérifier les SHAs exacts sur le Marketplace GitHub au moment de la mise à jour.

---

### WR-04 : `apply.yml` applique un plan frais, pas le plan reviewé en PR

**Fichier :** `.github/workflows/apply.yml:59`

**Problème :** `terraform apply -auto-approve` sans fichier de plan (`-plan=planfile`)
recalcule un nouveau plan au moment du merge. Si l'état de l'infrastructure a changé
entre le moment du commentaire PR (plan.yml) et le merge (apply.yml), l'apply peut
détruire ou créer des ressources qui n'ont pas été reviewées. Le commentaire PR donne
une fausse assurance sur ce qui sera effectivement appliqué.

**Correctif recommandé (long terme) :** Persister le plan binaire comme artifact dans
`plan.yml` et le réutiliser dans `apply.yml` :

```yaml
# plan.yml — après Terraform Plan
- name: Upload plan artifact
  uses: actions/upload-artifact@v4
  with:
    name: tfplan-${{ github.event.pull_request.number }}
    path: terraform/tfplan.binary
    retention-days: 7

# apply.yml — remplacer apply par
- name: Download plan artifact
  uses: actions/download-artifact@v4
  with:
    name: tfplan-${{ github.event.pull_request.number }}
    path: terraform/
- name: Terraform Apply
  run: terraform apply -auto-approve terraform/tfplan.binary
  working-directory: terraform
```

Note : cette approche complexifie le pipeline. Si le trade-off est accepté en
connaissance de cause (délai court entre plan et merge, infra stable), le documenter
explicitement dans le README.

---

## Informations

### IN-01 : Version `hashicorp/setup-terraform@v4` à vérifier

**Fichiers :** `.github/workflows/plan.yml:47`, `.github/workflows/apply.yml:45`

**Problème :** La dernière version majeure stable de `hashicorp/setup-terraform`
connue au moment de cette revue est `v3`. Si `v4` n'existe pas sur le Marketplace
GitHub, les deux workflows échouent dès le début avec une erreur de résolution d'action.
À confirmer sur https://github.com/hashicorp/setup-terraform/releases.

**Correctif :** Si `v4` n'existe pas, utiliser `@v3` ou épingler sur le SHA `v3` (voir WR-03).

---

### IN-02 : Version Terraform non épinglée (`~> 1.5`)

**Fichiers :** `.github/workflows/plan.yml:49`, `.github/workflows/apply.yml:47`

**Problème :** `terraform_version: "~> 1.5"` autorise toute version `>= 1.5, < 2.0`.
Un upgrade mineur de Terraform (ex. 1.5 → 1.9 → 1.12) peut introduire des changements
de comportement subtils (warnings, nouvelles validations, changements de provider API).
La reproductibilité des runs n'est pas garantie.

**Correctif :** Épingler sur une version exacte :

```yaml
terraform_version: "1.9.8"
```

Mettre à jour délibérément via un commit dédié lors des upgrades.

---

_Reviewé le : 2026-06-26_
_Reviewer : Claude (gsd-code-reviewer)_
_Profondeur : standard_
