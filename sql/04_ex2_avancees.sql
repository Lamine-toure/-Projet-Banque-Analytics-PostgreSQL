-- =============================================================================
-- ANALYSES AVANCÉES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Évolution du comportement de dépense par client
-- Compare le montant moyen du 1er trimestre vs le dernier trimestre.
-- Limité aux clients ayant au moins 5 transactions par trimestre.
-- -----------------------------------------------------------------------------
WITH trimestriels AS (
    SELECT
        id_client,
        EXTRACT(quarter FROM date_transaction) AS trimestre,
        AVG(amount) AS montant_moyen,
        COUNT(*) AS nb_transactions
    FROM transactions
    GROUP BY id_client, EXTRACT(quarter FROM date_transaction)
),
t1 AS (
    SELECT
        id_client,
        montant_moyen,
        nb_transactions
    FROM trimestriels
    WHERE trimestre = 1
    AND nb_transactions >= 5
),
t4 AS (
    SELECT
        id_client,
        montant_moyen,
        nb_transactions
    FROM trimestriels
    WHERE trimestre = 4
    AND nb_transactions >= 5
)
SELECT
    t1.id_client,
    ROUND(t1.montant_moyen, 2) AS montant_moyen_qfirst,
    ROUND(t4.montant_moyen, 2) AS montant_moyen_qlast,
    ROUND(
        (t4.montant_moyen - t1.montant_moyen)
        / NULLIF(ABS(t1.montant_moyen), 0) * 100,
        2
    ) AS variation_pct
FROM t1
JOIN t4 USING (id_client)
ORDER BY variation_pct DESC;


-- -----------------------------------------------------------------------------
-- Détection d'anomalies de transactions
-- Transactions dont le montant dépasse de plus de 2 écarts-types
-- la moyenne des transactions du client (z_score > 2).
-- -----------------------------------------------------------------------------
WITH stats_client AS (
    SELECT
        id_client,
        AVG(amount)                                                  AS montant_moyen_client,
        STDDEV(amount)                                               AS ecart_type
    FROM transactions
    GROUP BY id_client
)
SELECT
    t.id_transaction,
    t.id_client,
    ROUND(t.amount::NUMERIC, 2)                                      AS montant,
    ROUND(s.montant_moyen_client::NUMERIC, 2)                        AS montant_moyen_client,
    ROUND(s.ecart_type::NUMERIC, 2)                                  AS ecart_type,
    ROUND(
        (t.amount - s.montant_moyen_client)
        / NULLIF(s.ecart_type, 0), 2
    )                                                                 AS z_score
FROM transactions t
JOIN stats_client s ON s.id_client = t.id_client
WHERE s.ecart_type > 0
    AND (t.amount - s.montant_moyen_client) / NULLIF(s.ecart_type, 0) > 2
ORDER BY z_score DESC
LIMIT 200;

-- -----------------------------------------------------------------------------
-- Analyse RFM (Recency, Frequency, Monetary)
-- Recency  : jours depuis la dernière transaction (4 = le plus récent)
-- Frequency: nombre total de transactions (4 = le plus fréquent)
-- Monetary : montant total dépensé (4 = le plus dépensier)
-- Segmentation en quartiles via NTILE(4).
-- -----------------------------------------------------------------------------
WITH rfm_base AS (
    SELECT
        id_client,
        MAX(date_transaction)                                         AS derniere_transaction,
        COUNT(*)                                                      AS frequency,
        SUM(amount)                                                   AS monetary
    FROM transactions
    GROUP BY id_client
),
date_max AS (
    SELECT MAX(date_transaction) AS date_ref FROM transactions
),
rfm_scores AS (
    SELECT
        r.id_client,
        (SELECT date_ref FROM date_max) - r.derniere_transaction      AS recency_jours,
        r.frequency,
        r.monetary,
        -- Recency : inversé (moins de jours = meilleur = score 4)
        5 - NTILE(4) OVER (ORDER BY r.derniere_transaction ASC)       AS recency_score,
        NTILE(4) OVER (ORDER BY r.frequency ASC)                      AS frequency_score,
        NTILE(4) OVER (ORDER BY r.monetary ASC)                       AS monetary_score
    FROM rfm_base r
)
SELECT
    id_client,
    recency_score,
    frequency_score,
    monetary_score,
    ROUND((recency_score + frequency_score + monetary_score) / 3.0, 2) AS rfm_score_global
FROM rfm_scores
ORDER BY rfm_score_global DESC;

-- -----------------------------------------------------------------------------
-- Clients VIP et leur contribution au chiffre d'affaires
-- VIP = top 10% par montant total dépensé.
-- Affiche montant, % du CA total, et cumul progressif.
-- -----------------------------------------------------------------------------
WITH montants AS (
    SELECT
        id_client,
        SUM(amount)                                                   AS montant_total
    FROM transactions
    GROUP BY id_client
),
total_ca AS (
    SELECT SUM(montant_total) AS ca_total FROM montants
),
vip AS (
    SELECT
        id_client,
        montant_total,
        NTILE(10) OVER (ORDER BY montant_total ASC)                   AS decile
    FROM montants
)
SELECT
    v.id_client,
    ROUND(v.montant_total::NUMERIC, 2)                                AS montant_total,
    ROUND(v.montant_total / t.ca_total * 100, 4)                      AS pourcentage_du_ca,
    ROUND(
        SUM(v.montant_total) OVER (
            ORDER BY v.montant_total DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) / t.ca_total * 100, 4
    )                                                                  AS cumul_pct
FROM vip v, total_ca t
WHERE v.decile = 10
ORDER BY v.montant_total DESC;

-- -----------------------------------------------------------------------------
-- Corrélation entre credit_score et montant moyen des transactions
-- Tranches de 300 points : 300-600, 600-900, 900+
-- Nombre de clients, montant moyen, médian, écart-type, nb transactions.
-- -----------------------------------------------------------------------------
WITH tranches AS (
    SELECT
        c.id_client,
        c.credit_score,
        CASE
            WHEN c.credit_score BETWEEN 300 AND 599 THEN '300-600'
            WHEN c.credit_score BETWEEN 600 AND 899 THEN '600-900'
            WHEN c.credit_score >= 900               THEN '900+'
            ELSE 'Autre'
        END                                                            AS tranche_score
    FROM clients c
)
SELECT
    tr.tranche_score,
    COUNT(DISTINCT tr.id_client)                                       AS nb_clients,
    ROUND(AVG(t.amount::NUMERIC), 2)                                   AS montant_moyen,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY t.amount::NUMERIC
    ), 2)                                                              AS montant_median,
    ROUND(STDDEV(t.amount::NUMERIC), 2)                                AS ecart_type,
    COUNT(t.id_transaction)                                            AS nb_transactions
FROM tranches tr
LEFT JOIN transactions t ON t.id_client = tr.id_client
GROUP BY tr.tranche_score
ORDER BY tr.tranche_score;

-- -----------------------------------------------------------------------------
-- Patterns de dépense par secteur et genre
-- Top 10 secteurs par genre selon le montant total.
-- Rang 1 = secteur préféré du genre.
-- -----------------------------------------------------------------------------
WITH stats AS (
    SELECT
        c.gender                                                       AS genre,
        m.description                                                  AS secteur,
        COUNT(t.id_transaction)                                        AS nb_transactions,
        ROUND(SUM(t.amount::NUMERIC), 2)                               AS montant_total,
        ROUND(AVG(t.amount::NUMERIC), 2)                               AS montant_moyen,
        RANK() OVER (
            PARTITION BY c.gender
            ORDER BY SUM(t.amount) DESC
        )                                                              AS rang
    FROM transactions t
    JOIN clients c     ON c.id_client = t.id_client
    LEFT JOIN mcc_codes m ON m.mcc_code = t.mcc
    GROUP BY c.gender, m.description
)
SELECT
    genre,
    secteur,
    nb_transactions,
    montant_total,
    montant_moyen,
    rang
FROM stats
WHERE rang <= 10
ORDER BY genre, rang;

-- -----------------------------------------------------------------------------
-- Clients avec comportement de dépense croissant
-- Identifie les clients dont la moyenne mensuelle augmente
-- sur au moins 3 mois consécutifs.
-- -----------------------------------------------------------------------------
WITH mensuel AS (
    SELECT
        id_client,
        DATE_TRUNC('month', date_transaction)                          AS mois,
        AVG(amount)                                                    AS montant_moyen_mois
    FROM transactions
    GROUP BY id_client, DATE_TRUNC('month', date_transaction)
),
avec_tendance AS (
    SELECT
        id_client,
        mois,
        ROUND(montant_moyen_mois::NUMERIC, 2)                          AS montant_moyen_mois,
        LAG(montant_moyen_mois) OVER (
            PARTITION BY id_client ORDER BY mois
        )                                                              AS mois_precedent,
        CASE
            WHEN montant_moyen_mois > LAG(montant_moyen_mois) OVER (
                PARTITION BY id_client ORDER BY mois
            ) THEN 'croissante'
            WHEN montant_moyen_mois = LAG(montant_moyen_mois) OVER (
                PARTITION BY id_client ORDER BY mois
            ) THEN 'stable'
            ELSE 'decroissante'
        END                                                            AS tendance
    FROM mensuel
),
clients_croissants AS (
    SELECT DISTINCT id_client
    FROM (
        SELECT
            id_client,
            mois,
            tendance,
            COUNT(*) FILTER (WHERE tendance = 'croissante') OVER (
                PARTITION BY id_client
                ORDER BY mois
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            )                                                          AS nb_croissants_consecutifs
        FROM avec_tendance
    ) sub
    WHERE nb_croissants_consecutifs >= 3
)
SELECT
    t.id_client,
    t.mois,
    t.montant_moyen_mois,
    t.tendance
FROM avec_tendance t
WHERE t.id_client IN (SELECT id_client FROM clients_croissants)
ORDER BY t.id_client, t.mois;

-- -----------------------------------------------------------------------------
-- Analyse de la diversité des cartes par client
-- Diversité = nb marques / nb cartes.
-- Clients à faible diversité : ratio < 0.5
-- -----------------------------------------------------------------------------
WITH diversite AS (
    SELECT
        c.id_client,
        COUNT(DISTINCT ca.id)                                          AS nb_cartes,
        COUNT(DISTINCT ca.card_brand)                                  AS nb_marques,
        COUNT(DISTINCT ca.card_type)                                   AS nb_types,
        ROUND(
            COUNT(DISTINCT ca.card_brand)::DECIMAL
            / NULLIF(COUNT(DISTINCT ca.id), 0), 2
        )                                                              AS ratio_diversite
    FROM clients c
    LEFT JOIN cartes ca ON ca.id_client = c.id_client
    GROUP BY c.id_client
),
transactions_par_carte AS (
    SELECT
        card_id,
        COUNT(*)                                                       AS nb_transactions_carte
    FROM transactions
    GROUP BY card_id
)
SELECT
    d.id_client,
    d.nb_cartes,
    d.nb_marques,
    d.nb_types,
    d.ratio_diversite,
    COALESCE(SUM(tpc.nb_transactions_carte), 0)                        AS nb_transactions_total,
    CASE
        WHEN d.ratio_diversite < 0.5 THEN 'faible diversité'
        ELSE 'bonne diversité'
    END                                                                AS niveau_diversite
FROM diversite d
LEFT JOIN cartes ca2    ON ca2.id_client = d.id_client
LEFT JOIN transactions_par_carte tpc ON tpc.card_id = ca2.id
GROUP BY d.id_client, d.nb_cartes, d.nb_marques, d.nb_types, d.ratio_diversite
ORDER BY d.ratio_diversite ASC;

-- -----------------------------------------------------------------------------
-- Prédiction de churn : clients inactifs
-- Critères :
--   1. Pas de transaction depuis > 90 jours (vs date max du dataset)
--   2. Baisse de > 30% du montant moyen mensuel entre
--      les 3 derniers mois actifs vs les 3 mois précédents
-- -----------------------------------------------------------------------------
WITH date_max AS (
    SELECT MAX(date_transaction) AS date_ref FROM transactions
),
derniere_transaction AS (
    SELECT
        id_client,
        MAX(date_transaction)                                          AS derniere_tx
    FROM transactions
    GROUP BY id_client
),
inactifs AS (
    SELECT
        d.id_client,
        d.derniere_tx,
        EXTRACT(DAY FROM (dm.date_ref - d.derniere_tx))::INT           AS jours_inactivite
    FROM derniere_transaction d, date_max dm
    WHERE dm.date_ref - d.derniere_tx > INTERVAL '90 days'
),
mensuel AS (
    SELECT
        id_client,
        DATE_TRUNC('month', date_transaction)                          AS mois,
        AVG(amount)                                                    AS montant_moyen_mois
    FROM transactions
    GROUP BY id_client, DATE_TRUNC('month', date_transaction)
),
mois_classes AS (
    SELECT
        m.id_client,
        m.mois,
        m.montant_moyen_mois,
        ROW_NUMBER() OVER (
            PARTITION BY m.id_client ORDER BY m.mois DESC
        )                                                              AS rang_mois
    FROM mensuel m
    WHERE m.id_client IN (SELECT id_client FROM inactifs)
),
periode_recente AS (
    SELECT id_client, AVG(montant_moyen_mois) AS montant_recent
    FROM mois_classes
    WHERE rang_mois BETWEEN 1 AND 3
    GROUP BY id_client
),
periode_ancienne AS (
    SELECT id_client, AVG(montant_moyen_mois) AS montant_ancien
    FROM mois_classes
    WHERE rang_mois BETWEEN 4 AND 6
    GROUP BY id_client
)
SELECT
    i.id_client,
    i.derniere_tx                                                      AS derniere_transaction,
    i.jours_inactivite,
    ROUND(r.montant_recent::NUMERIC, 2)                                AS montant_moyen_recent,
    ROUND(a.montant_ancien::NUMERIC, 2)                                AS montant_moyen_ancien,
    ROUND(
        (r.montant_recent - a.montant_ancien)
        / NULLIF(ABS(a.montant_ancien), 0) * 100, 2
    )                                                                  AS variation_pct
FROM inactifs i
JOIN periode_recente  r ON r.id_client = i.id_client
JOIN periode_ancienne a ON a.id_client = i.id_client
WHERE (r.montant_recent - a.montant_ancien)
      / NULLIF(ABS(a.montant_ancien), 0) * 100 < -30
ORDER BY i.jours_inactivite DESC;