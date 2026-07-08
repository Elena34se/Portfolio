/* Анализ данных для агентства недвижимости (ad hoc задачи):
*/

-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL))
-- Выведем объявления без выбросов:
SELECT
-- Разделим все объявления на Санкт-Петербург и Лен.область
    CASE
    	WHEN city_id = '6X8I' THEN 'Санкт-Петербург'
    	ELSE 'Лен.область'
    END AS Регион,
-- Создаем доп.поле по количеству дней активности, для порядка добавим нумерацию:
    CASE
    	WHEN days_exposition BETWEEN 1 AND 30 THEN '1) в течение месяца'
    	WHEN days_exposition BETWEEN 31 AND 90 THEN '2) от 1 месяца до 3'
    	WHEN days_exposition BETWEEN 91 AND 180 THEN '3) от 3 месяцев до 6'
    	WHEN days_exposition >181 THEN '4) более полугода'
    	ELSE '5) еще активны'
    END AS Активность_объявления,
-- Считаем основные параметры продаваемых квартир:
    COUNT(f.id) AS Количество_объявлений,
    ROUND(COUNT(f.id)/SUM(COUNT(f.id)) OVER(), 4) AS Доля_от_всех_объявлений,
    ROUND(AVG(a.last_price/f.total_area)::NUMERIC,2) AS Средняя_стоимость_1м_кв_в_руб,
    ROUND(AVG(f.total_area)::NUMERIC,2) AS Средняя_площадь_м_кв,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.rooms) AS Количество_комнат,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.balcony) AS Количество_балконов,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.floor) AS Количество_этажей
FROM real_estate.flats AS f
LEFT JOIN real_estate.advertisement AS a USING (id)
LEFT JOIN real_estate.city AS c USING (city_id)
LEFT JOIN real_estate.type AS t USING (type_id)
-- Рассматриваем объявления только за полный год (с 2015 по 2018гг), только в городах, с учётом выбросов:
WHERE DATE_TRUNC('year', first_day_exposition::timestamp)>='2015-01-01' AND DATE_TRUNC('year', first_day_exposition::timestamp)<='2018-01-01' AND t.TYPE='город' AND id IN (SELECT * FROM filtered_id)
GROUP BY Регион, Активность_объявления
ORDER BY Регион DESC, Активность_объявления;



-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)),
-- Выведем объявления без выбросов:
-- Для каждого объявления расчитаем месяц публикации (first_day) и снятия (last_day)
inf_of_advertisements AS (
    SELECT
        a.id,
        a.last_price,
        f.total_area,
        EXTRACT(MONTH FROM a.first_day_exposition) AS month_of_first_day_exposition,
        EXTRACT(MONTH FROM a.first_day_exposition + a.days_exposition::int) AS month_of_last_day_exposition
    FROM real_estate.advertisement AS a 
    LEFT JOIN real_estate.flats AS f USING (id)
    LEFT JOIN real_estate.type AS t USING (type_id)
-- Рассматриваем объявления только за полный год (с 2015 по 2018гг), только в городах, с учетом выбросов:
    WHERE DATE_TRUNC('year', first_day_exposition::timestamp)>='2015-01-01' AND DATE_TRUNC('year', first_day_exposition::timestamp)<='2018-01-01' AND t.TYPE='город' AND id IN (SELECT * FROM filtered_id)),
first_day_exposition AS (
    SELECT
        month_of_first_day_exposition,
        COUNT(id) AS count_of_first_day_exposition,
        ROUND(AVG(last_price/total_area)::NUMERIC,2) AS avg_price_first,
        ROUND(AVG(total_area)::NUMERIC,2) AS avg_square_first
    FROM inf_of_advertisements
    GROUP BY month_of_first_day_exposition),
last_day_exposition AS (
    SELECT
        month_of_last_day_exposition, 
        COUNT(id) AS count_of_last_day_exposition,
        ROUND(AVG(last_price/total_area)::NUMERIC,2) AS avg_price_last,
         ROUND(AVG(total_area)::NUMERIC,2) AS avg_square_last
    FROM inf_of_advertisements AS i
    WHERE month_of_last_day_exposition IS NOT NULL
    GROUP BY month_of_last_day_exposition)
SELECT 
    f.month_of_first_day_exposition AS Месяц,
    f.count_of_first_day_exposition AS Количество_публикаций,
    f.avg_price_first AS Средняя_стоимость_1м_кв_в_руб_опуб,
    f.avg_square_first AS Средняя_площадь_м_кв_опуб,
    l.count_of_last_day_exposition AS Количество_снятий,
    l.avg_price_last AS Средняя_стоимость_1м_кв_в_руб_снят,
    l.avg_square_last AS Средняя_площадь_м_кв_снят
FROM first_day_exposition AS f
FULL JOIN last_day_exposition AS l ON f.month_of_first_day_exposition=l.month_of_last_day_exposition
ORDER BY f.month_of_first_day_exposition;

