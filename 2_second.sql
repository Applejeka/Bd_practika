/* 
=============================================
1. ПРОЦЕДУРА ДОБАВЛЕНИЯ P2P ПРОВЕРКИ
=============================================
Параметры: 
  - checked_peer: ник проверяемого
  - checking_peer: ник проверяющего
  - task_name: название задания
  - p2p_status: статус P2P проверки
  - p2p_time: время проверки
Логика:
  - Если статус "Start": создается новая проверка
  - Если статус другой: добавляется результат к существующей проверке
  - Проверяет, что нет незавершенных проверок между этими пирами
=============================================
*/

CREATE OR REPLACE PROCEDURE add_peer_review(
    checked_peer VARCHAR,       -- Пир, которого проверяют
    checking_peer VARCHAR,      -- Пир, который проверяет
    task_name TEXT,             -- Название задания
    p2p_status check_status,    -- Статус проверки (Start/Success/Failure)
    p2p_time TIME               -- Время проверки
) AS $$
DECLARE
    check_id BIGINT;            -- ID создаваемой или используемой проверки
    unfinished_check_exists BOOLEAN; -- Флаг наличия незавершенной проверки
BEGIN
    -- Проверяем, есть ли незавершенная проверка между этими пирами по этому заданию
    SELECT EXISTS (
        SELECT 1 
        FROM p2p
        JOIN checks ON p2p.checkid = checks.id
        WHERE p2p.checkingpeer = checking_peer
            AND checks.peer = checked_peer
            AND checks.task = task_name
            AND p2p.state != 'Success'  -- Исключаем успешные проверки
    ) INTO unfinished_check_exists;
    
    IF p2p_status = 'Start' THEN
        -- ============ СТАТУС "START" ============
        -- Создаем новую проверку
        
        IF unfinished_check_exists THEN
            -- Если есть незавершенная проверка, нельзя начать новую
            RAISE EXCEPTION 'Ошибка: у пира % уже есть незавершенная проверка задания % от пира %', 
                checked_peer, task_name, checking_peer;
        END IF;
        
        -- Создаем новую запись в таблице Checks
        INSERT INTO checks (peer, task, date)
        VALUES (checked_peer, task_name, CURRENT_DATE)
        RETURNING id INTO check_id;
        
        -- Создаем запись в таблице P2P со статусом "Start"
        INSERT INTO p2p (checkid, checkingpeer, state, time)
        VALUES (check_id, checking_peer, p2p_status, p2p_time);
        
    ELSE
        -- ============ СТАТУС "SUCCESS" ИЛИ "FAILURE" ============
        -- Добавляем результат к существующей проверке
        
        IF NOT unfinished_check_exists THEN
            -- Если нет незавершенной проверки, нельзя добавить результат
            RAISE EXCEPTION 'Ошибка: не найдена начатая проверка задания % у пира % от пира %', 
                task_name, checked_peer, checking_peer;
        END IF;
        
        -- Находим ID незавершенной проверки
        SELECT checks.id INTO check_id
        FROM p2p
        JOIN checks ON p2p.checkid = checks.id
        WHERE p2p.checkingpeer = checking_peer
            AND checks.peer = checked_peer
            AND checks.task = task_name
            AND p2p.state = 'Start'  -- Ищем именно начатую проверку
        ORDER BY p2p.time DESC
        LIMIT 1;
        
        -- Добавляем результат проверки
        INSERT INTO p2p (checkid, checkingpeer, state, time)
        VALUES (check_id, checking_peer, p2p_status, p2p_time);
        
    END IF;
    
    RAISE NOTICE 'P2P проверка успешно добавлена. Check ID: %', check_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE add_verter_review(
    checked_peer VARCHAR,       -- Пир, которого проверяют
    task_name TEXT,             -- Название задания
    verter_status check_status, -- Статус проверки Verter
    verter_time TIME            -- Время проверки
) AS $$
DECLARE
    check_id BIGINT;            -- ID проверки для добавления Verter
    last_successful_p2p_time TIME; -- Время последней успешной P2P проверки
BEGIN
    -- Находим последнюю успешную P2P проверку по этому заданию
    SELECT 
        checks.id,
        MAX(p2p.time)
    INTO
        check_id,
        last_successful_p2p_time
    FROM p2p
    JOIN checks ON p2p.checkid = checks.id
    WHERE checks.peer = checked_peer
        AND checks.task = task_name
        AND p2p.state = 'Success'
    GROUP BY checks.id
    ORDER BY MAX(p2p.time) DESC
    LIMIT 1;
    
    -- Проверяем, найдена ли успешная P2P проверка
    IF check_id IS NULL THEN
        RAISE EXCEPTION 'Ошибка: не найдена успешная P2P проверка задания % у пира %', 
            task_name, checked_peer;
    END IF;
    
    IF verter_status = 'Start' THEN
        -- ============ СТАТУС "START" ============
        -- Начинаем новую проверку Verter
        
        -- Проверяем, нет ли уже начатой проверки Verter для этой проверки
        IF EXISTS (
            SELECT 1 
            FROM verter 
            WHERE checkid = check_id 
                AND state = 'Start'
        ) THEN
            RAISE EXCEPTION 'Ошибка: проверка Verter для check_id % уже начата', check_id;
        END IF;
        
        -- Добавляем начало проверки Verter
        INSERT INTO verter (checkid, state, time)
        VALUES (check_id, verter_status, verter_time);
        
    ELSE
        -- ============ СТАТУС "SUCCESS" ИЛИ "FAILURE" ============
        -- Добавляем результат проверки Verter
        
        -- Проверяем, есть ли начатая проверка Verter
        IF NOT EXISTS (
            SELECT 1 
            FROM verter 
            WHERE checkid = check_id 
                AND state = 'Start'
        ) THEN
            RAISE EXCEPTION 'Ошибка: не найдена начатая проверка Verter для check_id %', check_id;
        END IF;
        
        -- Добавляем результат проверки Verter
        INSERT INTO verter (checkid, state, time)
        VALUES (check_id, verter_status, verter_time);
        
    END IF;
    
    RAISE NOTICE 'Проверка Verter успешно добавлена. Check ID: %, Время последней успешной P2P: %', 
        check_id, last_successful_p2p_time;
END;
$$ LANGUAGE plpgsql;

-- Функция-триггер для обновления TransferredPoints
CREATE OR REPLACE FUNCTION fnc_update_transferredpoints_on_p2p_start()
RETURNS TRIGGER AS $$
DECLARE
    checked_peer VARCHAR;  -- Пир, которого проверяют
BEGIN
    -- Находим пира, которого проверяют, по ID проверки
    SELECT peer INTO checked_peer
    FROM checks
    WHERE id = NEW.checkid;
    
    -- Проверяем, что это начало новой проверки
    IF NEW.state = 'Start' THEN
        -- Проверяем, существует ли уже запись для этой пары пиров
        IF EXISTS (
            SELECT 1 
            FROM transferredpoints
            WHERE checkingpeer = NEW.checkingpeer
                AND checkedpeer = checked_peer
        ) THEN
            -- Если запись существует - увеличиваем счетчик
            UPDATE transferredpoints
            SET pointsamount = pointsamount + 1
            WHERE checkingpeer = NEW.checkingpeer
                AND checkedpeer = checked_peer;
                
            RAISE NOTICE 'Обновлены передаваемые очки: % -> %, теперь: % очков',
                NEW.checkingpeer,
                checked_peer,
                (SELECT pointsamount 
                 FROM transferredpoints 
                 WHERE checkingpeer = NEW.checkingpeer 
                    AND checkedpeer = checked_peer) + 1;
        ELSE
            -- Если записи нет - создаем новую
            INSERT INTO transferredpoints (checkingpeer, checkedpeer, pointsamount)
            VALUES (NEW.checkingpeer, checked_peer, 1);
            
            RAISE NOTICE 'Создана новая запись передаваемых очков: % -> %, 1 очко',
                NEW.checkingpeer, checked_peer;
        END IF;
    END IF;
    
    RETURN NEW;  -- Возвращаем новую запись для продолжения операций
END;
$$ LANGUAGE plpgsql;

-- Создание триггера на таблице P2P
CREATE OR REPLACE TRIGGER trg_update_transferredpoints
AFTER INSERT ON p2p
FOR EACH ROW
EXECUTE FUNCTION fnc_update_transferredpoints_on_p2p_start();

-- Функция-триггер для проверки корректности XP
CREATE OR REPLACE FUNCTION fnc_validate_xp_before_insert()
RETURNS TRIGGER AS $$
DECLARE
    max_xp_for_task INTEGER;       -- Максимальный XP для задания
    p2p_status check_status;       -- Статус P2P проверки
    verter_status check_status;    -- Статус Verter проверки
    task_title VARCHAR;            -- Название задания
BEGIN
    -- Получаем информацию о проверке
    SELECT 
        tasks.maxxp,
        tasks.title,
        (SELECT state FROM p2p WHERE checkid = NEW.checkid AND state != 'Start' ORDER BY time DESC LIMIT 1),
        (SELECT state FROM verter WHERE checkid = NEW.checkid AND state != 'Start' ORDER BY time DESC LIMIT 1)
    INTO
        max_xp_for_task,
        task_title,
        p2p_status,
        verter_status
    FROM checks
    JOIN tasks ON checks.task = tasks.title
    WHERE checks.id = NEW.checkid;
    
    -- Проверка 1: XP не должен превышать максимум для задания
    IF NEW.xpamount > max_xp_for_task THEN
        RAISE EXCEPTION 'Ошибка: количество XP (%) превышает максимальное для задания "%" (%)', 
            NEW.xpamount, task_title, max_xp_for_task;
    END IF;
    
    -- Проверка 2: Должна быть успешная P2P проверка
    IF p2p_status IS NULL OR p2p_status != 'Success' THEN
        RAISE EXCEPTION 'Ошибка: проверка не содержит успешной P2P проверки или P2P проверка не завершена';
    END IF;
    
    -- Проверка 3: Если есть проверка Verter, она должна быть успешной
    IF verter_status IS NOT NULL AND verter_status != 'Success' THEN
        RAISE EXCEPTION 'Ошибка: проверка Verter не успешна (статус: %)', verter_status;
    END IF;
    
    -- Проверка 4: XP должен быть положительным
    IF NEW.xpamount <= 0 THEN
        RAISE EXCEPTION 'Ошибка: количество XP должно быть положительным';
    END IF;
    
    RAISE NOTICE 'XP проверен и будет добавлен: % XP за задание "%"', 
        NEW.xpamount, task_title;
    
    RETURN NEW;  -- Разрешаем вставку
END;
$$ LANGUAGE plpgsql;

-- Создание триггера на таблице XP
CREATE OR REPLACE TRIGGER trg_validate_xp_before_insert
BEFORE INSERT ON xp
FOR EACH ROW
EXECUTE FUNCTION fnc_validate_xp_before_insert();
