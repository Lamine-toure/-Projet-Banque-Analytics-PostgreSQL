-- =============================================================================
-- CHARGEMENT DES DONNÉES
-- =============================================================================
SET client_encoding = 'UTF8';

-- =============================================================================
-- 1. CHARGEMENT DES MCC CODES
-- =============================================================================
INSERT INTO mcc_codes (mcc_code, description) VALUES
('5812', 'Eating Places and Restaurants'),
('5541', 'Service Stations'),
('7996', 'Amusement Parks, Carnivals, Circuses'),
('5411', 'Grocery Stores, Supermarkets'),
('4784', 'Tolls and Bridge Fees'),
('4900', 'Utilities - Electric, Gas, Water, Sanitary'),
('5942', 'Book Stores'),
('5814', 'Fast Food Restaurants'),
('4829', 'Money Transfer'),
('5311', 'Department Stores'),
('5211', 'Lumber and Building Materials'),
('5310', 'Discount Stores'),
('3780', 'Computer Network Services'),
('5499', 'Miscellaneous Food Stores'),
('4121', 'Taxicabs and Limousines'),
('5300', 'Wholesale Clubs'),
('5719', 'Miscellaneous Home Furnishing Stores'),
('7832', 'Motion Picture Theaters'),
('5813', 'Drinking Places (Alcoholic Beverages)'),
('4814', 'Telecommunication Services'),
('5661', 'Shoe Stores'),
('5977', 'Cosmetic Stores'),
('8099', 'Medical Services'),
('7538', 'Automotive Service Shops'),
('5912', 'Drug Stores and Pharmacies'),
('4111', 'Local and Suburban Commuter Transportation'),
('5815', 'Digital Goods - Media, Books, Apps'),
('8021', 'Dentists and Orthodontists'),
('5921', 'Package Stores, Beer, Wine, Liquor'),
('5655', 'Sports Apparel, Riding Apparel Stores'),
('7230', 'Beauty and Barber Shops'),
('3390', 'Miscellaneous Metalwork'),
('7922', 'Theatrical Producers'),
('3722', 'Passenger Railways'),
('5651', 'Family Clothing Stores'),
('4899', 'Cable, Satellite, and Other Pay Television Services'),
('5251', 'Hardware Stores'),
('7995', 'Betting (including Lottery Tickets, Casinos)'),
('3596', 'Miscellaneous Machinery and Parts Manufacturing'),
('3730', 'Ship Chandlers'),
('9402', 'Postal Services - Government Only'),
('7801', 'Athletic Fields, Commercial Sports'),
('5970', 'Artist Supply Stores, Craft Shops'),
('5932', 'Antique Shops'),
('5621', 'Women''s Ready-To-Wear Stores'),
('7349', 'Cleaning and Maintenance Services'),
('4722', 'Travel Agencies'),
('5193', 'Florists Supplies, Nursery Stock and Flowers'),
('3775', 'Railroad Freight'),
('3684', 'Semiconductors and Related Devices'),
('5045', 'Computers, Computer Peripheral Equipment'),
('3504', 'Gardening Supplies'),
('7011', 'Lodging - Hotels, Motels, Resorts'),
('8041', 'Chiropractors'),
('4214', 'Motor Freight Carriers and Trucking'),
('6300', 'Insurance Sales, Underwriting'),
('8011', 'Doctors, Physicians'),
('3509', 'Industrial Equipment and Supplies'),
('7210', 'Laundry Services'),
('5192', 'Books, Periodicals, Newspapers'),
('7542', 'Car Washes'),
('3640', 'Lighting, Fixtures, Electrical Supplies'),
('7393', 'Detective Agencies, Security Services'),
('8111', 'Legal Services and Attorneys'),
('3771', 'Railroad Passenger Transport'),
('5732', 'Electronics Stores'),
('5094', 'Precious Stones and Metals'),
('5712', 'Furniture, Home Furnishings, and Equipment Stores'),
('5816', 'Digital Goods - Games'),
('7802', 'Recreational Sports, Clubs'),
('3389', 'Non-Precious Metal Services'),
('8043', 'Optometrists, Optical Goods and Eyeglasses'),
('3393', 'Heat Treating Metal Services'),
('3174', 'Upholstery and Drapery Stores'),
('3001', 'Steel Products Manufacturing'),
('3395', 'Welding Repair'),
('3058', 'Tools, Parts, Supplies Manufacturing'),
('8049', 'Podiatrists'),
('3387', 'Electroplating, Plating, Polishing Services'),
('4112', 'Passenger Railways'),
('3405', 'Ironwork'),
('5261', 'Lawn and Garden Supply Stores'),
('3144', 'Floor Covering Stores'),
('3132', 'Leather Goods'),
('3359', 'Non-Ferrous Metal Foundries'),
('8931', 'Accounting, Auditing, and Bookkeeping Services'),
('8062', 'Hospitals'),
('7276', 'Tax Preparation Services'),
('4131', 'Bus Lines'),
('3260', 'Pottery and Ceramics'),
('3256', 'Brick, Stone, and Related Materials'),
('3006', 'Miscellaneous Fabricated Metal Products'),
('7531', 'Automotive Body Repair Shops'),
('1711', 'Heating, Plumbing, Air Conditioning Contractors'),
('5947', 'Gift, Card, Novelty Stores'),
('3007', 'Coated and Laminated Products'),
('4511', 'Airlines'),
('3075', 'Bolt, Nut, Screw, Rivet Manufacturing'),
('3066', 'Miscellaneous Metals'),
('3005', 'Miscellaneous Metal Fabrication'),
('4411', 'Cruise Lines'),
('3000', 'Steelworks'),
('5533', 'Automotive Parts and Accessories Stores'),
('3008', 'Steel Drums and Barrels'),
('7549', 'Towing Services'),
('5941', 'Sporting Goods Stores'),
('5722', 'Household Appliance Stores'),
('3009', 'Fabricated Structural Metal Products'),
('5733', 'Music Stores - Musical Instruments')
ON CONFLICT (mcc_code) DO NOTHING;

-- =============================================================================
-- 2. CHARGEMENT DES CLIENTS (users_data.csv)
-- =============================================================================
CREATE TEMP TABLE clients_staging (
    id                  INT,
    current_age         INT,
    retirement_age      INT,
    birth_year          INT,
    birth_month         INT,
    gender              VARCHAR(20),
    address             TEXT,
    latitude            DECIMAL(9,6),
    longitude           DECIMAL(9,6),
    per_capita_income   VARCHAR(20),
    yearly_income       VARCHAR(20),
    total_debt          VARCHAR(20),
    credit_score        INT,
    num_credit_cards    INT
);

COPY clients_staging FROM '/data/users_data.csv'
    WITH (FORMAT csv, HEADER true, DELIMITER ',');

INSERT INTO clients (
    id_client, current_age, retirement_age, birth_year, birth_month,
    gender, adresse, latitude, longitude,
    per_capita_income, yearly_income, total_debt,
    credit_score, num_credit_cards
)
SELECT
    id,
    current_age,
    retirement_age,
    birth_year,
    birth_month,
    gender,
    address,
    latitude,
    longitude,
    REPLACE(per_capita_income, '$', '')::DECIMAL(15,2),
    REPLACE(yearly_income,     '$', '')::DECIMAL(15,2),
    REPLACE(total_debt,        '$', '')::DECIMAL(15,2),
    credit_score,
    num_credit_cards
FROM clients_staging;

DROP TABLE clients_staging;

-- =============================================================================
-- 3. CHARGEMENT DES CARTES (cards_data.csv)
-- =============================================================================
CREATE TEMP TABLE cartes_staging (
    id                    INT,
    client_id             INT,
    card_brand            VARCHAR(50),
    card_type             VARCHAR(50),
    card_number           BIGINT,
    expires               VARCHAR(10),
    cvv                   INT,
    has_chip              VARCHAR(5),
    num_cards_issued      INT,
    credit_limit          VARCHAR(20),
    acct_open_date        VARCHAR(10),
    year_pin_last_changed INT,
    card_on_dark_web      VARCHAR(5)
);

COPY cartes_staging FROM '/data/cards_data.csv'
    WITH (FORMAT csv, HEADER true, DELIMITER ',');

INSERT INTO cartes (
    id, id_client, card_brand, card_type, card_number, expires, cvv,
    has_chip, num_cards_issued, credit_limit, acct_open_date,
    year_pin_last_changed, card_on_dark_web
)
SELECT
    id,
    client_id,
    card_brand,
    card_type,
    card_number,
    expires,
    cvv,
    CASE UPPER(has_chip) WHEN 'YES' THEN TRUE ELSE FALSE END,
    num_cards_issued,
    REPLACE(credit_limit, '$', '')::DECIMAL(15,2),
    TO_DATE(
        SUBSTRING(acct_open_date FROM 4 FOR 4)
        || '-' ||
        SUBSTRING(acct_open_date FROM 1 FOR 2)
        || '-01',
        'YYYY-MM-DD'
    ),
    year_pin_last_changed,
    CASE WHEN card_on_dark_web ILIKE 'yes' THEN TRUE ELSE FALSE END
FROM cartes_staging;

DROP TABLE cartes_staging;

-- =============================================================================
-- 4. CHARGEMENT DES TRANSACTIONS (transactions_data.csv)
-- =============================================================================
CREATE TEMP TABLE transactions_staging (
    id             BIGINT,
    date           TIMESTAMP,
    client_id      INT,
    card_id        INT,
    amount         VARCHAR(20),
    use_chip       VARCHAR(50),
    merchant_id    BIGINT,
    merchant_city  VARCHAR(100),
    merchant_state VARCHAR(100),
    zip            VARCHAR(20),
    mcc            VARCHAR(20),   
    errors         TEXT
);

COPY transactions_staging FROM '/data/transactions_data.csv'
    WITH (FORMAT csv, HEADER true, DELIMITER ',');

-- Insertion des marchands uniques
-- On filtre les mcc valides (présents dans mcc_codes) et on tronque à 10 chars
INSERT INTO marchands (merchant_id, merchant_city, merchant_state, zip, mcc)
SELECT DISTINCT
    merchant_id,
    merchant_city,
    merchant_state,
    zip,
    LEFT(mcc, 10)
FROM transactions_staging
WHERE LEFT(mcc, 10) IN (SELECT mcc_code FROM mcc_codes)
ON CONFLICT (merchant_id) DO NOTHING;

-- Insertion des transactions
INSERT INTO transactions (
    id_transaction, date_transaction, id_client, card_id, id_marchand,
    amount, use_chip,
    merchant_city, merchant_state, zip, mcc, errors, is_fraud
)
SELECT
    ts.id,
    ts.date,
    ts.client_id,
    ts.card_id,
    m.id_marchand,
    REPLACE(REPLACE(ts.amount, '$', ''), ',', '')::DECIMAL(12,3),
    ts.use_chip,
    ts.merchant_city,
    ts.merchant_state,
    ts.zip,
    LEFT(ts.mcc, 10),
    NULLIF(TRIM(ts.errors), ''),
    FALSE
FROM transactions_staging ts
LEFT JOIN marchands m ON m.merchant_id = ts.merchant_id;

DROP TABLE transactions_staging;

-- =============================================================================
-- VÉRIFICATIONS POST-CHARGEMENT
-- =============================================================================
DO $$
BEGIN
    RAISE NOTICE '=== VÉRIFICATION DES CHARGEMENTS ===';
    RAISE NOTICE 'Clients     : % lignes', (SELECT COUNT(*) FROM clients);
    RAISE NOTICE 'Cartes      : % lignes', (SELECT COUNT(*) FROM cartes);
    RAISE NOTICE 'Marchands   : % lignes', (SELECT COUNT(*) FROM marchands);
    RAISE NOTICE 'Transactions: % lignes', (SELECT COUNT(*) FROM transactions);
    RAISE NOTICE 'MCC codes   : % lignes', (SELECT COUNT(*) FROM mcc_codes);
END $$;