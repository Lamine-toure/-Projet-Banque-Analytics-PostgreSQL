-- =============================================================================
-- INDUSTRIALISATION - DATAMART + PROCÉDURES PL/pgSQL
-- =============================================================================
-- Batchs quotidiens  : Ex1 Q3 (risque dette), Ex1 Q4 (transactions secteur)
-- Batchs mensuels    : Ex1 Q8 (diversité cartes), Ex2 Q3 (RFM), Ex2 Q4 (VIP)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Création du schéma datamart
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS datamart;

-- =============================================================================
-- TABLES DU DATAMART
-- =============================================================================

-- -----------------------------------------------------------------------------
-- DM1 : Clients à risque (dette élevée) — batch QUOTIDIEN
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS datamart.dm_clients_risque CASCADE;

CREATE TABLE datamart.dm_clients_risque (
    id                  SERIAL          PRIMARY KEY,
    date_calcul         DATE            NOT NULL DEFAULT CURRENT_DATE,
    id_client           INT             NOT NULL,
    nom_complet         VARCHAR(200),
    salaire             DECIMAL(15,2),
    dette               DECIMAL(15,2),
    ratio_dette_salaire DECIMAL(10,4),
    niveau_dette        VARCHAR(20),
    UNIQUE (date_calcul, id_client)
);

CREATE INDEX idx_dm_risque_date   ON datamart.dm_clients_risque (date_calcul);
CREATE INDEX idx_dm_risque_niveau ON datamart.dm_clients_risque (niveau_dette);

-- -----------------------------------------------------------------------------
-- DM2 : Transactions par secteur — batch QUOTIDIEN
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS datamart.dm_transactions_secteur CASCADE;

CREATE TABLE datamart.dm_transactions_secteur (
    id              SERIAL          PRIMARY KEY,
    date_calcul     DATE            NOT NULL DEFAULT CURRENT_DATE,
    mcc_code        VARCHAR(20),
    secteur         VARCHAR(255),
    nb_transactions BIGINT,
    montant_moyen   DECIMAL(15,2),
    montant_total   DECIMAL(15,2),
    UNIQUE (date_calcul, mcc_code)
);

CREATE INDEX idx_dm_secteur_date ON datamart.dm_transactions_secteur (date_calcul);

-- -----------------------------------------------------------------------------
-- DM3 : Diversité des cartes — batch MENSUEL
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS datamart.dm_diversite_cartes CASCADE;

CREATE TABLE datamart.dm_diversite_cartes (
    id               SERIAL          PRIMARY KEY,
    annee_mois       VARCHAR(7)      NOT NULL,
    id_client        INT             NOT NULL,
    nb_cartes        INT,
    nb_marques       INT,
    nb_types         INT,
    ratio_diversite  DECIMAL(5,2),
    nb_transactions  BIGINT,
    niveau_diversite VARCHAR(20),
    UNIQUE (annee_mois, id_client)
);

CREATE INDEX idx_dm_diversite_mois ON datamart.dm_diversite_cartes (annee_mois);

-- -----------------------------------------------------------------------------
-- DM4 : Analyse RFM — batch MENSUEL
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS datamart.dm_rfm CASCADE;

CREATE TABLE datamart.dm_rfm (
    id               SERIAL          PRIMARY KEY,
    annee_mois       VARCHAR(7)      NOT NULL,
    id_client        INT             NOT NULL,
    recency_jours    INT,
    frequency        BIGINT,
    monetary         DECIMAL(15,2),
    recency_score    INT,
    frequency_score  INT,
    monetary_score   INT,
    rfm_score_global DECIMAL(5,2),
    segment          VARCHAR(30),
    UNIQUE (annee_mois, id_client)
);

CREATE INDEX idx_dm_rfm_mois    ON datamart.dm_rfm (annee_mois);
CREATE INDEX idx_dm_rfm_segment ON datamart.dm_rfm (segment);

-- -----------------------------------------------------------------------------
-- DM5 : Clients VIP — batch MENSUEL
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS datamart.dm_clients_vip CASCADE;

CREATE TABLE datamart.dm_clients_vip (
    id             SERIAL          PRIMARY KEY,
    annee_mois     VARCHAR(7)      NOT NULL,
    id_client      INT             NOT NULL,
    nom_complet    VARCHAR(200),
    montant_total  DECIMAL(15,2),
    pourcentage_ca DECIMAL(10,4),
    cumul_pct      DECIMAL(10,4),
    decile         INT,
    UNIQUE (annee_mois, id_client)
);

CREATE INDEX idx_dm_vip_mois ON datamart.dm_clients_vip (annee_mois);

-- =============================================================================
-- TABLE DE LOG DES BATCHS
-- =============================================================================
DROP TABLE IF EXISTS datamart.batch_log CASCADE;

CREATE TABLE datamart.batch_log (
    id          SERIAL          PRIMARY KEY,
    batch_name  VARCHAR(100)    NOT NULL,
    date_debut  TIMESTAMP       NOT NULL DEFAULT NOW(),
    date_fin    TIMESTAMP,
    statut      VARCHAR(20)     DEFAULT 'EN_COURS',
    nb_lignes   INT             DEFAULT 0,
    message     TEXT
);

-- =============================================================================
-- PROCÉDURES PL/pgSQL
-- =============================================================================

-- -----------------------------------------------------------------------------
-- PROC 1 : batch_clients_risque() — QUOTIDIEN
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE datamart.batch_clients_risque()
LANGUAGE plpgsql AS $$
DECLARE
    v_nb_lignes   INT := 0;
    v_log_id      INT;
    v_date_calcul DATE := CURRENT_DATE;
BEGIN
    INSERT INTO datamart.batch_log (batch_name, statut)
    VALUES ('batch_clients_risque', 'EN_COURS')
    RETURNING id INTO v_log_id;

    RAISE NOTICE '[%] Début batch_clients_risque pour %', NOW(), v_date_calcul;

    DELETE FROM datamart.dm_clients_risque
    WHERE date_calcul = v_date_calcul;

    INSERT INTO datamart.dm_clients_risque (
        date_calcul, id_client, nom_complet,
        salaire, dette, ratio_dette_salaire, niveau_dette
    )
    SELECT
        v_date_calcul,
        c.id_client,
        e.nom_complet,
        c.yearly_income,
        c.total_debt,
        ROUND(c.total_debt / NULLIF(c.yearly_income, 0), 4),
        CASE
            WHEN c.total_debt / NULLIF(c.yearly_income, 0) <= 0.50 THEN 'low'
            WHEN c.total_debt / NULLIF(c.yearly_income, 0) <= 1.00 THEN 'medium'
            WHEN c.total_debt / NULLIF(c.yearly_income, 0) <= 2.00 THEN 'high'
            WHEN c.total_debt / NULLIF(c.yearly_income, 0) <= 5.00 THEN 'ultra_high'
            ELSE 'UTP'
        END
    FROM clients c
    LEFT JOIN clients_ext e ON e.client_id = c.id_client;

    GET DIAGNOSTICS v_nb_lignes = ROW_COUNT;

    UPDATE datamart.batch_log
    SET date_fin  = NOW(),
        statut    = 'OK',
        nb_lignes = v_nb_lignes,
        message   = 'Calcul risque dette terminé'
    WHERE id = v_log_id;

    RAISE NOTICE '[%] batch_clients_risque terminé : % lignes insérées',
        NOW(), v_nb_lignes;

EXCEPTION WHEN OTHERS THEN
    UPDATE datamart.batch_log
    SET date_fin = NOW(), statut = 'ERREUR', message = SQLERRM
    WHERE id = v_log_id;
    RAISE;
END;
$$;

-- -----------------------------------------------------------------------------
-- PROC 2 : batch_transactions_secteur() — QUOTIDIEN
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE datamart.batch_transactions_secteur()
LANGUAGE plpgsql AS $$
DECLARE
    v_nb_lignes   INT := 0;
    v_log_id      INT;
    v_date_calcul DATE := CURRENT_DATE;
BEGIN
    INSERT INTO datamart.batch_log (batch_name, statut)
    VALUES ('batch_transactions_secteur', 'EN_COURS')
    RETURNING id INTO v_log_id;

    RAISE NOTICE '[%] Début batch_transactions_secteur pour %', NOW(), v_date_calcul;

    DELETE FROM datamart.dm_transactions_secteur
    WHERE date_calcul = v_date_calcul;

    INSERT INTO datamart.dm_transactions_secteur (
        date_calcul, mcc_code, secteur,
        nb_transactions, montant_moyen, montant_total
    )
    SELECT
        v_date_calcul,
        m.mcc_code,
        m.description,
        COUNT(t.id_transaction),
        ROUND(AVG(t.amount::NUMERIC), 2),
        ROUND(SUM(t.amount::NUMERIC), 2)
    FROM mcc_codes m
    LEFT JOIN transactions t ON t.mcc = m.mcc_code
    GROUP BY m.mcc_code, m.description;

    GET DIAGNOSTICS v_nb_lignes = ROW_COUNT;

    UPDATE datamart.batch_log
    SET date_fin  = NOW(),
        statut    = 'OK',
        nb_lignes = v_nb_lignes,
        message   = 'Stats secteurs calculées'
    WHERE id = v_log_id;

    RAISE NOTICE '[%] batch_transactions_secteur terminé : % lignes', NOW(), v_nb_lignes;

EXCEPTION WHEN OTHERS THEN
    UPDATE datamart.batch_log
    SET date_fin = NOW(), statut = 'ERREUR', message = SQLERRM
    WHERE id = v_log_id;
    RAISE;
END;
$$;

-- -----------------------------------------------------------------------------
-- PROC 3 : batch_diversite_cartes() — MENSUEL
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE datamart.batch_diversite_cartes()
LANGUAGE plpgsql AS $$
DECLARE
    v_nb_lignes  INT := 0;
    v_log_id     INT;
    v_annee_mois VARCHAR(7) := TO_CHAR(CURRENT_DATE, 'YYYY-MM');
BEGIN
    INSERT INTO datamart.batch_log (batch_name, statut)
    VALUES ('batch_diversite_cartes', 'EN_COURS')
    RETURNING id INTO v_log_id;

    RAISE NOTICE '[%] Début batch_diversite_cartes pour %', NOW(), v_annee_mois;

    DELETE FROM datamart.dm_diversite_cartes
    WHERE annee_mois = v_annee_mois;

    INSERT INTO datamart.dm_diversite_cartes (
        annee_mois, id_client, nb_cartes, nb_marques,
        nb_types, ratio_diversite, nb_transactions, niveau_diversite
    )
    WITH diversite AS (
        SELECT
            c.id_client,
            COUNT(DISTINCT ca.id)                           AS nb_cartes,
            COUNT(DISTINCT ca.card_brand)                   AS nb_marques,
            COUNT(DISTINCT ca.card_type)                    AS nb_types,
            ROUND(
                COUNT(DISTINCT ca.card_brand)::DECIMAL
                / NULLIF(COUNT(DISTINCT ca.id), 0), 2
            )                                               AS ratio_diversite
        FROM clients c
        LEFT JOIN cartes ca ON ca.id_client = c.id_client
        GROUP BY c.id_client
    ),
    tx_par_client AS (
        SELECT id_client, COUNT(*) AS nb_transactions
        FROM transactions
        GROUP BY id_client
    )
    SELECT
        v_annee_mois,
        d.id_client,
        d.nb_cartes,
        d.nb_marques,
        d.nb_types,
        d.ratio_diversite,
        COALESCE(tx.nb_transactions, 0),
        CASE
            WHEN d.ratio_diversite < 0.5 THEN 'faible'
            ELSE 'bonne'
        END
    FROM diversite d
    LEFT JOIN tx_par_client tx ON tx.id_client = d.id_client;

    GET DIAGNOSTICS v_nb_lignes = ROW_COUNT;

    UPDATE datamart.batch_log
    SET date_fin  = NOW(),
        statut    = 'OK',
        nb_lignes = v_nb_lignes,
        message   = 'Diversité cartes calculée pour ' || v_annee_mois
    WHERE id = v_log_id;

    RAISE NOTICE '[%] batch_diversite_cartes terminé : % lignes', NOW(), v_nb_lignes;

EXCEPTION WHEN OTHERS THEN
    UPDATE datamart.batch_log
    SET date_fin = NOW(), statut = 'ERREUR', message = SQLERRM
    WHERE id = v_log_id;
    RAISE;
END;
$$;

-- -----------------------------------------------------------------------------
-- PROC 4 : batch_rfm() — MENSUEL
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE datamart.batch_rfm()
LANGUAGE plpgsql AS $$
DECLARE
    v_nb_lignes  INT := 0;
    v_log_id     INT;
    v_annee_mois VARCHAR(7) := TO_CHAR(CURRENT_DATE, 'YYYY-MM');
BEGIN
    INSERT INTO datamart.batch_log (batch_name, statut)
    VALUES ('batch_rfm', 'EN_COURS')
    RETURNING id INTO v_log_id;

    RAISE NOTICE '[%] Début batch_rfm pour %', NOW(), v_annee_mois;

    DELETE FROM datamart.dm_rfm WHERE annee_mois = v_annee_mois;

    INSERT INTO datamart.dm_rfm (
        annee_mois, id_client, recency_jours, frequency, monetary,
        recency_score, frequency_score, monetary_score,
        rfm_score_global, segment
    )
    WITH rfm_base AS (
        SELECT
            id_client,
            MAX(date_transaction) AS derniere_transaction,
            COUNT(*)              AS frequency,
            SUM(amount)           AS monetary
        FROM transactions
        GROUP BY id_client
    ),
    date_max AS (
        SELECT MAX(date_transaction) AS date_ref FROM transactions
    ),
    rfm_scores AS (
        SELECT
            r.id_client,
            EXTRACT(DAY FROM (dm.date_ref - r.derniere_transaction))::INT AS recency_jours,
            r.frequency,
            r.monetary,
            5 - NTILE(4) OVER (ORDER BY r.derniere_transaction ASC)    AS recency_score,
            NTILE(4) OVER (ORDER BY r.frequency ASC)                   AS frequency_score,
            NTILE(4) OVER (ORDER BY r.monetary ASC)                    AS monetary_score
        FROM rfm_base r, date_max dm
    )
    SELECT
        v_annee_mois,
        id_client,
        recency_jours,
        frequency,
        ROUND(monetary::NUMERIC, 2),
        recency_score,
        frequency_score,
        monetary_score,
        ROUND((recency_score + frequency_score + monetary_score) / 3.0, 2),
        CASE
            WHEN recency_score = 4 AND frequency_score = 4 AND monetary_score = 4
                THEN 'Champion'
            WHEN recency_score >= 3 AND frequency_score >= 3
                THEN 'Loyal'
            WHEN recency_score = 4 AND frequency_score <= 2
                THEN 'Nouveau'
            WHEN recency_score <= 2 AND frequency_score >= 3
                THEN 'At Risk'
            WHEN recency_score = 1 AND frequency_score = 1
                THEN 'Perdu'
            ELSE 'Standard'
        END
    FROM rfm_scores;

    GET DIAGNOSTICS v_nb_lignes = ROW_COUNT;

    UPDATE datamart.batch_log
    SET date_fin  = NOW(),
        statut    = 'OK',
        nb_lignes = v_nb_lignes,
        message   = 'RFM calculé pour ' || v_annee_mois
    WHERE id = v_log_id;

    RAISE NOTICE '[%] batch_rfm terminé : % lignes', NOW(), v_nb_lignes;

EXCEPTION WHEN OTHERS THEN
    UPDATE datamart.batch_log
    SET date_fin = NOW(), statut = 'ERREUR', message = SQLERRM
    WHERE id = v_log_id;
    RAISE;
END;
$$;

-- -----------------------------------------------------------------------------
-- PROC 5 : batch_clients_vip() — MENSUEL
-- Correction : JOIN clients_ext déplacé dans une CTE dédiée "vip"
-- pour éviter l'erreur "invalid reference to FROM-clause entry"
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE datamart.batch_clients_vip()
LANGUAGE plpgsql AS $$
DECLARE
    v_nb_lignes  INT := 0;
    v_log_id     INT;
    v_annee_mois VARCHAR(7) := TO_CHAR(CURRENT_DATE, 'YYYY-MM');
BEGIN
    INSERT INTO datamart.batch_log (batch_name, statut)
    VALUES ('batch_clients_vip', 'EN_COURS')
    RETURNING id INTO v_log_id;

    RAISE NOTICE '[%] Début batch_clients_vip pour %', NOW(), v_annee_mois;

    DELETE FROM datamart.dm_clients_vip WHERE annee_mois = v_annee_mois;

    INSERT INTO datamart.dm_clients_vip (
        annee_mois, id_client, nom_complet,
        montant_total, pourcentage_ca, cumul_pct, decile
    )
    WITH montants AS (
        SELECT
            t.id_client,
            SUM(t.amount)                                AS montant_total,
            NTILE(10) OVER (ORDER BY SUM(t.amount) ASC) AS decile
        FROM transactions t
        GROUP BY t.id_client
    ),
    total_ca AS (
        SELECT SUM(montant_total) AS ca_total FROM montants
    ),
    -- CTE intermédiaire : isole les VIP et intègre le CA total
    -- pour permettre le LEFT JOIN sur clients_ext dans le SELECT final
    vip AS (
        SELECT
            m.id_client,
            m.montant_total,
            m.decile,
            t.ca_total
        FROM montants m
        CROSS JOIN total_ca t
        WHERE m.decile = 10
    )
    SELECT
        v_annee_mois,
        v.id_client,
        e.nom_complet,
        ROUND(v.montant_total::NUMERIC, 2),
        ROUND(v.montant_total / v.ca_total * 100, 4),
        ROUND(
            SUM(v.montant_total) OVER (
                ORDER BY v.montant_total DESC
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) / v.ca_total * 100, 4
        ),
        v.decile
    FROM vip v
    LEFT JOIN clients_ext e ON e.client_id = v.id_client
    ORDER BY v.montant_total DESC;

    GET DIAGNOSTICS v_nb_lignes = ROW_COUNT;

    UPDATE datamart.batch_log
    SET date_fin  = NOW(),
        statut    = 'OK',
        nb_lignes = v_nb_lignes,
        message   = 'VIP calculés pour ' || v_annee_mois
    WHERE id = v_log_id;

    RAISE NOTICE '[%] batch_clients_vip terminé : % lignes', NOW(), v_nb_lignes;

EXCEPTION WHEN OTHERS THEN
    UPDATE datamart.batch_log
    SET date_fin = NOW(), statut = 'ERREUR', message = SQLERRM
    WHERE id = v_log_id;
    RAISE;
END;
$$;

-- =============================================================================
-- PROCÉDURES MAÎTRES (orchestration)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- PROC MAÎTRE QUOTIDIENNE
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE datamart.run_daily_batch()
LANGUAGE plpgsql AS $$
DECLARE
    v_log_id INT;
BEGIN
    INSERT INTO datamart.batch_log (batch_name, statut)
    VALUES ('run_daily_batch', 'EN_COURS')
    RETURNING id INTO v_log_id;

    RAISE NOTICE '========================================';
    RAISE NOTICE '[%] LANCEMENT BATCH QUOTIDIEN', NOW();
    RAISE NOTICE '========================================';

    CALL datamart.batch_clients_risque();
    CALL datamart.batch_transactions_secteur();

    UPDATE datamart.batch_log
    SET date_fin = NOW(), statut = 'OK',
        message  = 'Tous les batchs quotidiens OK'
    WHERE id = v_log_id;

    RAISE NOTICE '========================================';
    RAISE NOTICE '[%] BATCH QUOTIDIEN TERMINÉ', NOW();
    RAISE NOTICE '========================================';

EXCEPTION WHEN OTHERS THEN
    UPDATE datamart.batch_log
    SET date_fin = NOW(), statut = 'ERREUR', message = SQLERRM
    WHERE id = v_log_id;
    RAISE;
END;
$$;

-- -----------------------------------------------------------------------------
-- PROC MAÎTRE MENSUELLE
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE datamart.run_monthly_batch()
LANGUAGE plpgsql AS $$
DECLARE
    v_log_id INT;
BEGIN
    INSERT INTO datamart.batch_log (batch_name, statut)
    VALUES ('run_monthly_batch', 'EN_COURS')
    RETURNING id INTO v_log_id;

    RAISE NOTICE '========================================';
    RAISE NOTICE '[%] LANCEMENT BATCH MENSUEL', NOW();
    RAISE NOTICE '========================================';

    CALL datamart.batch_diversite_cartes();
    CALL datamart.batch_rfm();
    CALL datamart.batch_clients_vip();

    UPDATE datamart.batch_log
    SET date_fin = NOW(), statut = 'OK',
        message  = 'Tous les batchs mensuels OK'
    WHERE id = v_log_id;

    RAISE NOTICE '========================================';
    RAISE NOTICE '[%] BATCH MENSUEL TERMINÉ', NOW();
    RAISE NOTICE '========================================';

EXCEPTION WHEN OTHERS THEN
    UPDATE datamart.batch_log
    SET date_fin = NOW(), statut = 'ERREUR', message = SQLERRM
    WHERE id = v_log_id;
    RAISE;
END;
$$;

-- =============================================================================
-- EXÉCUTION IMMÉDIATE DES BATCHS
-- =============================================================================
CALL datamart.run_daily_batch();
CALL datamart.run_monthly_batch();

-- =============================================================================
-- VÉRIFICATION FINALE
-- =============================================================================
DO $$
BEGIN
    RAISE NOTICE '=== ÉTAT FINAL DU DATAMART ===';
    RAISE NOTICE 'dm_clients_risque       : % lignes', (SELECT COUNT(*) FROM datamart.dm_clients_risque);
    RAISE NOTICE 'dm_transactions_secteur : % lignes', (SELECT COUNT(*) FROM datamart.dm_transactions_secteur);
    RAISE NOTICE 'dm_diversite_cartes     : % lignes', (SELECT COUNT(*) FROM datamart.dm_diversite_cartes);
    RAISE NOTICE 'dm_rfm                  : % lignes', (SELECT COUNT(*) FROM datamart.dm_rfm);
    RAISE NOTICE 'dm_clients_vip          : % lignes', (SELECT COUNT(*) FROM datamart.dm_clients_vip);
END $$;

SELECT batch_name, statut, nb_lignes, message
FROM datamart.batch_log
ORDER BY date_debut DESC
LIMIT 10;

