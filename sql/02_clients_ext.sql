-- =============================================================================
-- INTÉGRATION DES DONNÉES ÉTENDUES CLIENTS (users_ext.csv)
-- =============================================================================
-- Ce fichier crée une table clients_ext reliée à clients par client_id,
-- charge les données depuis le CSV, puis crée une vue jointe pour les analyses.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Création de la table clients_ext
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS clients_ext CASCADE;

CREATE TABLE clients_ext (
    client_id             INT             PRIMARY KEY,
    gender                VARCHAR(10),
    nationalite           VARCHAR(100),
    title                 VARCHAR(10),
    given_name            VARCHAR(100),
    middle_initial        VARCHAR(10),
    surname               VARCHAR(100),
    nom_complet           VARCHAR(200)    GENERATED ALWAYS AS (given_name || ' ' || surname) STORED,
    street_address        VARCHAR(200),
    city                  VARCHAR(100),
    region                VARCHAR(10),
    region_full           VARCHAR(100),
    zip_code              VARCHAR(20),
    country               VARCHAR(10),
    country_full          VARCHAR(100),
    email                 VARCHAR(150),
    telephone             VARCHAR(50),
    telephone_country_code INT,
    birthday              DATE,
    age                   INT,
    national_id           VARCHAR(50),
    occupation            VARCHAR(150),
    company               VARCHAR(150),
    latitude              DECIMAL(9,6),
    longitude             DECIMAL(9,6),
    CONSTRAINT fk_clients_ext_client
        FOREIGN KEY (client_id) REFERENCES clients (id_client)
);

-- INDEX utiles pour les analyses
CREATE INDEX idx_clients_ext_nationalite ON clients_ext (nationalite);
CREATE INDEX idx_clients_ext_country     ON clients_ext (country);
CREATE INDEX idx_clients_ext_occupation  ON clients_ext (occupation);

-- -----------------------------------------------------------------------------
-- Chargement via table staging
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE clients_ext_staging (
    client_id             INT,
    gender                VARCHAR(10),
    nationalite           VARCHAR(100),
    title                 VARCHAR(10),
    given_name            VARCHAR(100),
    middle_initial        VARCHAR(10),
    surname               VARCHAR(100),
    street_address        VARCHAR(200),
    city                  VARCHAR(100),
    region                VARCHAR(10),
    region_full           VARCHAR(100),
    zip_code              VARCHAR(20),
    country               VARCHAR(10),
    country_full          VARCHAR(100),
    email                 VARCHAR(150),
    telephone             VARCHAR(50),
    telephone_country_code INT,
    birthday              VARCHAR(20),   -- format MM/DD/YYYY -> converti en DATE
    age                   INT,
    national_id           VARCHAR(50),
    occupation            VARCHAR(150),
    company               VARCHAR(150),
    latitude              DECIMAL(9,6),
    longitude             DECIMAL(9,6)
);

COPY clients_ext_staging (
    client_id, gender, nationalite, title, given_name, middle_initial, surname,
    street_address, city, region, region_full, zip_code, country, country_full,
    email, telephone, telephone_country_code, birthday, age, national_id,
    occupation, company, latitude, longitude
)
FROM '/data/users_ext.csv'
    WITH (FORMAT csv, HEADER true, DELIMITER ',');

INSERT INTO clients_ext (
    client_id, gender, nationalite, title, given_name, middle_initial, surname,
    street_address, city, region, region_full, zip_code, country, country_full,
    email, telephone, telephone_country_code, birthday, age, national_id,
    occupation, company, latitude, longitude
)
SELECT
    client_id,
    gender,
    nationalite,
    title,
    given_name,
    middle_initial,
    surname,
    street_address,
    city,
    region,
    region_full,
    zip_code,
    country,
    country_full,
    email,
    telephone,
    telephone_country_code,
    -- Conversion date MM/DD/YYYY -> DATE
    TO_DATE(birthday, 'MM/DD/YYYY'),
    age,
    NULLIF(national_id, ''),
    occupation,
    company,
    latitude,
    longitude
FROM clients_ext_staging
-- On ne garde que les client_id qui existent dans clients
WHERE client_id IN (SELECT id_client FROM clients);

DROP TABLE clients_ext_staging;

-- -----------------------------------------------------------------------------
-- Vue jointe clients_full pour simplifier les requêtes
-- Cette vue remplace les jointures répétitives dans les analyses
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS clients_full;

CREATE VIEW clients_full AS
SELECT
    c.id_client,
    -- Infos étendues (depuis clients_ext)
    e.nom_complet,
    e.given_name                        AS prenom,
    e.surname                           AS nom,
    e.nationalite,
    e.country_full                      AS pays,
    e.occupation,
    e.company,
    e.email,
    e.birthday                          AS date_naissance,
    e.age,
    -- Infos financières (depuis clients)
    c.gender,
    c.yearly_income                     AS salaire,
    c.total_debt                        AS dette,
    c.credit_score,
    c.num_credit_cards                  AS nb_cartes,
    c.per_capita_income,
    -- Localisation originale
    c.adresse,
    c.latitude,
    c.longitude
FROM clients c
LEFT JOIN clients_ext e ON e.client_id = c.id_client;

-- -----------------------------------------------------------------------------
-- VÉRIFICATION
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE '=== VÉRIFICATION clients_ext ===';
    RAISE NOTICE 'Lignes chargées : %', (SELECT COUNT(*) FROM clients_ext);
    RAISE NOTICE 'Avec nom complet : %', (SELECT COUNT(*) FROM clients_ext WHERE nom_complet IS NOT NULL);
    RAISE NOTICE 'Nationalités distinctes : %', (SELECT COUNT(DISTINCT nationalite) FROM clients_ext);
    RAISE NOTICE 'Pays distincts : %', (SELECT COUNT(DISTINCT country_full) FROM clients_ext);
END $$;
