/* Проект «по мотивам online-игры»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты, а также оценить 
 * активность игроков при совершении внутриигровых покупок
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков
-- 1.1. Доля платящих пользователей по всем данным:
SELECT 
    COUNT(payer) AS total_users,
    SUM(CASE WHEN payer = 1 THEN 1 ELSE 0 END) AS paying_users,
    ROUND(AVG(payer), 4) AS share_paying_users 
FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT 
    r.race, 
    SUM(CASE WHEN u.payer = 1 THEN 1 ELSE 0 END) AS paying_users,
    COUNT(u.payer) AS total_users,
    ROUND(AVG(u.payer), 4) AS share_paying_users 
FROM fantasy.users AS u 
LEFT JOIN fantasy.race AS r USING (race_id)
GROUP BY r.race
ORDER BY share_paying_users DESC;
 

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT 
    COUNT(transaction_id) AS total_transactions,
    SUM(amount) AS sum_amount,
    MIN(amount) AS min_amount,
    MAX(amount) AS max_amount,
    ROUND(AVG(amount::NUMERIC), 2) AS avg_amount,
    ROUND(PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount::NUMERIC), 2) AS amount_median,
    ROUND(STDDEV(amount::NUMERIC), 2) AS amount_stand_dev
FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:
SELECT 
    COUNT(*) FILTER (WHERE amount=0) AS zero_transactions,
    ROUND(COUNT(*) FILTER (WHERE amount=0)/COUNT(*)::NUMERIC ,4) AS shere_of_zero_transactions
FROM fantasy.events;

-- 2.3: Популярные эпические предметы:
SELECT 
    i.game_items,
    COUNT(e.transaction_id) AS count_transactions,
    ROUND(COUNT(e.transaction_id)::NUMERIC / SUM(COUNT(e.transaction_id)) OVER (), 6) AS share_of_transactions,
    ROUND(COUNT(DISTINCT e.id)::NUMERIC / (SELECT COUNT(DISTINCT id) FROM fantasy.events WHERE amount > 0), 4) AS share_of_users
FROM fantasy.items AS i 
LEFT JOIN fantasy.events AS e USING (item_code)
WHERE e.amount > 0
GROUP BY i.item_code
ORDER BY count_transactions DESC;

-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
-- 1. Считаем количество всех зарегистрированных игроков (users)
WITH all_users_inf AS (     
    SELECT
        r.race_id,
        COUNT(u.id) AS total_users
    FROM fantasy.users AS u
    LEFT JOIN fantasy.race AS r USING (race_id)
    GROUP BY r.race_id),
--Статистика игроков, совершающих покупки в игре
all_payers_inf AS (
    SELECT
        r.race_id,
        COUNT(u.id) AS total_buyers,
        SUM(CASE WHEN u.payer = 1 THEN 1 ELSE 0 END) AS total_payers,
        ROUND(AVG(payer), 4) AS share_paying_users
    FROM fantasy.users AS u
    LEFT JOIN fantasy.race AS r USING (race_id)
    WHERE EXISTS (SELECT e.id FROM fantasy.events AS e WHERE e.id = u.id AND e.amount > 0)
    GROUP BY r.race_id),
--Статистика покупок среди игроков
transactions_inf AS (
    SELECT
        id,
        COUNT(transaction_id) AS count_transactions,
        SUM(amount) AS sum_amount,
        AVG(amount) AS avg_amount
    FROM fantasy.events
    WHERE amount > 0
    GROUP BY id)
--Основоной запрос
SELECT
    r.race,
    u.total_users,
    p.total_buyers,
    ROUND((p.total_buyers/u.total_users::NUMERIC), 4) AS share_of_buyers,
    p.share_paying_users,
    ROUND(AVG(t.count_transactions)::NUMERIC, 2) AS avg_count_of_transactions,
    ROUND(AVG(t.avg_amount)::NUMERIC, 2) AS avg_amount,
    ROUND(AVG(t.sum_amount)::NUMERIC, 2) AS avg_sum_amount
FROM fantasy.race AS r 
LEFT JOIN all_users_inf AS u USING (race_id)
LEFT JOIN all_payers_inf AS p USING (race_id)
LEFT JOIN fantasy.users AS us USING (race_id)
LEFT JOIN transactions_inf AS t USING (id)
GROUP BY r.race_id, u.total_users, p.total_buyers, p.share_paying_users;
