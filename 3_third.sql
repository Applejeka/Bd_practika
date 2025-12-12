-- ============================================================================
-- 1. ФУНКЦИЯ ДЛЯ ЧИТАЕМОГО ПРЕДСТАВЛЕНИЯ ТАБЛИЦЫ TRANSFERREDPOINTS
-- ============================================================================
-- Возвращает таблицу передаваемых очков между пирами в читаемом формате
-- Обрабатывает двусторонние передачи (A->B и B->A) как чистый результат
DROP FUNCTION IF EXISTS fnc_readable_transferred_points CASCADE;

CREATE OR REPLACE FUNCTION fnc_readable_transferred_points()
RETURNS TABLE (
    peer1 VARCHAR,     -- Первый пир в паре
    peer2 VARCHAR,     -- Второй пир в паре  
    amount INTEGER     -- Чистое количество переданных очков (peer1 -> peer2)
) 
AS $$
BEGIN
    RETURN QUERY
    -- Шаг 1: Находим все взаимные передачи (где есть обе стороны A->B и B->A)
    WITH reciprocal_transfers AS (
        -- Исходные передачи
        SELECT 
            tp.checkingpeer AS peer1, 
            tp.checkedpeer AS peer2, 
            tp.pointsamount AS amount
        FROM transferredpoints tp
        
        UNION ALL
        
        -- Обратные передачи (меняем местами пиров)
        SELECT 
            tp.checkedpeer AS peer1, 
            tp.checkingpeer AS peer2, 
            -tp.pointsamount AS amount
        FROM transferredpoints tp
    ),
    -- Шаг 2: Суммируем все передачи между каждой парой пиров
    net_transfers AS (
        SELECT 
            LEAST(peer1, peer2) AS peer1,     -- Всегда меньший ник первым
            GREATEST(peer1, peer2) AS peer2,  -- Всегда больший ник вторым
            SUM(amount) AS net_amount
        FROM reciprocal_transfers
        GROUP BY LEAST(peer1, peer2), GREATEST(peer1, peer2)
        HAVING SUM(amount) != 0  -- Исключаем нулевые балансы
    )
    -- Шаг 3: Возвращаем результат с положительными значениями
    SELECT 
        peer1,
        peer2,
        ABS(net_amount)::INTEGER AS amount
    FROM net_transfers
    WHERE net_amount > 0  -- Только положительные чистые переводы
    
    UNION ALL
    
    -- Если чистый перевод отрицательный, меняем пиров местами
    SELECT 
        peer2 AS peer1,
        peer1 AS peer2,
        ABS(net_amount)::INTEGER AS amount
    FROM net_transfers
    WHERE net_amount < 0
    
    ORDER BY peer1, peer2;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 2. ФУНКЦИЯ ДЛЯ ПОЛУЧЕНИЯ УСПЕШНЫХ ПРОВЕРОК С XP
-- ============================================================================
-- Возвращает таблицу: пир, задание, полученный XP
DROP FUNCTION IF EXISTS fnc_successful_checks CASCADE;

CREATE OR REPLACE FUNCTION fnc_successful_checks()
RETURNS TABLE (
    peer VARCHAR,      -- Пир, прошедший проверку
    task VARCHAR,      -- Название задания
    xp INTEGER         -- Количество полученного XP
) 
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.peer,
        c.task,
        x.xpamount::INTEGER AS xp
    FROM checks c
    INNER JOIN p2p p ON c.id = p.checkid
    INNER JOIN xp x ON c.id = x.checkid
    WHERE p.state = 'Success'  -- Только успешные P2P проверки
    ORDER BY c.peer, c.task;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 3. ФУНКЦИЯ ДЛЯ ПОИСКА ПИРОВ, КОТОРЫЕ НЕ ПОКИДАЛИ КАМПУС ЦЕЛЫЙ ДЕНЬ
-- ============================================================================
-- Находит пиров, у которых в указанный день был только вход, но не было выхода
DROP FUNCTION IF EXISTS fnc_find_diligent_students(date) CASCADE;

CREATE OR REPLACE FUNCTION fnc_find_diligent_students(
    target_date DATE  -- Дата для проверки
)
RETURNS TABLE (
    peer VARCHAR      -- Пир, который не покидал кампус
) 
AS $$
BEGIN
    RETURN QUERY
    WITH daily_activity AS (
        SELECT 
            tt.peer,
            COUNT(*) FILTER (WHERE tt.state = 1) AS entries,  -- Количество входов
            COUNT(*) FILTER (WHERE tt.state = 2) AS exits     -- Количество выходов
        FROM timetracking tt
        WHERE tt.date = target_date
        GROUP BY tt.peer
    )
    SELECT da.peer
    FROM daily_activity da
    WHERE da.entries > 0  -- Был хотя бы один вход
      AND da.exits = 0;   -- Не было ни одного выхода
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. ПРОЦЕДУРА ДЛЯ РАСЧЕТА ИЗМЕНЕНИЯ ОЧКОВ ПИРОВ (ИЗ TRANSFERREDPOINTS)
-- ============================================================================
-- Рассчитывает баланс очков для каждого пира
DROP PROCEDURE IF EXISTS proc_count_points(refcursor) CASCADE;

CREATE OR REPLACE PROCEDURE proc_count_points(
    INOUT result_cursor refcursor  -- Курсор для возврата результатов
)
AS $$
BEGIN
    OPEN result_cursor FOR
    WITH points_summary AS (
        -- Очки, полученные как проверяющий
        SELECT 
            tp.checkingpeer AS peer,
            SUM(tp.pointsamount) AS points_change
        FROM transferredpoints tp
        GROUP BY tp.checkingpeer
        
        UNION ALL
        
        -- Очки, отданные как проверяемый (отрицательные)
        SELECT 
            tp.checkedpeer AS peer,
            SUM(-tp.pointsamount) AS points_change
        FROM transferredpoints tp
        GROUP BY tp.checkedpeer
    )
    SELECT 
        ps.peer,
        SUM(ps.points_change)::INTEGER AS total_points
    FROM points_summary ps
    GROUP BY ps.peer
    ORDER BY total_points DESC, ps.peer;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 5. ПРОЦЕДУРА ДЛЯ РАСЧЕТА ИЗМЕНЕНИЯ ОЧКОВ (ИЗ ЧИТАЕМОЙ ФУНКЦИИ)
-- ============================================================================
-- Использует функцию fnc_readable_transferred_points для расчета
DROP PROCEDURE IF EXISTS proc_count_points_fnc(refcursor) CASCADE;

CREATE OR REPLACE PROCEDURE proc_count_points_fnc(
    INOUT result_cursor refcursor
)
AS $$
BEGIN
    OPEN result_cursor FOR
    WITH readable_points AS (
        SELECT * FROM fnc_readable_transferred_points()
    ),
    points_summary AS (
        -- Очки, отправленные как peer1
        SELECT 
            rp.peer1 AS peer,
            SUM(rp.amount) AS points_change
        FROM readable_points rp
        GROUP BY rp.peer1
        
        UNION ALL
        
        -- Очки, полученные как peer2 (отрицательные)
        SELECT 
            rp.peer2 AS peer,
            SUM(-rp.amount) AS points_change
        FROM readable_points rp
        GROUP BY rp.peer2
    )
    SELECT 
        ps.peer,
        SUM(ps.points_change)::INTEGER AS total_points
    FROM points_summary ps
    GROUP BY ps.peer
    ORDER BY total_points DESC, ps.peer;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 6. ПРОЦЕДУРА ДЛЯ НАХОЖДЕНИЯ САМЫХ ЧАСТО ПРОВЕРЯЕМЫХ ЗАДАНИЙ ПО ДНЯМ
-- ============================================================================
-- Для каждого дня находит задание с максимальным количеством проверок
DROP PROCEDURE IF EXISTS proc_find_most_frequent_tasks(refcursor) CASCADE;

CREATE OR REPLACE PROCEDURE proc_find_most_frequent_tasks(
    INOUT result_cursor refcursor
)
AS $$
BEGIN
    OPEN result_cursor FOR
    WITH daily_task_counts AS (
        SELECT 
            c.date,
            c.task,
            COUNT(*) AS check_count
        FROM checks c
        GROUP BY c.date, c.task
    ),
    max_counts_per_day AS (
        SELECT 
            dtc.date,
            MAX(dtc.check_count) AS max_count
        FROM daily_task_counts dtc
        GROUP BY dtc.date
    )
    SELECT 
        dtc.date,
        dtc.task
    FROM daily_task_counts dtc
    INNER JOIN max_counts_per_day mcpd 
        ON dtc.date = mcpd.date 
        AND dtc.check_count = mcpd.max_count
    ORDER BY dtc.date, dtc.task;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 7. ПРОЦЕДУРА ДЛЯ НАХОЖДЕНИЯ ПИРОВ, ЗАВЕРШИВШИХ БЛОК ЗАДАНИЙ
-- ============================================================================
-- Находит пиров, которые завершили все задания указанного блока
DROP PROCEDURE IF EXISTS proc_find_peers_completed_block(refcursor, TEXT) CASCADE;

CREATE OR REPLACE PROCEDURE proc_find_peers_completed_block(
    INOUT result_cursor refcursor,
    IN block_prefix TEXT  -- Префикс блока (например, 'C', 'DO', 'SQL')
)
AS $$
BEGIN
    OPEN result_cursor FOR
    WITH block_tasks AS (
        -- Все задания в указанном блоке
        SELECT t.title
        FROM tasks t
        WHERE t.title LIKE block_prefix || '%'
    ),
    completed_block_tasks AS (
        -- Пиры, успешно завершившие задания блока
        SELECT DISTINCT 
            c.peer,
            c.task,
            c.date
        FROM checks c
        INNER JOIN xp x ON c.id = x.checkid
        WHERE c.task IN (SELECT title FROM block_tasks)
    ),
    peers_completed_all AS (
        -- Пиры, которые завершили ВСЕ задания блока
        SELECT 
            cbt.peer,
            MAX(cbt.date) AS completion_date
        FROM completed_block_tasks cbt
        GROUP BY cbt.peer
        HAVING COUNT(DISTINCT cbt.task) = (SELECT COUNT(*) FROM block_tasks)
    )
    SELECT 
        pca.peer,
        pca.completion_date
    FROM peers_completed_all pca
    ORDER BY pca.completion_date DESC, pca.peer;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 8. ПРОЦЕДУРА ДЛЯ РЕКОМЕНДАЦИЙ ПРОВЕРКИ
-- ============================================================================
-- Определяет, к какому пиру стоит обратиться для проверки на основе рекомендаций друзей
DROP PROCEDURE IF EXISTS proc_get_recommendations(refcursor) CASCADE;

CREATE OR REPLACE PROCEDURE proc_get_recommendations(
    INOUT result_cursor refcursor
)
AS $$
BEGIN
    OPEN result_cursor FOR
    WITH friend_recommendations AS (
        -- Рекомендации друзей для каждого пира
        SELECT 
            f.peer1,
            r.recommendedpeer,
            COUNT(*) AS recommendation_count
        FROM friends f
        INNER JOIN recommendations r ON f.peer2 = r.peer
        WHERE f.peer1 != r.recommendedpeer  -- Исключаем саморекомендации
        GROUP BY f.peer1, r.recommendedpeer
    ),
    top_recommendations AS (
        -- Наиболее часто рекомендуемый пир для каждого
        SELECT 
            fr.peer1,
            fr.recommendedpeer,
            fr.recommendation_count,
            ROW_NUMBER() OVER (
                PARTITION BY fr.peer1 
                ORDER BY fr.recommendation_count DESC, fr.recommendedpeer
            ) AS rank
        FROM friend_recommendations fr
    )
    SELECT 
        tr.peer1 AS peer,
        tr.recommendedpeer AS recommended_peer
    FROM top_recommendations tr
    WHERE tr.rank = 1
    ORDER BY tr.peer1;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 9. ПРОЦЕДУРА ДЛЯ СТАТИСТИКИ НАЧАЛА БЛОКОВ
-- ============================================================================
-- Статистика по началу выполнения блоков заданий
DROP PROCEDURE IF EXISTS proc_get_block_start_stats(refcursor, TEXT, TEXT) CASCADE;

CREATE OR REPLACE PROCEDURE proc_get_block_start_stats(
    INOUT result_cursor refcursor,
    IN block1_prefix TEXT,
    IN block2_prefix TEXT
)
AS $$
DECLARE
    total_peers_count INTEGER;
BEGIN
    -- Общее количество пиров
    SELECT COUNT(*) INTO total_peers_count FROM peers;
    
    -- Если нет пиров, устанавливаем 1 для избежания деления на 0
    IF total_peers_count = 0 THEN
        total_peers_count := 1;
    END IF;

    OPEN result_cursor FOR
    WITH started_blocks AS (
        -- Пиры, начавшие блоки
        SELECT DISTINCT 
            c.peer,
            CASE 
                WHEN c.task LIKE block1_prefix || '%' THEN 'block1'
                WHEN c.task LIKE block2_prefix || '%' THEN 'block2'
            END AS block_type
        FROM checks c
        WHERE c.task LIKE block1_prefix || '%' 
           OR c.task LIKE block2_prefix || '%'
    ),
    stats AS (
        SELECT 
            COUNT(DISTINCT CASE WHEN sb.block_type = 'block1' THEN sb.peer END)::NUMERIC 
                / total_peers_count * 100 AS started_block1_percent,
            COUNT(DISTINCT CASE WHEN sb.block_type = 'block2' THEN sb.peer END)::NUMERIC 
                / total_peers_count * 100 AS started_block2_percent,
            COUNT(DISTINCT CASE WHEN sb.block_type IN ('block1', 'block2') THEN sb.peer END)::NUMERIC 
                / total_peers_count * 100 AS started_both_blocks_percent,
            (total_peers_count - COUNT(DISTINCT sb.peer))::NUMERIC 
                / total_peers_count * 100 AS started_no_blocks_percent
        FROM started_blocks sb
        RIGHT JOIN peers p ON sb.peer = p.nickname
    )
    SELECT 
        ROUND(started_block1_percent, 2) AS started_block1_percent,
        ROUND(started_block2_percent, 2) AS started_block2_percent,
        ROUND(started_both_blocks_percent, 2) AS started_both_blocks_percent,
        ROUND(started_no_blocks_percent, 2) AS started_no_blocks_percent
    FROM stats;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 10. ПРОЦЕДУРА ДЛЯ СТАТИСТИКИ УСПЕШНОСТИ ПРОВЕРОК В ДЕНЬ РОЖДЕНИЯ
-- ============================================================================
DROP PROCEDURE IF EXISTS proc_get_birthday_check_stats(refcursor) CASCADE;

CREATE OR REPLACE PROCEDURE proc_get_birthday_check_stats(
    INOUT result_cursor refcursor
)
AS $$
BEGIN
    OPEN result_cursor FOR
    WITH birthday_checks AS (
        -- Проверки, выполненные в день рождения пира
        SELECT 
            p.nickname,
            c.id AS check_id,
            EXTRACT(MONTH FROM p.birthday) AS birth_month,
            EXTRACT(DAY FROM p.birthday) AS birth_day,
            EXTRACT(MONTH FROM c.date) AS check_month,
            EXTRACT(DAY FROM c.date) AS check_day
        FROM peers p
        INNER JOIN checks c ON p.nickname = c.peer
        WHERE EXTRACT(MONTH FROM p.birthday) = EXTRACT(MONTH FROM c.date)
          AND EXTRACT(DAY FROM p.birthday) = EXTRACT(DAY FROM c.date)
    ),
    check_results AS (
        -- Результаты этих проверок
        SELECT 
            bc.nickname,
            p.state AS p2p_result,
            v.state AS verter_result
        FROM birthday_checks bc
        LEFT JOIN p2p p ON bc.check_id = p.checkid AND p.state != 'Start'
        LEFT JOIN verter v ON bc.check_id = v.checkid AND v.state != 'Start'
    ),
    stats AS (
        SELECT 
            COUNT(DISTINCT cr.nickname) FILTER (
                WHERE cr.p2p_result = 'Success' 
                AND (cr.verter_result IS NULL OR cr.verter_result = 'Success')
            ) AS successful_count,
            COUNT(DISTINCT cr.nickname) FILTER (
                WHERE cr.p2p_result = 'Failure' 
                OR cr.verter_result = 'Failure'
            ) AS failed_count,
            COUNT(DISTINCT cr.nickname) AS total_with_birthday_checks
        FROM check_results cr
    )
    SELECT 
        CASE 
            WHEN s.total_with_birthday_checks = 0 THEN 0
            ELSE ROUND(s.successful_count::NUMERIC / s.total_with_birthday_checks * 100, 2)
        END AS successful_checks_percent,
        CASE 
            WHEN s.total_with_birthday_checks = 0 THEN 0
            ELSE ROUND(s.failed_count::NUMERIC / s.total_with_birthday_checks * 100, 2)
        END AS failed_checks_percent
    FROM stats s;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 11. ПРОЦЕДУРА ДЛЯ ПОИСКА ПИРОВ, ВЫПОЛНИВШИХ Т1 И Т2, НО НЕ Т3
-- ============================================================================
DROP PROCEDURE IF EXISTS proc_find_peers_completed_t1_t2_not_t3(refcursor, TEXT, TEXT, TEXT) CASCADE;

CREATE OR REPLACE PROCEDURE proc_find_peers_completed_t1_t2_not_t3(
    INOUT result_cursor refcursor,
    IN task1_name TEXT,
    IN task2_name TEXT,
    IN task3_name TEXT
)
AS $$
BEGIN
    OPEN result_cursor FOR
    WITH successful_checks AS (
        -- Успешные проверки с XP
        SELECT DISTINCT c.peer, c.task
        FROM checks c
        INNER JOIN xp x ON c.id = x.checkid
    )
    SELECT DISTINCT sc1.peer
    FROM successful_checks sc1
    WHERE sc1.task = task1_name  -- Выполнил task1
      AND EXISTS (SELECT 1 FROM successful_checks sc2 
                  WHERE sc2.peer = sc1.peer AND sc2.task = task2_name)  -- И task2
      AND NOT EXISTS (SELECT 1 FROM successful_checks sc3 
                      WHERE sc3.peer = sc1.peer AND sc3.task = task3_name)  -- Но не task3
    ORDER BY sc1.peer;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 12. ФУНКЦИЯ ДЛЯ ПОДСЧЕТА КОЛИЧЕСТВА ПРЕДШЕСТВУЮЩИХ ЗАДАНИЙ
-- ============================================================================
DROP FUNCTION IF EXISTS fnc_count_previous_tasks CASCADE;

CREATE OR REPLACE FUNCTION fnc_count_previous_tasks()
RETURNS TABLE (
    task VARCHAR,
    previous_count INTEGER
) 
AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE task_hierarchy AS (
        -- Базовый случай: задачи без родительских задач
        SELECT 
            t.title,
            t.parenttask,
            0 AS depth
        FROM tasks t
        
        UNION ALL
        
        -- Рекурсивный случай: находим родительские задачи
        SELECT 
            th.title,
            t.parenttask,
            th.depth + 1
        FROM task_hierarchy th
        INNER JOIN tasks t ON th.parenttask = t.title
        WHERE t.parenttask IS NOT NULL
    )
    SELECT 
        th.title AS task,
        MAX(th.depth)::INTEGER AS previous_count
    FROM task_hierarchy th
    GROUP BY th.title
    ORDER BY th.title;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 13. ПРОЦЕДУРА ДЛЯ ПОИСКА "СЧАСТЛИВЫХ" ДНЕЙ
-- ============================================================================
-- День считается "счастливым", если в нем есть N последовательных успешных проверок
DROP PROCEDURE IF EXISTS proc_find_lucky_days(refcursor, INTEGER) CASCADE;

CREATE OR REPLACE PROCEDURE proc_find_lucky_days(
    INOUT result_cursor refcursor,
    IN consecutive_success_count INTEGER
)
AS $$
BEGIN
    OPEN result_cursor FOR
    WITH successful_checks AS (
        -- Успешные проверки с высоким XP (>= 80% от максимума)
        SELECT 
            c.id,
            c.date,
            p.time,
            p.state,
            x.xpamount,
            t.maxxp,
            ROW_NUMBER() OVER (ORDER BY c.date, p.time) AS row_num
        FROM checks c
        INNER JOIN p2p p ON c.id = p.checkid
        INNER JOIN xp x ON c.id = x.checkid
        INNER JOIN tasks t ON c.task = t.title
        WHERE p.state = 'Success'
          AND x.xpamount >= t.maxxp * 0.8
    ),
    consecutive_groups AS (
        -- Группируем последовательные успешные проверки
        SELECT 
            sc.date,
            sc.row_num,
            sc.row_num - ROW_NUMBER() OVER (PARTITION BY sc.date ORDER BY sc.row_num) AS grp
        FROM successful_checks sc
    ),
    consecutive_counts AS (
        -- Считаем количество последовательных успехов в каждой группе
        SELECT 
            cg.date,
            COUNT(*) AS consecutive_count
        FROM consecutive_groups cg
        GROUP BY cg.date, cg.grp
    ),
    max_consecutive_per_day AS (
        -- Максимальное количество последовательных успехов за день
        SELECT 
            cc.date,
            MAX(cc.consecutive_count) AS max_consecutive
        FROM consecutive_counts cc
        GROUP BY cc.date
    )
    SELECT mc.date
    FROM max_consecutive_per_day mc
    WHERE mc.max_consecutive >= consecutive_success_count
    ORDER BY mc.date;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 14. ФУНКЦИЯ ДЛЯ ПОИСКА ПИРА С МАКСИМАЛЬНЫМ КОЛИЧЕСТВОМ XP
-- ============================================================================
DROP FUNCTION IF EXISTS fnc_find_top_xp_peer CASCADE;

CREATE OR REPLACE FUNCTION fnc_find_top_xp_peer()
RETURNS TABLE (
    peer VARCHAR,
    total_xp BIGINT
) 
AS $$
BEGIN
    RETURN QUERY
    WITH peer_xp_totals AS (
        SELECT 
            c.peer,
            SUM(x.xpamount)::BIGINT AS total_xp
        FROM checks c
        INNER JOIN xp x ON c.id = x.checkid
        GROUP BY c.peer
    )
    SELECT pxt.peer, pxt.total_xp
    FROM peer_xp_totals pxt
    WHERE pxt.total_xp = (SELECT MAX(total_xp) FROM peer_xp_totals)
    ORDER BY pxt.peer;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 15. ПРОЦЕДУРА ДЛЯ ПОИСКА РАННИХ ВХОДОВ
-- ============================================================================
DROP PROCEDURE IF EXISTS proc_find_early_entrants(refcursor, TIME, INTEGER) CASCADE;

CREATE OR REPLACE PROCEDURE proc_find_early_entrants(
    INOUT result_cursor refcursor,
    IN cutoff_time TIME,
    IN min_entries_count INTEGER
)
AS $$
BEGIN
    OPEN result_cursor FOR
    WITH early_entries AS (
        SELECT 
            tt.peer,
            COUNT(DISTINCT tt.date) AS early_entry_count
        FROM timetracking tt
        WHERE tt.state = 1  -- Вход
          AND tt.time < cutoff_time
        GROUP BY tt.peer
    )
    SELECT 
        ee.peer,
        ee.early_entry_count::INTEGER
    FROM early_entries ee
    WHERE ee.early_entry_count >= min_entries_count
    ORDER BY ee.early_entry_count DESC, ee.peer;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 16. ПРОЦЕДУРА ДЛЯ ПОИСКА ЧАСТЫХ ВЫХОДОВ
-- ============================================================================
DROP PROCEDURE IF EXISTS proc_find_frequent_exits(refcursor, INTEGER, INTEGER) CASCADE;

CREATE OR REPLACE PROCEDURE proc_find_frequent_exits(
    INOUT result_cursor refcursor,
    IN days_count INTEGER,
    IN min_exits_count INTEGER
)
AS $$
DECLARE
    start_date DATE;
BEGIN
    -- Рассчитываем начальную дату
    start_date := CURRENT_DATE - (days_count - 1);
    
    OPEN result_cursor FOR
    WITH recent_exits AS (
        SELECT 
            tt.peer,
            COUNT(DISTINCT tt.date) AS exit_count
        FROM timetracking tt
        WHERE tt.state = 2  -- Выход
          AND tt.date BETWEEN start_date AND CURRENT_DATE
        GROUP BY tt.peer
    )
    SELECT 
        re.peer,
        re.exit_count::INTEGER
    FROM recent_exits re
    WHERE re.exit_count >= min_exits_count
    ORDER BY re.exit_count DESC, re.peer;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 17. ФУНКЦИЯ ДЛЯ СТАТИСТИКИ РАННИХ ВХОДОВ ПО МЕСЯЦАМ
-- ============================================================================
DROP FUNCTION IF EXISTS fnc_calculate_early_entry_stats CASCADE;

CREATE OR REPLACE FUNCTION fnc_calculate_early_entry_stats()
RETURNS TABLE (
    month_name VARCHAR,
    early_entry_percent NUMERIC(5,1)
) 
AS $$
BEGIN
    RETURN QUERY
    WITH birthday_entries AS (
        -- Входы в месяц рождения
        SELECT 
            p.nickname,
            tt.date,
            tt.time,
            EXTRACT(MONTH FROM p.birthday) AS birth_month,
            EXTRACT(MONTH FROM tt.date) AS entry_month
        FROM peers p
        INNER JOIN timetracking tt ON p.nickname = tt.peer
        WHERE tt.state = 1  -- Вход
          AND EXTRACT(MONTH FROM p.birthday) = EXTRACT(MONTH FROM tt.date)
    ),
    monthly_stats AS (
        SELECT 
            TO_CHAR(TO_DATE(be.entry_month::TEXT, 'MM'), 'Month') AS month_name,
            COUNT(*) FILTER (WHERE be.time < '12:00:00') AS early_entries,
            COUNT(*) AS total_entries
        FROM birthday_entries be
        GROUP BY be.entry_month
    ),
    all_months AS (
        -- Все 12 месяцев для полного результата
        SELECT 
            TO_CHAR(generate_series(1, 12), 'Month') AS month_name,
            0 AS early_entries,
            0 AS total_entries
    )
    SELECT 
        COALESCE(ms.month_name, am.month_name) AS month_name,
        ROUND(
            COALESCE(
                ms.early_entries::NUMERIC / NULLIF(ms.total_entries, 0) * 100,
                0
            ), 1
        ) AS early_entry_percent
    FROM all_months am
    LEFT JOIN monthly_stats ms ON TRIM(ms.month_name) = TRIM(am.month_name)
    ORDER BY TO_DATE(TRIM(COALESCE(ms.month_name, am.month_name)), 'Month');
END;
$$ LANGUAGE plpgsql;

