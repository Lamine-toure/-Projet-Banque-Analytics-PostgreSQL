-- =============================================================================
-- ANALYSE CLIENTS ET TRANSACTIONS
-- =============================================================================

-- Q1 : Clients et nombre de cartes (avec vrai nom et nationalité)
SELECT
    cf.id_client,
    cf.nom_complet,
    cf.nationalite,
    cf.salaire,
    COUNT(ca.id) AS nb_cartes
FROM clients_full cf
LEFT JOIN cartes ca ON ca.id_client = cf.id_client
GROUP BY cf.id_client, cf.nom_complet, cf.nationalite, cf.salaire
ORDER BY nb_cartes DESC;

--Q2 : Montant total dépensé par client
select 
	c.id_client,
	c.yearly_income                          AS salaire,
    COALESCE(SUM(t.amount), 0)               AS montant_total_transactions
from clients c
left join transactions t on t.id_client = c.id_client
group by c.id_client, c.yearly_income
order by montant_total_transactions desc
limit 100;

-- Q3 : Clients à risque (dette élevée)

select
    id_client,
    yearly_income                                        AS salaire,
    total_debt                                           AS dette,
    ROUND(total_debt / nullif(yearly_income, 0), 4)     AS ratio_dette_salaire,
    case
        when total_debt / nullif(yearly_income, 0) <= 0.50 then 'low'
        when total_debt / nullif(yearly_income, 0) <= 1.00 then 'medium'
        when total_debt / nullif(yearly_income, 0) <= 2.00 then 'high'
        when total_debt / nullif(yearly_income, 0) <= 5.00 then 'ultra_high'
        else 'UTP'
    end                                                  as niveau_dette
from clients
order by ratio_dette_salaire desc

-- Q4 : Transactions par secteur (MCC)
select
    m.mcc_code                               as code_mcc,
    m.description                            as secteur,
    count(t.id_transaction)                  as nb_transactions,
    ROUND(avg(t.amount::NUMERIC), 2)         as montant_moyen,
    ROUND(sum(t.amount::NUMERIC), 2)         as montant_total
from mcc_codes m
left join transactions t on t.mcc = m.mcc_code
group by m.mcc_code, m.description
order by nb_transactions desc;

-- Q5 : Cartes les plus utilisées
select
    t.card_id                                as id_carte,
    count(t.id_transaction)                  as nb_transactions,
    ROUND(sum(t.amount::NUMERIC), 2)         as montant_total
from transactions t
group by t.card_id
ORDER BY nb_transactions desc
LIMIT 150;

-- Q6 : Clients par nationalité (vraie nationalité !)
SELECT
    nationalite,
    COUNT(*) AS nb_clients,
    ROUND(AVG(salaire), 2) AS salaire_moyen,
    ROUND(AVG(dette), 2) AS dette_moyenne
FROM clients_full
GROUP BY nationalite
ORDER BY nb_clients DESC;

-- Q7 : Transactions par type et secteur
select
    t.use_chip                               as type_transaction,
    m.description                            as secteur_destinataire,
    count(t.id_transaction)                  as nb_transactions,
    ROUND(sum(t.amount::NUMERIC), 2)         as montant_total
from transactions t
left join mcc_codes m on m.mcc_code = t.mcc
group by t.use_chip, m.description
order by type_transaction asc, montant_total desc;

-- Q8 : Clients sans transactions
select
    c.id_client,
    c.yearly_income                          as salaire,
    c.credit_score
from clients c
left join transactions t on t.id_client = c.id_client
where t.id_transaction is null;

-- Q9 : Villes les plus actives
select
    t.merchant_city                          as ville_destinataire,
    count(t.id_transaction)                  as nombre_transactions,
    ROUND(avg(t.amount), 2)         as montant_moyen
from transactions t
where t.merchant_city is not null
group by t.merchant_city
order by nombre_transactions desc
limit 5;

-- Q10 : Analyse par genre
select
    c.gender                                 as genre,
    count(distinct c.id_client)              as nb_clients,
    ROUND(avg(c.yearly_income), 2)           as salaire_moyen,
    ROUND(avg(c.credit_score), 2)            as credit_score_moyen,
    ROUND(coalesce(sum(t.amount::NUMERIC), 0), 2) as montant_total_transactions
from clients c
left join transactions t ON t.id_client = c.id_client
group by c.gender
order by montant_total_transactions desc;
