-- =============================================
-- СОЗДАНИЕ ТАБЛИЦЫ PEERS (ПИРЫ)
-- =============================================
CREATE TABLE Peers
(
    Nickname VARCHAR NOT NULL PRIMARY KEY, -- Уникальный никнейм пира
    Birthday DATE NOT NULL                  -- Дата рождения пира
);

-- Заполнение таблицы Peers тестовыми данными
INSERT INTO Peers (Nickname, Birthday)
VALUES 
    ('peer1', '1990-01-01'),
    ('peer2', '1990-01-02'),
    ('peer3', '1990-01-03'),
    ('peer4', '1990-01-04'),
    ('peer5', '1990-01-05'),
    ('peer6', '1990-01-06'),
    ('peer7', '1990-01-07'),
    ('peer8', '1990-01-08'),
    ('peer9', '1990-01-09'),
    ('peer10', '1990-01-10');
-- Дополнительные пиры для тестирования (закомментированы)
-- ('peera', '1990-01-10'),
-- ('peerb', '1990-01-10');

-- =============================================
-- СОЗДАНИЕ ТАБЛИЦЫ TASKS (ЗАДАНИЯ)
-- =============================================
CREATE TABLE Tasks
(
    Title      VARCHAR PRIMARY KEY,      -- Название задания
    ParentTask VARCHAR,                  -- Родительское задание (если есть)
    MaxXP      INTEGER NOT NULL,         -- Максимальное количество XP за задание
    FOREIGN KEY (ParentTask) REFERENCES Tasks (Title) ON DELETE SET NULL
);

-- Заполнение таблицы Tasks тестовыми данными (задания School 21)
INSERT INTO Tasks VALUES 
    ('C2_SimpleBashUtils', NULL, 250),
    ('C3_s21_string+', 'C2_SimpleBashUtils', 500),
    ('C4_s21_math', 'C2_SimpleBashUtils', 300),
    ('C5_s21_decimal', 'C4_s21_math', 350),
    ('C6_s21_matrix', 'C5_s21_decimal', 200),
    ('C7_SmartCalc_v1.0', 'C6_s21_matrix', 500),
    ('C8_3DViewer_v1.0', 'C7_SmartCalc_v1.0', 750),
    ('DO1_Linux', 'C3_s21_string+', 300),
    ('DO2_Linux Network', 'DO1_Linux', 250),
    ('DO3_LinuxMonitoring v1.0', 'DO2_Linux Network', 350),
    ('DO4_LinuxMonitoring v2.0', 'DO3_LinuxMonitoring v1.0', 350),
    ('DO5_SimpleDocker', 'DO3_LinuxMonitoring v1.0', 300),
    ('DO6_CICD', 'DO5_SimpleDocker', 300),
    ('CPP1_s21_matrix+', 'C8_3DViewer_v1.0', 300),
    ('CPP2_s21_containers', 'CPP1_s21_matrix+', 350),
    ('CPP3_SmartCalc_v2.0', 'CPP2_s21_containers', 600),
    ('CPP4_3DViewer_v2.0', 'CPP3_SmartCalc_v2.0', 750),
    ('CPP5_3DViewer_v2.1', 'CPP4_3DViewer_v2.0', 600),
    ('CPP6_3DViewer_v2.2', 'CPP4_3DViewer_v2.0', 800),
    ('CPP7_MLP', 'CPP4_3DViewer_v2.0', 700),
    ('CPP8_PhotoLab_v1.0', 'CPP4_3DViewer_v2.0', 450),
    ('CPP9_MonitoringSystem', 'CPP4_3DViewer_v2.0', 1000),
    ('A1_Maze', 'CPP4_3DViewer_v2.0', 300),
    ('A2_SimpleNavigator v1.0', 'A1_Maze', 400),
    ('A3_Parallels', 'A2_SimpleNavigator v1.0', 300),
    ('A4_Crypto', 'A2_SimpleNavigator v1.0', 350),
    ('A5_s21_memory', 'A2_SimpleNavigator v1.0', 400),
    ('A6_Transactions', 'A2_SimpleNavigator v1.0', 700),
    ('A7_DNA Analyzer', 'A2_SimpleNavigator v1.0', 800),
    ('A8_Algorithmic trading', 'A2_SimpleNavigator v1.0', 800),
    ('SQL1_Bootcamp', 'C8_3DViewer_v1.0', 1500),
    ('SQL2_Info21 v1.0', 'SQL1_Bootcamp', 500),
    ('SQL3_RetailAnalitycs v1.0', 'SQL2_Info21 v1.0', 600);

-- =============================================
-- СОЗДАНИЕ ТИПА CHECK_STATUS (СТАТУС ПРОВЕРКИ)
-- =============================================
CREATE TYPE check_status AS ENUM ('Start', 'Success', 'Failure');

-- =============================================
-- СОЗДАНИЕ ТАБЛИЦЫ CHECKS (ПРОВЕРКИ)
-- =============================================
CREATE TABLE Checks
(
    ID   BIGSERIAL PRIMARY KEY,    -- Уникальный ID проверки
    Peer VARCHAR NOT NULL,          -- Пир, который проходит проверку
    Task VARCHAR NOT NULL,          -- Задание, которое проверяется
    Date DATE NOT NULL DEFAULT CURRENT_DATE, -- Дата проверки
    FOREIGN KEY (Peer) REFERENCES Peers (Nickname),
    FOREIGN KEY (Task) REFERENCES Tasks (Title)
);

-- Заполнение таблицы Checks тестовыми данными
INSERT INTO Checks (peer, task, date) VALUES 
    ('peer1', 'C2_SimpleBashUtils', '2023-03-01'),
    ('peer1', 'C2_SimpleBashUtils', '2023-03-02'),
    ('peer2', 'C4_s21_math', '2023-03-02'),
    ('peer3', 'C2_SimpleBashUtils', '2023-03-03'),
    ('peer3', 'C3_s21_string+', '2023-03-04'),
    ('peer4', 'DO1_Linux', '2023-03-05'),
    ('peer5', 'DO2_Linux Network', '2023-03-05'),
    ('peer6', 'DO2_Linux Network', '2023-03-05'),
    ('peer7', 'DO3_LinuxMonitoring v1.0', '2023-03-07'),
    ('peer8', 'C5_s21_decimal', '2023-03-08'),
    ('peer9', 'C3_s21_string+', '2023-03-08'),
    ('peer10', 'C4_s21_math', '2023-03-08'),
    ('peer2', 'C3_s21_string+', '2023-03-08'),
    ('peer3', 'DO1_Linux', '2023-03-09'),
    ('peer1', 'C6_s21_matrix', '2023-03-10'),
    ('peer8', 'DO1_Linux', '2023-03-10'),
    ('peer5', 'C2_SimpleBashUtils', '2023-03-12'),
    ('peer4', 'C6_s21_matrix', '2023-04-01'),
    ('peer7', 'DO1_Linux', '2023-04-05'),
    ('peer10', 'C3_s21_string+', '2023-04-06'),
    ('peer7', 'DO2_Linux Network', '2023-04-06'),
    ('peer7', 'DO3_LinuxMonitoring v1.0', '2023-04-07'),
    ('peer7', 'DO4_LinuxMonitoring v2.0', '2023-04-08'),
    ('peer7', 'DO5_SimpleDocker', '2023-04-09'),
    ('peer7', 'DO6_CICD', '2023-04-10'),
    ('peer3', 'C4_s21_math', '2023-04-06'),
    ('peer3', 'C5_s21_decimal', '2023-03-07'),
    ('peer3', 'C6_s21_matrix', '2023-03-08'),
    ('peer3', 'C7_SmartCalc_v1.0', '2023-03-09'),
    ('peer3', 'C8_3DViewer_v1.0', '2023-03-10');

-- =============================================
-- СОЗДАНИЕ ТАБЛИЦЫ P2P (P2P ПРОВЕРКИ)
-- =============================================
CREATE TABLE P2P
(
    ID           BIGSERIAL PRIMARY KEY,      -- Уникальный ID P2P проверки
    CheckID      BIGINT NOT NULL,            -- ID основной проверки
    CheckingPeer VARCHAR NOT NULL,           -- Пир, который проверяет
    State        check_status NOT NULL,      -- Статус проверки
    Time         TIME NOT NULL,              -- Время проверки
    FOREIGN KEY (CheckID) REFERENCES Checks (ID) ON DELETE CASCADE,
    FOREIGN KEY (CheckingPeer) REFERENCES Peers (Nickname)
);

-- Заполнение таблицы P2P тестовыми данными
INSERT INTO P2P (CheckID, CheckingPeer, State, Time) VALUES 
    (1, 'peer2', 'Start', '09:00:00'),
    (2, 'peer2', 'Failure', '10:00:00'),      -- Пир завалил проверку
    (3, 'peer3', 'Start', '13:00:00'),
    (4, 'peer3', 'Success', '14:00:00'),
    (5, 'peer1', 'Start', '22:00:00'),
    (6, 'peer1', 'Success', '23:00:00'),
    (7, 'peer4', 'Start', '15:00:00'),
    (8, 'peer4', 'Success', '16:00:00'),      -- Verter завалит дальше
    (9, 'peer5', 'Start', '14:00:00'),
    (10, 'peer5', 'Success', '15:00:00'),
    (11, 'peer6', 'Start', '01:00:00'),
    (12, 'peer6', 'Success', '02:00:00'),
    (13, 'peer7', 'Start', '10:00:00'),
    (14, 'peer7', 'Success', '12:00:00'),
    (15, 'peer8', 'Start', '12:00:00'),
    (16, 'peer8', 'Success', '13:00:00'),
    (17, 'peer9', 'Start', '12:00:00'),
    (18, 'peer9', 'Success', '13:00:00'),
    (19, 'peer10', 'Start', '19:00:00'),
    (20, 'peer5', 'Start', '15:00:00'),
    (21, 'peer5', 'Success', '15:01:00'),
    (22, 'peer7', 'Start', '22:00:00'),
    (23, 'peer7', 'Failure', '23:00:00'),
    (24, 'peer4', 'Start', '22:00:00'),
    (25, 'peer4', 'Success', '23:00:00'),
    (26, 'peer1', 'Start', '22:00:00'),
    (27, 'peer1', 'Success', '23:00:00'),
    (28, 'peer9', 'Start', '04:00:00'),
    (29, 'peer9', 'Success', '05:00:00'),
    (30, 'peer1', 'Start', '05:00:00'),
    (31, 'peer1', 'Failure', '06:00:00'),
    (32, 'peer7', 'Start', '07:00:00'),
    (33, 'peer7', 'Success', '08:00:00'),
    (34, 'peer10', 'Start', '08:00:00'),
    (35, 'peer10', 'Success', '09:00:00'),
    (36, 'peer2', 'Start', '09:00:00'),
    (37, 'peer2', 'Success', '10:00:00'),
    (38, 'peer6', 'Start', '11:00:00'),
    (39, 'peer1', 'Start', '11:00:00'),
    (40, 'peer1', 'Success', '12:00:00'),
    (41, 'peer2', 'Start', '05:00:00'),
    (42, 'peer2', 'Success', '06:00:00'),
    (43, 'peer3', 'Start', '10:00:00'),
    (44, 'peer3', 'Success', '11:00:00'),
    (45, 'peer4', 'Start', '11:00:00'),
    (46, 'peer4', 'Success', '12:00:00'),
    (47, 'peer5', 'Start', '18:00:00'),
    (48, 'peer5', 'Success', '19:00:00'),
    (49, 'peer6', 'Start', '15:00:00'),
    (50, 'peer6', 'Success', '16:00:00'),
    (51, 'peer7', 'Start', '13:00:00'),
    (52, 'peer7', 'Success', '14:00:00'),
    (53, 'peer8', 'Start', '13:00:00'),
    (54, 'peer8', 'Success', '14:00:00'),
    (55, 'peer9', 'Start', '16:00:00'),
    (56, 'peer9', 'Success', '17:00:00'),
    (57, 'peer10', 'Start', '22:00:00'),
    (58, 'peer10', 'Success', '23:00:00');

-- =============================================
-- СОЗДАНИЕ ТАБЛИЦЫ VERTER (АВТОМАТИЧЕСКИЕ ПРОВЕРКИ)
-- =============================================
CREATE TABLE Verter
(
    ID      BIGSERIAL PRIMARY KEY,   -- Уникальный ID Verter проверки
    CheckID BIGINT  NOT NULL,        -- ID основной проверки
    State   check_status NOT NULL,   -- Статус проверки
    Time    TIME    NOT NULL,        -- Время проверки
    FOREIGN KEY (CheckID) REFERENCES Checks (ID) ON DELETE CASCADE
);

-- Заполнение таблицы Verter тестовыми данными
INSERT INTO Verter (CheckID, State, Time) VALUES 
    (2, 'Start', '13:01:00'),
    (2, 'Success', '13:02:00'),
    (3, 'Start', '23:01:00'),
    (3, 'Success', '23:02:00'),
    (4, 'Start', '16:01:00'),
    (4, 'Failure', '16:02:00'),      -- Автоматическая проверка не пройдена
    (5, 'Start', '15:01:00'),
    (5, 'Success', '15:02:00'),
    (13, 'Start', '23:01:00'),
    (13, 'Success', '23:02:00'),
    (15, 'Start', '05:01:00'),
    (15, 'Failure', '05:02:00'),
    (17, 'Start', '06:01:00'),
    (17, 'Success', '06:02:00'),
    (18, 'Start', '06:01:00'),
    (18, 'Success', '06:02:00'),
    (19, 'Start', '06:01:00'),
    (19, 'Failure', '06:02:00'),
    (21, 'Start', '12:01:00'),
    (21, 'Success', '12:02:00'),
    (22, 'Start', '06:01:00'),
    (22, 'Success', '06:02:00'),
    (23, 'Start', '11:01:00'),
    (23, 'Success', '11:02:00'),
    (24, 'Start', '12:01:00'),
    (24, 'Success', '12:02:00'),
    (25, 'Start', '19:01:00'),
    (25, 'Success', '19:02:00'),
    (26, 'Start', '16:01:00'),
    (26, 'Success', '16:02:00'),
    (27, 'Start', '14:01:00'),
    (27, 'Success', '14:02:00'),
    (28, 'Start', '14:01:00'),
    (28, 'Success', '14:02:00'),
    (29, 'Start', '17:01:00'),
    (29, 'Success', '17:02:00'),
    (30, 'Start', '23:01:00'),
    (30, 'Success', '23:02:00');

-- =============================================
-- СОЗДАНИЕ ТАБЛИЦЫ TRANSFERREDPOINTS (ПЕРЕДАЧА ОЧКОВ)
-- =============================================
CREATE TABLE TransferredPoints
(
    ID           BIGSERIAL PRIMARY KEY,   -- Уникальный ID записи
    CheckingPeer VARCHAR NOT NULL,        -- Пир, который проверял
    CheckedPeer  VARCHAR NOT NULL,        -- Пир, которого проверяли
    PointsAmount INTEGER NOT NULL,        -- Количество переданных очков
    FOREIGN KEY (CheckingPeer) REFERENCES Peers (Nickname),
    FOREIGN KEY (CheckedPeer) REFERENCES Peers (Nickname)
);

-- Автоматическое заполнение на основе P2P проверок
-- Учитываются завершенные проверки (не статус 'Start')
INSERT INTO TransferredPoints (CheckingPeer, CheckedPeer, PointsAmount)
SELECT checkingpeer, Peer, COUNT(*)
FROM P2P
JOIN Checks C ON C.ID = P2P.CheckID
WHERE State != 'Start'
GROUP BY CheckingPeer, Peer;

-- =============================================
-- СОЗДАНИЕ ТАБЛИЦЫ FRIENDS (ДРУЗЬЯ)
-- =============================================
CREATE TABLE Friends
(
    ID    BIGSERIAL PRIMARY KEY,   -- Уникальный ID дружбы
    Peer1 VARCHAR NOT NULL,        -- Первый пир
    Peer2 VARCHAR NOT NULL,        -- Второй пир
    FOREIGN KEY (Peer1) REFERENCES Peers (Nickname),
    FOREIGN KEY (Peer2) REFERENCES Peers (Nickname),
    CHECK (Peer1 != Peer2)         -- Проверка, что пир не дружит сам с собой
);

-- Автоматическое создание всех возможных пар друзей
INSERT INTO Friends (Peer1, Peer2)
SELECT p1.Nickname, p2.Nickname
FROM Peers p1
CROSS JOIN Peers p2
WHERE p1.Nickname < p2.Nickname;  -- Исключаем дубликаты (A-B и B-A)

-- =============================================
-- СОЗДАНИЕ ТАБЛИЦЫ RECOMMENDATIONS (РЕКОМЕНДАЦИИ)
-- =============================================
CREATE TABLE Recommendations
(
    ID              BIGSERIAL PRIMARY KEY,  -- Уникальный ID рекомендации
    Peer            VARCHAR NOT NULL,       -- Пир, который рекомендует
    RecommendedPeer VARCHAR NOT NULL,       -- Рекомендуемый пир
    FOREIGN KEY (Peer) REFERENCES Peers (Nickname),
    FOREIGN KEY (RecommendedPeer) REFERENCES Peers (Nickname),
    CHECK (Peer != RecommendedPeer)         -- Пир не может рекомендовать себя
);

-- Заполнение таблицы Recommendations тестовыми данными
INSERT INTO Recommendations (Peer, RecommendedPeer) VALUES 
    ('peer1', 'peer2'),
    ('peer1', 'peer3'),
    ('peer2', 'peer5'),
    ('peer3', 'peer5'),
    ('peer4', 'peer1'),
    ('peer5', 'peer10'),
    ('peer6', 'peer4'),
    ('peer7', 'peer5'),
    ('peer8', 'peer1'),
    ('peer9', 'peer6');

-- =============================================
-- СОЗДАНИЕ ТАБЛИЦЫ XP (ОПЫТ)
-- =============================================
CREATE TABLE XP
(
    ID       BIGSERIAL PRIMARY KEY,  -- Уникальный ID записи XP
    CheckID  BIGINT  NOT NULL,       -- ID проверки
    XPAmount INTEGER NOT NULL,       -- Количество полученного XP
    FOREIGN KEY (CheckID) REFERENCES Checks (ID) ON DELETE CASCADE,
    CHECK (XPAmount > 0)             -- XP должен быть положительным
);

-- Заполнение таблицы XP тестовыми данными
INSERT INTO XP (CheckID, XPAmount) VALUES 
    (2, 240),
    (3, 300),
    (5, 200),
    (6, 250),
    (7, 250),
    (8, 250),
    (9, 350),
    (11, 450),
    (13, 500),
    (14, 300),
    (17, 250),
    (18, 150),
    (21, 250),
    (22, 350),
    (23, 350),
    (24, 300),
    (25, 300),
    (26, 300),
    (27, 350),
    (28, 200),
    (29, 500),
    (30, 750);

-- =============================================
-- СОЗДАНИЕ ТАБЛИЦЫ TIMETRACKING (УЧЕТ ВРЕМЕНИ)
-- =============================================
CREATE TABLE TimeTracking
(
    ID     BIGSERIAL PRIMARY KEY,  -- Уникальный ID записи
    Peer   VARCHAR NOT NULL,       -- Пир
    Date   DATE NOT NULL,          -- Дата посещения
    Time   TIME NOT NULL,          -- Время входа/выхода
    State  INTEGER NOT NULL CHECK (State IN (1, 2)), -- 1 = вход, 2 = выход
    FOREIGN KEY (Peer) REFERENCES Peers (Nickname)
);

-- Заполнение таблицы TimeTracking тестовыми данными
INSERT INTO TimeTracking (Peer, Date, Time, State) VALUES 
    ('peer1', '2023-03-02', '08:00:00', 1),
    ('peer1', '2023-03-02', '18:00:00', 2),
    ('peer2', '2023-03-02', '18:30:00', 1),
    ('peer2', '2023-03-02', '23:30:00', 2),
    ('peer4', '2023-04-02', '18:10:00', 1),
    ('peer4', '2023-04-02', '21:00:00', 2),
    ('peer3', '2023-04-22', '10:00:00', 1),
    ('peer5', '2023-04-22', '11:00:00', 1),
    ('peer5', '2023-04-22', '21:00:00', 2),
    ('peer3', '2023-04-22', '23:00:00', 2),
    ('peer7', '2023-05-02', '18:10:00', 1),
    ('peer7', '2023-05-02', '21:00:00', 2),
    ('peer7', '2023-05-02', '22:10:00', 1),
    ('peer7', '2023-05-02', '23:50:00', 2);

-- =============================================
-- ПРОЦЕДУРА ЭКСПОРТА ДАННЫХ В CSV
-- =============================================
CREATE OR REPLACE PROCEDURE export_data(
    IN table_name VARCHAR,   -- Название таблицы для экспорта
    IN file_path TEXT,       -- Путь к файлу для сохранения
    IN delimiter CHAR        -- Разделитель полей
) AS $$
BEGIN
    -- Динамическое выполнение команды COPY для экспорта
    EXECUTE format('COPY %I TO %L DELIMITER %L CSV HEADER;', 
                   table_name, file_path, delimiter);
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- ПРОЦЕДУРА ИМПОРТА ДАННЫХ ИЗ CSV
-- =============================================
CREATE OR REPLACE PROCEDURE import_data(
    IN table_name VARCHAR,   -- Название таблицы для импорта
    IN file_path TEXT,       -- Путь к файлу с данными
    IN delimiter CHAR        -- Разделитель полей
) AS $$
BEGIN
    -- Динамическое выполнение команды COPY для импорта
    EXECUTE format('COPY %I FROM %L DELIMITER %L CSV HEADER;', 
                   table_name, file_path, delimiter);
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- ПРИМЕРЫ ИСПОЛЬЗОВАНИЯ (ЗАКОММЕНТИРОВАНЫ)
-- =============================================

-- Экспорт всех таблиц в CSV файлы
-- CALL export_data('peers', '/path/to/peers.csv', ',');
-- CALL export_data('tasks', '/path/to/tasks.csv', ',');
-- CALL export_data('checks', '/path/to/checks.csv', ',');
-- CALL export_data('p2p', '/path/to/p2p.csv', ',');
-- CALL export_data('verter', '/path/to/verter.csv', ',');
-- CALL export_data('transferredpoints', '/path/to/transferredpoints.csv', ',');
-- CALL export_data('friends', '/path/to/friends.csv', ',');
-- CALL export_data('recommendations', '/path/to/recommendations.csv', ',');
-- CALL export_data('xp', '/path/to/xp.csv', ',');
-- CALL export_data('timetracking', '/path/to/timetracking.csv', ',');

-- Импорт всех таблиц из CSV файлов
-- CALL import_data('peers', '/path/to/peers.csv', ',');
-- CALL import_data('tasks', '/path/to/tasks.csv', ',');
-- CALL import_data('checks', '/path/to/checks.csv', ',');
-- CALL import_data('p2p', '/path/to/p2p.csv', ',');
-- CALL import_data('verter', '/path/to/verter.csv', ',');
-- CALL import_data('transferredpoints', '/path/to/transferredpoints.csv', ',');
-- CALL import_data('friends', '/path/to/friends.csv', ',');
-- CALL import_data('recommendations', '/path/to/recommendations.csv', ',');
-- CALL import_data('xp', '/path/to/xp.csv', ',');
-- CALL import_data('timetracking', '/path/to/timetracking.csv', ',');

-- Очистка всех таблиц (удаление данных)
-- TRUNCATE TABLE Peers CASCADE;
-- TRUNCATE TABLE Tasks CASCADE;
-- TRUNCATE TABLE Checks CASCADE;
-- TRUNCATE TABLE P2P CASCADE;
-- TRUNCATE TABLE Verter CASCADE;
-- TRUNCATE TABLE TransferredPoints CASCADE;
-- TRUNCATE TABLE Friends CASCADE;
-- TRUNCATE TABLE Recommendations CASCADE;
-- TRUNCATE TABLE XP CASCADE;
-- TRUNCATE TABLE TimeTracking CASCADE;

-- =============================================
-- ДОПОЛНИТЕЛЬНЫЙ ЗАПРОС ДЛЯ ПРОВЕРКИ ЦЕЛОСТНОСТИ
-- =============================================
-- Проверка соответствия полученного XP максимальному возможному за задание
SELECT 
    XP.ID,
    XP.CheckID,
    XP.XPAmount,
    Tasks.MaxXP,
    CASE 
        WHEN XP.XPAmount <= Tasks.MaxXP THEN 'OK'
        ELSE 'ERROR: XP превышает максимум'
    END AS Status
FROM XP
JOIN Checks ON Checks.ID = XP.CheckID
JOIN Tasks ON Checks.Task = Tasks.Title;
