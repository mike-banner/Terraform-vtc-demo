---
phase: 03-integration-saas-vtc
plan: 03
type: execute
wave: 1
depends_on: []
files_modified:
  - terraform/providers.tf
  - terraform/variables.tf
  - terraform/main.tf
  - terraform/outputs.tf
  - terraform/terraform.tfvars
  - terraform/modules/supabase_project/main.tf
  - terraform/modules/supabase_project/variables.tf
  - terraform/modules/supabase_project/outputs.tf
  - terraform/modules/cloudflare_pages/main.tf
  - terraform/modules/cloudflare_pages/variables.tf
  - .github/workflows/plan.yml
  - .github/workflows/apply.yml
autonomous: false
requirements:
  - "Déploiement SaaS VTC"
user_setup:
  - service: supabase
    why: "Création des projets BDD par workspace via le provider Terraform Supabase"
    env_vars:
      - name: TF_VAR_supabase_access_token
        source: "Supabase Dashboard -> Account -> Access Tokens -> Generate new token"
      - name: TF_VAR_supabase_org_id
        source: "Supabase Dashboard -> Organization Settings -> slug de l'organisation (PAS un UUID)"
      - name: TF_VAR_db_password
        source: "Mot de passe Postgres choisi par l'operateur (>= 12 caracteres)"
    dashboard_config:
      - task: "Ajouter 3 secrets GitHub Actions : SUPABASE_ACCESS_TOKEN, SUPABASE_ORG_ID, SUPABASE_DB_PASSWORD"
        location: "GitHub repo -> Settings -> Secrets and variables -> Actions"

must_haves:
  truths:
    - "Un projet Supabase est declare et cree par workspace, avec un nom suffixe par le workspace (vtc-demo-dev, vtc-demo-staging, vtc-demo-production)"
    - "La database_url est construite a partir du projet Supabase et injectee dans les env_vars Cloudflare Pages en type secret_text"
    - "Le domaine custom est resolu par workspace via domain_map (dev->dev.vtc-saas.com, staging->staging.vtc-saas.com, production->app.vtc-saas.com)"
    - "Aucun secret (db_password, access_token, database_url) n'apparait en clair dans tfvars ni dans le code ; les variables sensibles n'ont aucun default"
    - "terraform plan (dry-run) montre la creation d'un supabase_project ET d'un cloudflare_pages_project, database_url affichee comme (sensitive value)"
  artifacts:
    - path: "terraform/modules/supabase_project/main.tf"
      provides: "resource supabase_project (organization_id, name, database_password, region)"
      contains: "resource \"supabase_project\""
    - path: "terraform/modules/supabase_project/outputs.tf"
      provides: "output database_url marque sensitive"
      contains: "sensitive"
    - path: "terraform/modules/supabase_project/variables.tf"
      provides: "variables organization_id, project_name, db_password, region"
    - path: "terraform/providers.tf"
      provides: "provider supabase/supabase ~> 1.0 + bloc provider supabase"
      contains: "supabase/supabase"
    - path: "terraform/variables.tf"
      provides: "supabase_access_token, supabase_org_id, db_password, domain_map, supabase_region"
    - path: "terraform/main.tf"
      provides: "module.supabase_project + injection env_vars dans module.cloudflare_pages"
      contains: "module \"supabase_project\""
    - path: "terraform/outputs.tf"
      provides: "output database_url sensitive=true"
      contains: "database_url"
    - path: "terraform/modules/cloudflare_pages/main.tf"
      provides: "deployment_configs avec env_vars en secret_text"
      contains: "deployment_configs"
    - path: "terraform/modules/cloudflare_pages/variables.tf"
      provides: "variable env_vars (map(string), default={})"
      contains: "env_vars"
  key_links:
    - from: "terraform/main.tf"
      to: "module.supabase_project.database_url"
      via: "env_vars = { DATABASE_URL = module.supabase_project.database_url }"
      pattern: "module\\.supabase_project\\.database_url"
    - from: "terraform/modules/supabase_project/outputs.tf"
      to: "supabase_project.this.id"
      via: "construction de l'URL postgres a partir du ref projet"
      pattern: "supabase_project\\.this\\.id"
    - from: "terraform/modules/cloudflare_pages/main.tf"
      to: "deployment_configs.production.env_vars"
      via: "transformation map(string) -> { type=secret_text, value }"
      pattern: "secret_text"
---

<objective>
Integrer la BDD Supabase et le Frontend Cloudflare Pages via Terraform, en reutilisant le socle workspace de la Phase 1. Chaque workspace (dev/staging/production) obtient son propre projet Supabase, dont l'URL de connexion est injectee automatiquement et de facon securisee dans les variables d'environnement du projet Cloudflare Pages correspondant.

Purpose: Concretiser le deploiement multi-environnement du SaaS VTC -- "le lien magique" entre la BDD provisionnee et le frontend, sans aucun secret en clair.
Output: providers.tf etendu, module supabase_project, module cloudflare_pages adapte aux env_vars, main.tf/variables.tf/outputs.tf racine cables, tfvars + workflows CI a jour, et un dry-run terraform plan valide.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md

<interfaces>
<!-- Schemas verifies sur les sources officielles des providers. L'executeur doit les utiliser directement, sans explorer. -->

Provider supabase/supabase (~> 1.0) -- resource supabase_project :
  Arguments requis :
    - organization_id   (string)             -- SLUG de l'org Supabase, PAS un UUID
    - name              (string)
    - database_password (string, sensitive)
    - region            (string)             -- ex: "eu-west-3"
  Optionnels : instance_size (string, ex "micro")
  Read-only  : id (string)  -- "project ref", utilise pour construire le host db.<id>.supabase.co
  Config provider : provider "supabase" { access_token = var.supabase_access_token }

  URL de connexion Postgres (aucun output natif -- a construire) :
    postgresql://postgres:<db_password>@db.<id>.supabase.co:5432/postgres

Provider cloudflare/cloudflare (~> 5.0) -- cloudflare_pages_project.deployment_configs :
  deployment_configs = {
    production = { env_vars = { CLE = { type = "secret_text", value = "..." } } }
    preview    = { env_vars = { CLE = { type = "secret_text", value = "..." } } }
  }
  type appartient a { "plain_text", "secret_text" } ; value est sensible.
</interfaces>
</context>

<tasks>

<!-- ============================== WAVE 1 ============================== -->

<task type="auto">
  <name>Task 1: Provider Supabase + variables racine (Wave 1)</name>
  <files>terraform/providers.tf, terraform/variables.tf</files>
  <read_first>
    - terraform/providers.tf (etat actuel : seul le provider cloudflare est declare)
    - terraform/variables.tf (conventions : sensitive=true et AUCUN default sur les secrets)
  </read_first>
  <action>
    Dans terraform/providers.tf :
    - Ajouter dans le bloc required_providers une entree supabase = { source = "supabase/supabase", version = "~> 1.0" } (conserver l'entree cloudflare ~> 5.0 et required_version >= 1.5.0).
    - Ajouter un bloc provider "supabase" { access_token = var.supabase_access_token }.

    Dans terraform/variables.tf, ajouter ces 5 variables (conserver les existantes) :
    - supabase_access_token : type=string, sensitive=true, AUCUN default. Description : "Token d'acces Supabase (Account -> Access Tokens), injecte via TF_VAR_* en CI".
    - supabase_org_id : type=string, AUCUN default. Description : "Slug de l'organisation Supabase (PAS un UUID)".
    - db_password : type=string, sensitive=true, AUCUN default. Description : "Mot de passe Postgres du projet Supabase".
    - supabase_region : type=string, default="eu-west-3". Description : "Region Supabase/AWS du projet (ex eu-west-3 = Paris)". # ponytail: default tunable, ajuster si la region n'est pas offerte
    - domain_map : type=map(string), default={ dev = "dev.vtc-saas.com", staging = "staging.vtc-saas.com", production = "app.vtc-saas.com" }. Description : "Domaine custom Cloudflare par workspace".
  </action>
  <verify>
    <automated>grep -q 'supabase/supabase' terraform/providers.tf &amp;&amp; grep -q 'access_token = var.supabase_access_token' terraform/providers.tf &amp;&amp; grep -q 'variable "supabase_access_token"' terraform/variables.tf &amp;&amp; grep -q 'variable "domain_map"' terraform/variables.tf &amp;&amp; echo OK</automated>
  </verify>
  <acceptance_criteria>
    - providers.tf contient source = "supabase/supabase" et version = "~> 1.0"
    - providers.tf contient le bloc provider "supabase" avec access_token = var.supabase_access_token
    - variables.tf contient les 5 variables nommees exactement : supabase_access_token, supabase_org_id, db_password, supabase_region, domain_map
    - supabase_access_token et db_password portent sensitive = true et n'ont AUCUNE ligne default
    - domain_map default mappe exactement dev->dev.vtc-saas.com, staging->staging.vtc-saas.com, production->app.vtc-saas.com
  </acceptance_criteria>
  <done>Le provider Supabase et les 5 variables racine sont declares, secrets sans default.</done>
</task>

<task type="auto">
  <name>Task 2: Module supabase_project (Wave 1)</name>
  <files>terraform/modules/supabase_project/main.tf, terraform/modules/supabase_project/variables.tf, terraform/modules/supabase_project/outputs.tf</files>
  <read_first>
    - terraform/modules/cloudflare_pages/main.tf (replique le pattern : bloc terraform/required_providers en tete de module, resource nommee "this")
    - terraform/modules/cloudflare_pages/variables.tf (style des descriptions et types)
    - terraform/modules/cloudflare_pages/outputs.tf (style des outputs construits)
  </read_first>
  <action>
    Creer le dossier terraform/modules/supabase_project/ avec 3 fichiers.

    variables.tf -- 4 variables, toutes sans default :
    - organization_id (string) : slug de l'org Supabase.
    - project_name (string) : nom complet deja suffixe par workspace (ex vtc-demo-dev).
    - db_password (string, sensitive=true) : mot de passe Postgres.
    - region (string) : region du projet.

    main.tf :
    - Bloc terraform { required_providers { supabase = { source = "supabase/supabase" } } }.
    - resource "supabase_project" "this" avec : organization_id = var.organization_id, name = var.project_name, database_password = var.db_password, region = var.region, instance_size = "micro".

    outputs.tf :
    - output "database_url" : value = "postgresql://postgres:${var.db_password}@db.${supabase_project.this.id}.supabase.co:5432/postgres", sensitive = true. # ponytail: connexion directe ; basculer sur le host pooler aws-0-<region>.pooler.supabase.com si le pooler devient requis
    - output "project_ref" : value = supabase_project.this.id (non sensitive -- sert au debug/plan).
  </action>
  <verify>
    <automated>test -f terraform/modules/supabase_project/main.tf &amp;&amp; grep -q 'resource "supabase_project" "this"' terraform/modules/supabase_project/main.tf &amp;&amp; grep -q 'sensitive' terraform/modules/supabase_project/outputs.tf &amp;&amp; grep -q 'supabase_project.this.id' terraform/modules/supabase_project/outputs.tf &amp;&amp; echo OK</automated>
  </verify>
  <acceptance_criteria>
    - Les 3 fichiers existent sous terraform/modules/supabase_project/
    - main.tf declare resource "supabase_project" "this" avec les 4 arguments requis (organization_id, name, database_password, region) referencant les variables
    - outputs.tf : database_url porte sensitive = true et construit l'URL a partir de supabase_project.this.id et var.db_password
    - variables.tf : db_password porte sensitive = true ; aucune variable n'expose de secret en default
  </acceptance_criteria>
  <done>Module supabase_project autonome : cree un projet par appel et exporte database_url (sensitive).</done>
</task>

<!-- ============================== WAVE 2 ============================== -->

<task type="auto">
  <name>Task 3: Adapter le module cloudflare_pages pour env_vars (Wave 2)</name>
  <files>terraform/modules/cloudflare_pages/main.tf, terraform/modules/cloudflare_pages/variables.tf</files>
  <read_first>
    - terraform/modules/cloudflare_pages/main.tf (resource cloudflare_pages_project.this -- possede build_config, PAS de deployment_configs)
    - terraform/modules/cloudflare_pages/variables.tf
    - Bloc interfaces du present plan (schema deployment_configs.env_vars du provider v5)
  </read_first>
  <action>
    Dans terraform/modules/cloudflare_pages/variables.tf, ajouter :
    - env_vars : type=map(string), default={}. Description : "Variables d'environnement a injecter dans le projet Pages (cle->valeur). Toutes injectees en secret_text".

    Dans terraform/modules/cloudflare_pages/main.tf, sur la resource cloudflare_pages_project.this, ajouter un attribut deployment_configs (conserver build_config et source existants) :
    - Definir un local env_vars_transformed = { for k, v in var.env_vars : k => { type = "secret_text", value = v } }.
    - deployment_configs = { production = { env_vars = local.env_vars_transformed }, preview = { env_vars = local.env_vars_transformed } }.
    Toutes les env_vars sont en type = "secret_text" (exigence securite : database_url ne doit jamais fuiter en clair).
  </action>
  <verify>
    <automated>grep -q 'variable "env_vars"' terraform/modules/cloudflare_pages/variables.tf &amp;&amp; grep -q 'deployment_configs' terraform/modules/cloudflare_pages/main.tf &amp;&amp; grep -q 'secret_text' terraform/modules/cloudflare_pages/main.tf &amp;&amp; echo OK</automated>
  </verify>
  <acceptance_criteria>
    - variables.tf contient variable "env_vars" de type map(string) avec default = {}
    - main.tf transforme var.env_vars en objets { type = "secret_text", value = ... }
    - main.tf definit deployment_configs avec les blocs production ET preview, chacun referencant les env_vars transformees
    - build_config et le bloc source GitHub existants sont conserves intacts
  </acceptance_criteria>
  <done>Le module cloudflare_pages accepte une map env_vars et l'injecte en secret_text dans production+preview.</done>
</task>

<task type="auto">
  <name>Task 4: Cabler main.tf + outputs.tf racine (le lien magique) (Wave 2)</name>
  <files>terraform/main.tf, terraform/outputs.tf</files>
  <read_first>
    - terraform/main.tf (instancie uniquement module.cloudflare_pages avec project_name suffixe par workspace)
    - terraform/outputs.tf (outputs existants : pages_project_url, pages_custom_domain, active_workspace)
    - terraform/modules/supabase_project/outputs.tf (output database_url produit par Task 2)
  </read_first>
  <action>
    Dans terraform/main.tf :
    - Ajouter module "supabase_project" { source = "./modules/supabase_project", organization_id = var.supabase_org_id, project_name = "${var.project_name}-${terraform.workspace}", db_password = var.db_password, region = var.supabase_region }.
    - Modifier l'appel module "cloudflare_pages" existant pour ajouter :
      - custom_domain = lookup(var.domain_map, terraform.workspace, "")
      - env_vars = { DATABASE_URL = module.supabase_project.database_url }
    Cette reference cree la dependance implicite : Terraform cree le projet Supabase AVANT le projet Cloudflare. Conserver les arguments existants (account_id, project_name, github_owner, github_repo_name). Supprimer le commentaire "# Test CI" en fin de fichier.

    Dans terraform/outputs.tf, ajouter :
    - output "database_url" { value = module.supabase_project.database_url, sensitive = true }
    - output "supabase_project_ref" { value = module.supabase_project.project_ref }
    Conserver les 3 outputs existants.
  </action>
  <verify>
    <automated>grep -q 'module "supabase_project"' terraform/main.tf &amp;&amp; grep -q 'module.supabase_project.database_url' terraform/main.tf &amp;&amp; grep -q 'lookup(var.domain_map' terraform/main.tf &amp;&amp; grep -q 'database_url' terraform/outputs.tf &amp;&amp; echo OK</automated>
  </verify>
  <acceptance_criteria>
    - main.tf instancie module "supabase_project" avec project_name = "${var.project_name}-${terraform.workspace}"
    - L'appel module "cloudflare_pages" passe env_vars = { DATABASE_URL = module.supabase_project.database_url } (dependance implicite Supabase -> Cloudflare)
    - L'appel module "cloudflare_pages" passe custom_domain = lookup(var.domain_map, terraform.workspace, "")
    - outputs.tf : output "database_url" porte sensitive = true ; output "supabase_project_ref" present ; les 3 outputs existants conserves
    - Le commentaire "# Test CI" est supprime de main.tf
  </acceptance_criteria>
  <done>main.tf cree le projet Supabase et injecte sa database_url dans Cloudflare Pages ; outputs racine exposent database_url (sensitive).</done>
</task>

<!-- ============================== WAVE 3 ============================== -->

<task type="auto">
  <name>Task 5: tfvars (non-sensibles) + secrets CI plan.yml/apply.yml (Wave 3)</name>
  <files>terraform/terraform.tfvars, .github/workflows/plan.yml, .github/workflows/apply.yml</files>
  <read_first>
    - terraform/terraform.tfvars (valeurs non-sensibles existantes : github_owner, github_repo_name, cloudflare_account_id)
    - .github/workflows/plan.yml (bloc env: avec les TF_VAR_* existants et le mapping de secrets)
    - .github/workflows/apply.yml (meme mapping de secrets, doit rester coherent avec plan.yml)
  </read_first>
  <action>
    Dans terraform/terraform.tfvars, ajouter UNIQUEMENT des valeurs non-sensibles :
    - supabase_region = "eu-west-3"
    NE PAS ajouter supabase_access_token, db_password ni supabase_org_id (injectes via TF_VAR_* en CI). domain_map reste sur son default (variables.tf).

    Dans .github/workflows/plan.yml ET .github/workflows/apply.yml, dans le bloc env: de chaque job, ajouter (a cote des TF_VAR_cloudflare_*) :
    - TF_VAR_supabase_access_token: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
    - TF_VAR_supabase_org_id: ${{ secrets.SUPABASE_ORG_ID }}
    - TF_VAR_db_password: ${{ secrets.SUPABASE_DB_PASSWORD }}
    Garder les deux workflows strictement coherents (meme mapping de secrets dans plan.yml et apply.yml).
  </action>
  <verify>
    <automated>grep -q 'supabase_region' terraform/terraform.tfvars &amp;&amp; ! grep -Eq 'db_password|access_token' terraform/terraform.tfvars &amp;&amp; grep -q 'TF_VAR_supabase_access_token' .github/workflows/plan.yml &amp;&amp; grep -q 'TF_VAR_db_password' .github/workflows/apply.yml &amp;&amp; echo OK</automated>
  </verify>
  <acceptance_criteria>
    - terraform.tfvars contient supabase_region = "eu-west-3" et AUCUNE occurrence de db_password, access_token ou un secret
    - plan.yml ET apply.yml contiennent les 3 lignes TF_VAR_supabase_access_token, TF_VAR_supabase_org_id, TF_VAR_db_password mappees sur SUPABASE_ACCESS_TOKEN / SUPABASE_ORG_ID / SUPABASE_DB_PASSWORD
    - Le mapping de secrets est identique entre plan.yml et apply.yml
  </acceptance_criteria>
  <done>tfvars contient les valeurs non-sensibles ; les deux workflows CI injectent les 3 nouveaux secrets Supabase.</done>
</task>

<!-- ============================== WAVE 4 ============================== -->

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 6: Dry-run terraform plan (validation arbre de dependances) (Wave 4)</name>
  <what-built>
    Provider Supabase ajoute, module supabase_project cree, cloudflare_pages adapte aux env_vars (secret_text), main.tf cable avec injection database_url + domain_map, tfvars et workflows CI a jour.
    Terraform n'est PAS installe dans l'environnement agent (blocker Phase 1) : cette validation est manuelle.
  </what-built>
  <how-to-verify>
    Depuis la racine du repo, executer (workspace dev, variables factices, init local sans backend R2) :

    1. cd terraform
    2. terraform init -backend=false
       (telecharge les providers cloudflare + supabase ; -backend=false evite d'avoir besoin des creds R2 pour un simple dry-run)
    3. terraform workspace new dev 2>/dev/null || terraform workspace select dev
    4. Lancer le plan avec des variables factices :
       TF_VAR_supabase_access_token=dummy-token \
       TF_VAR_supabase_org_id=dummy-org-slug \
       TF_VAR_db_password=DummyPassw0rd123 \
       TF_VAR_cloudflare_api_token=dummy \
       TF_VAR_cloudflare_account_id=3d32430d25b96e36682a9c025487c638 \
       TF_VAR_github_owner=mike-banner \
       TF_VAR_github_repo_name=Terraform-vtc-demo \
       terraform plan

    Resultats attendus :
    - Le plan affiche la creation de module.supabase_project.supabase_project.this (1 a creer)
    - Le plan affiche la creation de module.cloudflare_pages.cloudflare_pages_project.this avec deployment_configs
    - Dans le plan, la valeur DATABASE_URL et database_password apparaissent comme (sensitive value), jamais en clair
    - L'output database_url est marque (sensitive value)
    - terraform fmt -check -recursive ne signale aucun fichier (sinon lancer terraform fmt -recursive)

    Coller la sortie du plan (en-tete + section "Plan: X to add") dans la reponse.
  </how-to-verify>
  <resume-signal>Taper "approved" si le plan montre les 2 ressources et database_url masquee, sinon decrire l'erreur Terraform.</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Operateur/CI -> Terraform | Secrets (db_password, supabase_access_token) traversent en entree via TF_VAR_* |
| Terraform -> API Supabase | Provisionne le projet BDD, recoit le ref projet |
| Terraform -> API Cloudflare | Injecte database_url comme env var du projet Pages |
| Terraform -> backend R2 | Le tfstate (contenant database_url + db_password) est persiste |
| Cloudflare Pages -> runtime build | DATABASE_URL exposee aux builds via deployment_configs |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-03-01 | Information Disclosure | db_password / database_url dans le code ou tfvars | mitigate | sensitive=true sur variables et outputs ; AUCUN default sur les secrets ; tfvars ne contient que des valeurs non-sensibles (verifie par grep en Task 5) |
| T-03-02 | Information Disclosure | database_url cote Cloudflare Pages | mitigate | env_vars injectees en type="secret_text" (Task 3), jamais plain_text |
| T-03-03 | Information Disclosure | tfstate contient les secrets | accept | Backend R2 deja configure en Phase 1 comme seul acces ; aucun state local commite |
| T-03-04 | Spoofing | supabase_access_token compromis | mitigate | Stocke en GitHub Secret (SUPABASE_ACCESS_TOKEN), injecte via TF_VAR_* uniquement en CI, jamais en clair |
| T-03-05 | Elevation of Privilege | access token Supabase trop large | accept | Token de scope organisation requis par le provider ; rotation manuelle recommandee (hors scope IaC) |
| T-03-06 | Repudiation | apply Supabase non trace | accept | Audit via logs GitHub Actions (apply.yml) + GitOps strict (apply uniquement post-merge) |
| T-03-SC | Tampering | telechargement du provider supabase/supabase | mitigate | Version epinglee ~> 1.0, namespace officiel "supabase" sur registry.terraform.io ; providers Terraform hors gate npm/pip/cargo (pas de checkpoint requis) |
</threat_model>

<verification>
- terraform init -backend=false telecharge cloudflare ~> 5.0 ET supabase ~> 1.0 sans erreur
- terraform plan (workspace dev, vars factices) : Plan: 2 to add minimum (supabase_project + cloudflare_pages_project)
- Aucun secret en clair : DATABASE_URL et database_password = (sensitive value) dans le plan
- terraform fmt -check -recursive : aucun fichier non formate
- grep ne trouve aucun secret dans terraform.tfvars
</verification>

<success_criteria>
- Le module supabase_project cree un projet par workspace avec nom suffixe (vtc-demo-{workspace})
- database_url construite a partir du ref projet et du db_password, marquee sensitive partout
- Injection automatique de DATABASE_URL en secret_text dans Cloudflare Pages (production + preview)
- domain_map resout le domaine par workspace
- Aucun secret dans le code ni dans tfvars ; variables sensibles sans default
- plan.yml et apply.yml injectent les 3 nouveaux secrets Supabase de facon coherente
- Dry-run terraform plan valide l'arbre de dependances (Supabase avant Cloudflare)
</success_criteria>

<output>
Creer .planning/phases/03/03-PLAN-SUMMARY.md quand termine
</output>
