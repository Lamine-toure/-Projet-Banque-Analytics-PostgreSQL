-- =============================================================================
-- CONCEPTION DE LA BASE DE DONNÉES
-- Description : Création des tables, clés primaires, index et partitions
-- =============================================================================

-- On force l'encodage UTF-8
SET client_encoding = 'UTF8';

-- =============================================================================
-- NETTOYAGE (si re-exécution)
-- =============================================================================
DROP TABLE IF EXISTS transactions  CASCADE;
DROP TABLE IF EXISTS cartes        CASCADE;
DROP TABLE IF EXISTS clients       CASCADE;
DROP TABLE IF EXISTS marchands     CASCADE;
DROP TABLE IF EXISTS mcc_codes     CASCADE;

-- =============================================================================
-- TABLE : MCC_CODES (référentiel des secteurs d'activité)
-- =============================================================================
CREATE TABLE mcc_codes (
    mcc_code    VARCHAR(20)  NOT NULL,
    description VARCHAR(255) NOT NULL,
    CONSTRAINT pk_mcc PRIMARY KEY (mcc_code)
);

-- =============================================================================
-- TABLE : CLIENTS
-- Contient les informations personnelles et financières des clients.
-- =============================================================================
CREATE TABLE clients (
    id_client           INT             PRIMARY KEY,
    current_age         INT,
    retirement_age      INT,
    birth_year          INT,
    birth_month         INT,
    gender              VARCHAR(20),
    adresse             TEXT,
    latitude            DECIMAL(9,6),
    longitude           DECIMAL(9,6),
    per_capita_income   DECIMAL(15,2),
    yearly_income       DECIMAL(15,2),
    total_debt          DECIMAL(15,2),
    credit_score        INT,
    num_credit_cards    INT
);

-- INDEX sur CLIENTS :
-- credit_score : très souvent filtré dans les analyses de risque 
-- genre        : utilisé dans les analyses par genre 
CREATE INDEX idx_clients_credit_score ON clients (credit_score);
CREATE INDEX idx_clients_genre        ON clients (gender);

-- =============================================================================
-- TABLE : CARTES (partitionnée par card_brand)
-- Le partitionnement par marque (Visa, Mastercard, Amex, Discover)
-- car les analyses comparent souvent les comportements par marque, et cela permet
-- un pruning automatique des partitions lors des filtres sur card_brand.
-- =============================================================================
CREATE TABLE cartes (
    id                    INT             NOT NULL,
    id_client             INT             NOT NULL,
    card_brand            VARCHAR(50)     NOT NULL,
    card_type             VARCHAR(50),
    card_number           BIGINT,
    expires               VARCHAR(10),
    cvv                   INT,
    has_chip              BOOLEAN,
    num_cards_issued      INT,
    credit_limit          DECIMAL(15,2),
    acct_open_date        DATE,
    year_pin_last_changed INT,
    card_on_dark_web      BOOLEAN,
    CONSTRAINT pk_cartes PRIMARY KEY (id, card_brand)
) PARTITION BY LIST (card_brand);

-- Partitionnement par marque
CREATE TABLE cartes_visa       PARTITION OF cartes FOR VALUES IN ('Visa');
CREATE TABLE cartes_mastercard PARTITION OF cartes FOR VALUES IN ('Mastercard');
CREATE TABLE cartes_amex       PARTITION OF cartes FOR VALUES IN ('Amex');
CREATE TABLE cartes_discover   PARTITION OF cartes FOR VALUES IN ('Discover');
CREATE TABLE cartes_autres     PARTITION OF cartes DEFAULT;

-- INDEX sur CARTES :
-- id_client  : jointure très fréquente avec la table clients
-- card_type  : filtres fréquents Debit vs Credit dans les analyses
CREATE INDEX idx_cartes_id_client  ON cartes (id_client);
CREATE INDEX idx_cartes_card_type  ON cartes (card_type);

-- =============================================================================
-- TABLE : MARCHANDS
-- Référentiel des marchands (merchant_city, merchant_state, mcc, zip).
-- Dédupliqué depuis les transactions pour éviter la répétition.
-- =============================================================================
CREATE TABLE marchands (
    id_marchand     SERIAL          PRIMARY KEY,
    merchant_id     BIGINT          UNIQUE,
    merchant_city   VARCHAR(100),
    merchant_state  VARCHAR(100),
    zip             VARCHAR(20),
    mcc             VARCHAR(20),
    CONSTRAINT fk_marchand_mcc FOREIGN KEY (mcc) REFERENCES mcc_codes (mcc_code)
);

-- INDEX sur MARCHANDS :
-- merchant_city  : filtres géographiques fréquents (Ex1 Q9 - villes les plus actives)
-- mcc            : jointure avec mcc_codes pour les analyses par secteur (Ex1 Q4)
CREATE INDEX idx_marchands_city ON marchands (merchant_city);
CREATE INDEX idx_marchands_mcc  ON marchands (mcc);

-- =============================================================================
-- TABLE : TRANSACTIONS (partitionnée par période / année)
-- Le partitionnement par année sur la date de transaction est le choix le plus
-- naturel : les analyses temporelles (Q1, Q2, Q3 de l'Ex2) bénéficient du pruning
-- par date, et les batchs quotidiens/mensuels n'écrivent que dans la partition
-- de l'année courante.
-- =============================================================================
CREATE TABLE transactions (
    id_transaction      BIGINT          NOT NULL,
    id_client           INT             NOT NULL,
    card_id             INT             NOT NULL,
    id_marchand         INT,
    date_transaction    TIMESTAMP       NOT NULL,
    amount              DECIMAL(12,3)   NOT NULL,
    use_chip            VARCHAR(50),
    merchant_city       VARCHAR(100),
    merchant_state      VARCHAR(100),
    zip                 VARCHAR(20),
    mcc                 VARCHAR(20),
    errors              TEXT,
    is_fraud            BOOLEAN         DEFAULT FALSE,
    CONSTRAINT pk_transactions PRIMARY KEY (id_transaction, date_transaction)
) PARTITION BY RANGE (date_transaction);

-- Partitions par année (les données couvrent généralement 2010-2020)
CREATE TABLE transactions_2010 PARTITION OF transactions
    FOR VALUES FROM ('2010-01-01') TO ('2011-01-01');
CREATE TABLE transactions_2011 PARTITION OF transactions
    FOR VALUES FROM ('2011-01-01') TO ('2012-01-01');
CREATE TABLE transactions_2012 PARTITION OF transactions
    FOR VALUES FROM ('2012-01-01') TO ('2013-01-01');
CREATE TABLE transactions_2013 PARTITION OF transactions
    FOR VALUES FROM ('2013-01-01') TO ('2014-01-01');
CREATE TABLE transactions_2014 PARTITION OF transactions
    FOR VALUES FROM ('2014-01-01') TO ('2015-01-01');
CREATE TABLE transactions_2015 PARTITION OF transactions
    FOR VALUES FROM ('2015-01-01') TO ('2016-01-01');
CREATE TABLE transactions_2016 PARTITION OF transactions
    FOR VALUES FROM ('2016-01-01') TO ('2017-01-01');
CREATE TABLE transactions_2017 PARTITION OF transactions
    FOR VALUES FROM ('2017-01-01') TO ('2018-01-01');
CREATE TABLE transactions_2018 PARTITION OF transactions
    FOR VALUES FROM ('2018-01-01') TO ('2019-01-01');
CREATE TABLE transactions_2019 PARTITION OF transactions
    FOR VALUES FROM ('2019-01-01') TO ('2020-01-01');
CREATE TABLE transactions_2020 PARTITION OF transactions
    FOR VALUES FROM ('2020-01-01') TO ('2021-01-01');
CREATE TABLE transactions_another_year PARTITION OF transactions DEFAULT;

-- INDEX sur TRANSACTIONS :
-- id_client        : jointure centrale avec clients pour toutes les analyses par client
-- date_transaction : filtres temporels dans presque toutes les analyses avancées
CREATE INDEX idx_transactions_id_client        ON transactions (id_client);
CREATE INDEX idx_transactions_date_transaction ON transactions (date_transaction);

-- =============================================================================
-- CONTRAINTES DE CLÉ ÉTRANGÈRE
-- =============================================================================
ALTER TABLE cartes
    ADD CONSTRAINT fk_cartes_client
    FOREIGN KEY (id_client) REFERENCES clients (id_client);

ALTER TABLE transactions
    ADD CONSTRAINT fk_transactions_client
    FOREIGN KEY (id_client) REFERENCES clients (id_client);

-- Note : FK vers cartes et marchands non activée car les données peuvent avoir
-- des transactions sans carte correspondante dans le fichier partiel fourni.

-- =============================================================================
-- FIN DU FICHIER 00_schema.sql
-- =============================================================================