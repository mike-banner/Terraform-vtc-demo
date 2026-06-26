---
phase: 02-cicd-gitops
verified: 2026-06-26T00:00:00Z
status: human_needed
score: 5/5 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Vérifier que hashicorp/setup-terraform@v4 existe sur le Marketplace GitHub"
    expected: "La version v4 est disponible ; sinon remplacer par @v3 dans les deux workflows"
    why_human: "Impossible de vérifier la disponibilité d'une action GitHub sans accès réseau. La review IN-01 signale que v3 était la dernière version connue — si v4 n'existe pas, les deux workflows échouent dès le premier step."
  - test: "Ouvrir une PR de test vers staging modifiant un fichier sous terraform/"
    expected: "Le workflow Terraform Plan se lance, un commentaire apparaît dans la PR avec les statuts fmt/validate/plan et le détail du plan dans un bloc Show Plan"
    why_human: "Vérification end-to-end impossible sans GitHub Actions actif et secrets configurés (Task 4 du plan — checkpoint non exécuté)"
  - test: "Merger la PR de test vers staging"
    expected: "Le workflow Terraform Apply se lance, applique sur le workspace staging, aucun secret visible en clair dans les logs"
    why_human: "Idem — nécessite les 7 secrets configurés, le bucket R2 et les workspaces créés"
---

# Phase 02 : Verification — CI/CD GitOps

**Phase Goal:** Automatiser le cycle de déploiement Terraform via deux workflows GitHub Actions (plan sur PR, apply sur merge), supprimant toute intervention manuelle.
**Verified:** 2026-06-26
**Status:** human_needed — code vérifié 5/5, runtime bloqué par IN-01 (version v4) et checkpoint end-to-end non exécuté
**Re-verification:** Non — vérification initiale

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | PR vers main/staging déclenche un terraform plan commenté dans la PR | VERIFIED | `plan.yml` trigger `pull_request` branches `[main, staging]`, step `Post Plan to PR` via `github-script@v7` avec `await createComment` (ligne 100) |
| 2 | Merge/push déclenche un terraform apply automatique | VERIFIED | `apply.yml` trigger `push` branches `[main, staging]`, step `terraform apply -auto-approve -input=false` |
| 3 | Workspace sélectionné dynamiquement (main→production, staging→staging) | VERIFIED | `plan.yml` utilise `github.base_ref`, `apply.yml` utilise `github.ref_name` — distinction correcte, valeurs `production`/`staging`/`dev` |
| 4 | Credentials injectés depuis GitHub Secrets, jamais hardcodés | VERIFIED | `grep -rE "(AKIA|r2.cloudflarestorage.com/[a-z0-9]{20})" .github/workflows/` retourne 0 ; tous les accès via `${{ secrets.* }}` |
| 5 | Un plan en échec fait échouer le job | VERIFIED | `plan` step avec `continue-on-error: true`, step `Fail if plan failed` avec `if: steps.plan.outcome == 'failure'` → `exit 1` |

**Score : 5/5 truths verified**

---

### Required Artifacts

| Artifact | Attendu | Status | Détails |
|----------|---------|--------|---------|
| `.github/workflows/plan.yml` | Workflow PR : fmt, init, validate, plan, commentaire PR | VERIFIED | 113 lignes, YAML valide, 4× continue-on-error dont fmt+plan, permissions `pull-requests: write`, filtre `paths: terraform/**` |
| `.github/workflows/apply.yml` | Workflow merge : init, apply -auto-approve | VERIFIED | 60 lignes, YAML valide, trigger `push`, `github.ref_name` (jamais `base_ref`), permissions `contents: read` seulement |
| `.github/workflows/README.md` | Doc des 7 secrets, mapping workspace, prérequis bloquants | VERIFIED | 9 occurrences des 7 noms de secrets, 3 mentions `terraform-state-vtc`, 4 mentions `workspace new`/`-or-create`, 3 mentions `branch protection` |

---

### Key Link Verification

| From | To | Via | Status | Détails |
|------|----|-----|--------|---------|
| `plan.yml` | `terraform/backend.tf` | `-backend-config=endpoint` | WIRED | Ligne 63 : `-backend-config="endpoint=${{ secrets.CF_R2_ENDPOINT }}"` |
| `plan.yml` | GitHub Secrets | `secrets.CF_R2_ACCESS_KEY_ID` | WIRED | Ligne 38 : `AWS_ACCESS_KEY_ID: ${{ secrets.CF_R2_ACCESS_KEY_ID }}` |
| `apply.yml` | TF_WORKSPACE | `github.ref_name` | WIRED | Ligne 27 : expression conditionnelle `ref_name == 'main' && 'production' ...` |

---

### Behavioral Spot-Checks

Step 7b : SKIPPED — les workflows nécessitent GitHub Actions en ligne ; aucun point d'entrée local exécutable.

---

### Probe Execution

Step 7c : SKIPPED — aucun script `probe-*.sh` défini pour cette phase.

---

### Requirements Coverage

Aucune requirement ID déclarée dans `02-01-PLAN.md` (champ `requirements: []`). Voir ROADMAP.md Phase 2 pour les objectifs de haut niveau — tous couverts par les 5 truths vérifiées.

---

### Anti-Patterns Found

| File | Finding | Severity | Impact |
|------|---------|----------|--------|
| `plan.yml:63`, `apply.yml:52` | Secret `CF_R2_ENDPOINT` interpolé directement dans `run:` (`${{ secrets.* }}` dans la commande shell) | WARNING (WR-01) | Risque d'injection shell si la valeur contient des caractères spéciaux (`"`, `$`, backtick). Correctif : passer via une variable d'env intermédiaire `TF_BACKEND_ENDPOINT` |
| `plan.yml`, `apply.yml` | Aucun bloc `concurrency` déclaré | WARNING (WR-02) | Deux pushs rapprochés sur la même branche déclenchent deux runs parallèles → conflit de lock sur le state R2. `cancel-in-progress: true` pour plan, `false` pour apply |
| `plan.yml:43,47,82`, `apply.yml:42,45` | Actions référencées par tag mutable (`@v4`, `@v7`) au lieu de SHA de commit | WARNING (WR-03) | Vecteur supply-chain si le tag upstream est réécrit. Correctif : épingler sur SHA (`checkout@11bd7...`, etc.) |
| `apply.yml:59` | `terraform apply -auto-approve` sans fichier de plan binaire (-plan=planfile) | WARNING (WR-04) | L'apply recalcule un plan frais au moment du merge — des changements d'infrastructure entre le commentaire PR et le merge peuvent être appliqués sans review |

**Note CR-01 (review REVIEW.md) :** La review signale `createComment` appelé sans `await`. Le fichier sur disque (ligne 100 de `plan.yml`) montre `await github.rest.issues.createComment({...})` — le `await` EST présent. La review a vraisemblablement été rédigée sur une version intermédiaire. CR-01 n'est pas un bug dans le code actuel.

Aucun marqueur `TBD`, `FIXME`, `XXX` détecté dans les fichiers du workflow.

---

### Human Verification Required

#### 1. Version hashicorp/setup-terraform@v4

**Test :** Vérifier sur https://github.com/hashicorp/setup-terraform/releases que la version `v4` existe.
**Expected :** Le tag `v4` est présent et résolvable. Si absent, remplacer par `@v3` (ou SHA) dans `plan.yml:47` et `apply.yml:45`.
**Why human :** La review IN-01 signale que `v3` était la dernière version connue. Si `v4` n'existe pas, les deux workflows échouent immédiatement au step `setup-terraform` et le pipeline est entièrement non fonctionnel malgré un code par ailleurs correct.

#### 2. Test end-to-end : PR → commentaire plan

**Test :** Configurer les 7 secrets dans Settings > Secrets and variables > Actions, créer le bucket R2 `terraform-state-vtc`, initialiser les workspaces en local (`terraform workspace new staging production dev`), puis ouvrir une PR de test vers `staging` modifiant un fichier sous `terraform/`.
**Expected :** Le workflow "Terraform Plan" se déclenche, un commentaire avec les statuts fmt/validate/plan et un bloc `<details>Show Plan</details>` apparaît dans la PR.
**Why human :** Vérification runtime impossible sans GitHub Actions actif et secrets réels. Task 4 (checkpoint humain) non exécutée — arrêt du plan à 3/4 tasks.

#### 3. Test end-to-end : merge → apply

**Test :** Merger la PR de test vers `staging`.
**Expected :** Le workflow "Terraform Apply" se lance sur le workspace `staging`. Aucun secret visible en clair dans les logs. L'infrastructure Cloudflare Pages est modifiée selon le plan.
**Why human :** Idem — nécessite les prérequis du point 2 et un apply réel vers Cloudflare.

---

### Gaps Summary

Aucun gap bloquant au niveau du code. Les 5 must-haves sont vérifiés, les 3 artifacts existent et sont correctement câblés.

Les 4 warnings de la review (WR-01 à WR-04) représentent de la dette technique identifiée et documentée, sans bloquer le goal de la phase. Ils sont candidats à un plan dédié (phase 02 hotfix ou amélioration en phase 3).

Le point IN-01 (version `hashicorp/setup-terraform@v4`) est le seul risque potentiellement bloquant au runtime — il doit être résolu avant le premier déclenchement des workflows.

---

_Verified: 2026-06-26_
_Verifier: Claude (gsd-verifier)_
