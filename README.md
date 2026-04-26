# 🏦 Projet Banque Analytics — PostgreSQL

Projet d'analyse de données bancaires sur PostgreSQL, containerisé avec Docker.
Il couvre la modélisation d'une base de données, l'analyse SQL avancée et l'industrialisation via PL/pgSQL.

---

## 📁 Structure du projet

```
Projet2_Banque-Analyse/
├── docker-compose.yml          # Configuration Docker
├── .env                        # Variables d'environnement (non versionné)
├── .env.example                # Template des variables
├── .gitignore
├── data/                       # Fichiers CSV/JSON (non versionnés)
│   ├── users_data.csv
│   ├── users_ext.csv
│   ├── cards_data.csv
│   ├── transactions_data.csv
│   ├── mcc_codes.json
│   └── train_fraud_labels.json
└── sql/
    ├── 00_schema.sql           # Tables, partitions, index, clés
    ├── 01_load_data.sql        # Chargement des données CSV
    ├── 02_clients_ext.sql      # Table étendue + vue clients_full
    ├── 03_ex1_analyses.sql     # Exercice 1 : 10 requêtes d'analyse
    ├── 04_ex2_avancees.sql     # Exercice 2 : 9 requêtes avancées
    └── 05_ex3_plsql.sql        # Exercice 3 : Datamart + PL/pgSQL
```

---

## 🗃️ Dataset

Source : [Kaggle — Transactions Fraud Datasets](https://www.kaggle.com/datasets/computingvictor/transactions-fraud-datasets)

| Fichier | Description | Lignes |
|---------|-------------|--------|
| `users_data.csv` | Informations financières des clients | 2 000 |
| `users_ext.csv` | Informations personnelles étendues | 6 000 |
| `cards_data.csv` | Cartes bancaires | 6 146 |
| `transactions_data.csv` | Transactions bancaires | 13 305 915 |
| `mcc_codes.json` | Codes MCC (secteurs d'activité) | 109 |
| `train_fraud_labels.json` | Labels de fraude | 8 914 963 |

---

## 🚀 Installation et démarrage

### Prérequis

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Git Bash](https://git-scm.com/) (Windows) ou terminal Linux/Mac
- Python 3.x + pip (pour le script d'enrichissement)

### 1. Cloner le projet

```bash
git clone https://github.com/votre-username/Projet2_Banque-Analyse.git
cd Projet2_Banque-Analyse
```

### 2. Configurer les variables d'environnement

```bash
cp .env.example .env
# Éditez .env avec vos valeurs
```

### 3. Télécharger les données

Téléchargez les fichiers depuis [Kaggle](https://www.kaggle.com/datasets/computingvictor/transactions-fraud-datasets) et placez-les dans le dossier `data/`.

### 4. Démarrer les containers

```bash
docker compose up -d
docker ps  # Vérifiez que banqueanalytics2 et pgadmin2 tournent
```

### 5. Initialiser la base de données

```bash
# Création du schéma
docker exec -i banqueanalytics2 psql -U lamine -d banqueanalytics2 < sql/00_schema.sql

# Chargement des données (~10 min pour 13M de transactions)
docker exec -i banqueanalytics2 psql -U lamine -d banqueanalytics2 < sql/01_load_data.sql

# Données clients enrichies
docker exec -i banqueanalytics2 psql -U lamine -d banqueanalytics2 < sql/02_clients_ext.sql

# Datamart + procédures PL/pgSQL
docker exec -i banqueanalytics2 psql -U lamine -d banqueanalytics2 < sql/05_ex3_plsql.sql
```

---

## 🔌 Connexion aux outils

### pgAdmin
```
URL      : http://localhost:8081
Email    : voir .env (PGADMIN_EMAIL)
Password : voir .env (PGADMIN_PASSWORD)
```

Ajouter un serveur dans pgAdmin :
```
Host     : banqueanalytics2
Port     : 5432
Database : banqueanalytics2
Username : voir .env (POSTGRES_USER)
```

### SQLTools / DBeaver / psql
```
Host     : localhost
Port     : 5433
Database : banqueanalytics2
Username : voir .env (POSTGRES_USER)
```

---

## 📐 Modèle de données

```
clients (2 000)
    │
    ├──< cartes (6 146)          [partitionnée par card_brand]
    │       Visa | Mastercard | Amex | Discover
    │
    ├──< transactions (13 305 915) [partitionnée par année]
    │       2010 | 2011 | ... | 2020
    │       │
    │       └──> marchands (74 831)
    │                 │
    │                 └──> mcc_codes (109)
    │
    └──< clients_ext (2 000)     [données personnelles étendues]

Vue : clients_full = clients ⋈ clients_ext
```

### Partitionnement

| Table | Type | Partitions |
|-------|------|------------|
| `cartes` | LIST (card_brand) | Visa, Mastercard, Amex, Discover, Autres |
| `transactions` | RANGE (date) | 2010 à 2020 + défaut |

### Index

| Table | Colonnes indexées | Justification |
|-------|-------------------|---------------|
| `clients` | `credit_score`, `gender` | Filtres fréquents dans les analyses de risque |
| `cartes` | `id_client`, `card_type` | Jointures et filtres Debit/Credit |
| `marchands` | `merchant_city`, `mcc` | Analyses géographiques et par secteur |
| `transactions` | `id_client`, `date_transaction` | Jointures et filtres temporels |

---

## 📊 Exercice 1 — Analyses Clients & Transactions

| # | Requête | Technique |
|---|---------|-----------|
| Q1 | Clients et nombre de cartes | `LEFT JOIN` + `COUNT` + `GROUP BY` |
| Q2 | Montant total par client | `SUM` + `ORDER BY` + `LIMIT` |
| Q3 | Clients à risque (dette) | `CASE WHEN` ratio dette/salaire |
| Q4 | Transactions par secteur MCC | `LEFT JOIN mcc_codes` + agrégats |
| Q5 | Cartes les plus utilisées | `GROUP BY card_id` |
| Q6 | Clients par nationalité | `GROUP BY nationalite` |
| Q7 | Transactions par type et secteur | Double `GROUP BY` + `ORDER BY` |
| Q8 | Clients sans transactions | `LEFT JOIN` + `WHERE IS NULL` |
| Q9 | Top 5 villes actives | `GROUP BY merchant_city` + `LIMIT 5` |
| Q10 | Analyse par genre | `COUNT DISTINCT` + `SUM` |

---

## 🔬 Exercice 2 — Analyses Avancées

| # | Requête | Technique |
|---|---------|-----------|
| Q1 | Évolution dépenses par trimestre | `DATE_TRUNC('quarter')` + `DISTINCT ON` |
| Q2 | Détection d'anomalies (z-score) | `STDDEV` + z-score `(x-μ)/σ` |
| Q3 | Analyse RFM | `NTILE(4)` quartiles |
| Q4 | Clients VIP (top 10%) | `NTILE(10)` + cumul `SUM OVER` |
| Q5 | Corrélation credit_score | `PERCENTILE_CONT(0.5)` médiane |
| Q6 | Patterns par secteur et genre | `RANK() OVER (PARTITION BY)` |
| Q7 | Dépenses croissantes | `LAG()` + fenêtre glissante |
| Q8 | Diversité des cartes | `COUNT(DISTINCT)` multi-colonnes |
| Q9 | Prédiction churn | `ROW_NUMBER()` + double CTE |

---

## ⚙️ Exercice 3 — Industrialisation (Datamart)

### Tables du datamart

| Table | Source | Fréquence |
|-------|--------|-----------|
| `datamart.dm_clients_risque` | Ex1 Q3 | **Quotidien** |
| `datamart.dm_transactions_secteur` | Ex1 Q4 | **Quotidien** |
| `datamart.dm_diversite_cartes` | Ex1 Q8 | **Mensuel** |
| `datamart.dm_rfm` | Ex2 Q3 | **Mensuel** |
| `datamart.dm_clients_vip` | Ex2 Q4 | **Mensuel** |

### Lancer les batchs manuellement

```bash
# Batch quotidien
docker exec -it banqueanalytics2 psql -U lamine -d banqueanalytics2 \
    -c "CALL datamart.run_daily_batch();"

# Batch mensuel
docker exec -it banqueanalytics2 psql -U lamine -d banqueanalytics2 \
    -c "CALL datamart.run_monthly_batch();"

# Consulter l'historique des batchs
docker exec -it banqueanalytics2 psql -U lamine -d banqueanalytics2 \
    -c "SELECT batch_name, statut, nb_lignes, date_debut FROM datamart.batch_log ORDER BY date_debut DESC LIMIT 10;"
```

### Segmentation RFM

| Segment | Condition |
|---------|-----------|
| Champion | R=4, F=4, M=4 |
| Loyal | R≥3, F≥3 |
| Nouveau | R=4, F≤2 |
| At Risk | R≤2, F≥3 |
| Perdu | R=1, F=1 |
| Standard | Autres |

---

## 🔒 Sécurité

Les mots de passe et données sensibles sont gérés via un fichier `.env` **jamais versionné**.

```bash
# .env.example (à copier en .env)
POSTGRES_DB=banqueanalytics2
POSTGRES_USER=votre_user
POSTGRES_PASSWORD=votre_mot_de_passe
PGADMIN_EMAIL=votre_email
PGADMIN_PASSWORD=votre_mot_de_passe_pgadmin
DB_PORT=5433
```

---

## 🛠️ Technologies

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?logo=postgresql&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.x-3776AB?logo=python&logoColor=white)

- **PostgreSQL 16** — Base de données avec partitionnement natif
- **Docker Compose** — Containerisation (PostgreSQL + pgAdmin)
- **PL/pgSQL** — Procédures stockées et batchs
- **Python + Faker** — Génération de données synthétiques réalistes

---

## 👨‍💻 Auteur

**Lamine Touré**
