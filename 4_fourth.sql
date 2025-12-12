-- ============================================================================
-- СОЗДАНИЕ ТЕСТОВЫХ ТАБЛИЦ ДЛЯ ДЕМОНСТРАЦИИ
-- ============================================================================

-- Таблица 1 для тестирования процедуры удаления
CREATE TABLE IF NOT EXISTS del_table_1 (
    col1 TEXT,
    col2 TEXT,
    col3 TEXT
);

-- Таблица 2 для тестирования процедуры удаления
CREATE TABLE IF NOT EXISTS del_table_2 (
    col1 TEXT,
    col2 TEXT,
    col3 TEXT
);

-- Таблица с другим префиксом (не должна удаляться при вызове remove_table('del'))
CREATE TABLE IF NOT EXISTS table_del_1 (
    col1 TEXT,
    col2 TEXT,
    col3 TEXT
);

-- ============================================================================
-- 1. ПРОЦЕДУРА ДЛЯ УДАЛЕНИЯ ТАБЛИЦ ПО ПРЕФИКСУ ИМЕНИ
-- ============================================================================
-- Удаляет все таблицы в публичной схеме, имена которых начинаются с заданного префикса
DROP PROCEDURE IF EXISTS remove_table CASCADE;

CREATE OR REPLACE PROCEDURE remove_table(
    IN table_name_prefix TEXT  -- Префикс имени таблицы для удаления
)
AS $$
DECLARE
    target_table_name TEXT;  -- Переменная для хранения имени найденной таблицы
BEGIN
    -- Проходим по всем таблицам в публичной схеме, которые начинаются с заданного префикса
    FOR target_table_name IN 
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'           -- Только публичная схема
          AND table_type = 'BASE TABLE'         -- Только базовые таблицы (не представления)
          AND table_name LIKE table_name_prefix || '%'  -- Имена начинаются с префикса
    LOOP
        -- Динамически выполняем DROP TABLE для каждой найденной таблицы
        EXECUTE format('DROP TABLE IF EXISTS %I CASCADE', target_table_name);
        
        -- Логируем удаление (можно закомментировать в продакшене)
        RAISE NOTICE 'Таблица "%" успешно удалена', target_table_name;
    END LOOP;
    
    -- Если не найдено ни одной таблицы, информируем пользователя
    IF NOT FOUND THEN
        RAISE NOTICE 'Не найдено таблиц с префиксом "%"', table_name_prefix;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 2. ПРОЦЕДУРА ДЛЯ ПОДСЧЕТА ФУНКЦИЙ С ИХ ПАРАМЕТРАМИ
-- ============================================================================
-- Подсчитывает количество пользовательских функций и возвращает их список с параметрами
DROP PROCEDURE IF EXISTS list_functions_with_params CASCADE;

CREATE OR REPLACE PROCEDURE list_functions_with_params(
    OUT functions_count INTEGER,      -- Количество найденных функций
    OUT functions_list  TEXT          -- Список функций с параметрами (через ';')
)
AS $$
DECLARE
    func_record RECORD;               -- Запись для хранения информации о функции
    func_list   TEXT[] := ARRAY[]::TEXT[];  -- Массив для хранения описаний функций
BEGIN
    -- Инициализация выходных параметров
    functions_count := 0;
    functions_list := '';
    
    -- Собираем информацию обо всех пользовательских функциях
    FOR func_record IN
        SELECT 
            r.routine_name AS function_name,
            r.routine_type AS function_type,
            string_agg(
                CASE 
                    WHEN p.parameter_mode IS NOT NULL 
                    THEN format('%s %s %s', 
                               p.parameter_mode, 
                               p.parameter_name, 
                               p.data_type)
                    ELSE '()'
                END, 
                ', '
                ORDER BY p.ordinal_position
            ) AS parameters
        FROM information_schema.routines r
        LEFT JOIN information_schema.parameters p 
            ON r.specific_schema = p.specific_schema 
           AND r.specific_name = p.specific_name
        WHERE r.routine_schema = 'public'           -- Только публичная схема
          AND r.routine_type = 'FUNCTION'          -- Только функции (не процедуры)
        GROUP BY r.routine_name, r.routine_type, r.specific_name
        ORDER BY r.routine_name
    LOOP
        -- Увеличиваем счетчик функций
        functions_count := functions_count + 1;
        
        -- Формируем строку описания функции и добавляем в массив
        func_list := func_list || format(
            '%s %s(%s)',
            func_record.function_type,
            func_record.function_name,
            COALESCE(func_record.parameters, '')
        );
    END LOOP;
    
    -- Преобразуем массив в строку с разделителем ';'
    IF array_length(func_list, 1) > 0 THEN
        functions_list := array_to_string(func_list, '; ');
    END IF;
    
    RAISE NOTICE 'Найдено % пользовательских функций', functions_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 3. ПРОЦЕДУРА ДЛЯ УДАЛЕНИЯ ВСЕХ DML ТРИГГЕРОВ
-- ============================================================================
-- Удаляет все триггеры DML (INSERT/UPDATE/DELETE) в публичной схеме
DROP PROCEDURE IF EXISTS delete_all_dml_triggers CASCADE;

CREATE OR REPLACE PROCEDURE delete_all_dml_triggers(
    OUT deleted_triggers_count INTEGER  -- Количество удаленных триггеров
)
AS $$
DECLARE
    trig_record RECORD;  -- Запись для хранения информации о триггере
BEGIN
    -- Инициализируем счетчик
    deleted_triggers_count := 0;
    
    -- Собираем информацию о всех DML триггерах в публичной схеме
    FOR trig_record IN
        SELECT 
            DISTINCT trigger_name,
            event_object_table AS table_name
        FROM information_schema.triggers
        WHERE trigger_schema = 'public'           -- Только публичная схема
          AND event_manipulation IN ('INSERT', 'UPDATE', 'DELETE')  -- Только DML триггеры
        ORDER BY event_object_table, trigger_name
    LOOP
        -- Удаляем триггер с использованием форматирования для безопасности
        BEGIN
            EXECUTE format(
                'DROP TRIGGER IF EXISTS %I ON %I CASCADE',
                trig_record.trigger_name,
                trig_record.table_name
            );
            
            -- Увеличиваем счетчик успешно удаленных триггеров
            deleted_triggers_count := deleted_triggers_count + 1;
            
            -- Логируем удаление
            RAISE NOTICE 'Триггер "%" удален с таблицы "%"', 
                trig_record.trigger_name, 
                trig_record.table_name;
                
        EXCEPTION WHEN OTHERS THEN
            -- Логируем ошибки, но продолжаем выполнение
            RAISE WARNING 'Не удалось удалить триггер "%" на таблице "%": %',
                trig_record.trigger_name,
                trig_record.table_name,
                SQLERRM;
        END;
    END LOOP;
    
    -- Если не найдено ни одного триггера
    IF deleted_triggers_count = 0 THEN
        RAISE NOTICE 'DML триггеры не найдены в публичной схеме';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. ПРОЦЕДУРА ДЛЯ ПОИСКА ОБЪЕКТОВ БАЗЫ ДАННЫХ ПО ТЕКСТУ В ОПРЕДЕЛЕНИИ
-- ============================================================================
-- Ищет хранимые процедуры и функции, содержащие указанный текст в своем теле
DROP PROCEDURE IF EXISTS search_objects_by_content CASCADE;

CREATE OR REPLACE PROCEDURE search_objects_by_content(
    IN search_text TEXT,      -- Текст для поиска в определениях объектов
    INOUT result_cursor REFCURSOR  -- Курсор для возврата результатов
)
AS $$
BEGIN
    -- Открываем курсор с результатами поиска
    OPEN result_cursor FOR
        SELECT 
            r.routine_name AS object_name,
            r.routine_type AS object_type,
            r.data_type AS return_type,
            r.external_language AS language
        FROM information_schema.routines r
        WHERE r.specific_schema = 'public'                  -- Только публичная схема
          AND (
                -- Ищем в теле функции/процедуры (если доступно)
                r.routine_definition ILIKE '%' || search_text || '%'
                OR 
                -- Или в комментариях (через системные таблицы)
                EXISTS (
                    SELECT 1 
                    FROM pg_description pd
                    JOIN pg_proc pp ON pd.objoid = pp.oid
                    WHERE pp.proname = r.routine_name
                      AND pd.description ILIKE '%' || search_text || '%'
                )
          )
        ORDER BY 
            CASE r.routine_type 
                WHEN 'PROCEDURE' THEN 1 
                WHEN 'FUNCTION' THEN 2 
                ELSE 3 
            END,
            r.routine_name;
    
    -- Информируем о результате поиска
    RAISE NOTICE 'Поиск объектов, содержащих текст: "%"', search_text;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 5. ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ ДЛЯ ПОЛУЧЕНИЯ ПОЛНОГО ОПРЕДЕЛЕНИЯ ОБЪЕКТА
-- ============================================================================
-- Возвращает полный текст определения функции или процедуры
CREATE OR REPLACE FUNCTION get_object_definition(
    object_name TEXT,      -- Имя объекта (функции или процедуры)
    object_type TEXT DEFAULT NULL  -- Тип объекта ('FUNCTION' или 'PROCEDURE')
)
RETURNS TABLE (
    object_name TEXT,
    object_type TEXT,
    definition  TEXT,
    language    TEXT
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.routine_name::TEXT,
        r.routine_type::TEXT,
        COALESCE(
            r.routine_definition,
            pg_get_functiondef(p.oid)::TEXT
        ) AS definition,
        r.external_language::TEXT AS language
    FROM information_schema.routines r
    LEFT JOIN pg_proc p ON r.routine_name = p.proname
    WHERE r.specific_schema = 'public'
      AND r.routine_name = get_object_definition.object_name
      AND (get_object_definition.object_type IS NULL 
           OR r.routine_type = get_object_definition.object_type)
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 6. ПРОЦЕДУРА ДЛЯ ОЧИСТКИ ТЕСТОВЫХ ДАННЫХ (ДОПОЛНИТЕЛЬНАЯ)
-- ============================================================================
-- Безопасно удаляет все тестовые таблицы, созданные для демонстрации
DROP PROCEDURE IF EXISTS cleanup_test_tables CASCADE;

CREATE OR REPLACE PROCEDURE cleanup_test_tables()
AS $$
BEGIN
    -- Удаляем тестовые таблицы в определенном порядке (при необходимости)
    DROP TABLE IF EXISTS del_table_1 CASCADE;
    DROP TABLE IF EXISTS del_table_2 CASCADE;
    DROP TABLE IF EXISTS table_del_1 CASCADE;
    
    RAISE NOTICE 'Тестовые таблицы успешно удалены';
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- ПРИМЕР ИСПОЛЬЗОВАНИЯ ВСЕХ ПРОЦЕДУР
-- ============================================================================
/*
-- 1. Создаем тестовые таблицы
SELECT 'Создание тестовых таблиц...' AS info;
-- (Таблицы уже созданы в начале файла)

-- 2. Показываем список функций
SELECT 'Список функций с параметрами:' AS info;
DO $$
DECLARE
    func_count INTEGER;
    func_list TEXT;
BEGIN
    CALL list_functions_with_params(func_count, func_list);
    RAISE NOTICE 'Количество функций: %', func_count;
    RAISE NOTICE 'Список: %', func_list;
END $$;

-- 3. Поиск объектов по содержимому
SELECT 'Поиск объектов содержащих "table":' AS info;
BEGIN
    CALL search_objects_by_content('table', 'my_cursor');
    FETCH ALL FROM my_cursor;
END;

-- 4. Удаление таблиц по префиксу
SELECT 'Удаление таблиц с префиксом "del":' AS info;
CALL remove_table('del');

-- 5. Проверка наличия таблиц после удаления
SELECT 'Оставшиеся таблицы:' AS info;
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- 6. Очистка всех тестовых данных
SELECT 'Полная очистка тестовых данных:' AS info;
CALL cleanup_test_tables();
*/
