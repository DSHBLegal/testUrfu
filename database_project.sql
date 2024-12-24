-- 1. Создание таблиц

-- Таблица участников судебного процесса
CREATE TABLE Participants (
    id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    birth_date DATE NOT NULL,
    contact_info TEXT,
    role ENUM('Истец', 'Ответчик', 'Адвокат', 'Судья') NOT NULL
);

-- Таблица судебных дел
CREATE TABLE CourtCases (
    id INT AUTO_INCREMENT PRIMARY KEY,
    case_number VARCHAR(100) NOT NULL UNIQUE,
    category VARCHAR(255) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    status ENUM('В процессе', 'Завершено', 'Закрыто') NOT NULL
);

-- Таблица участников дел
CREATE TABLE CaseParticipants (
    id INT AUTO_INCREMENT PRIMARY KEY,
    case_id INT NOT NULL,
    participant_id INT NOT NULL,
    role_in_case ENUM('Истец', 'Ответчик', 'Адвокат') NOT NULL,
    FOREIGN KEY (case_id) REFERENCES CourtCases(id),
    FOREIGN KEY (participant_id) REFERENCES Participants(id)
);

-- Таблица решений и документов
CREATE TABLE Documents (
    id INT AUTO_INCREMENT PRIMARY KEY,
    case_id INT NOT NULL,
    document_type ENUM('Решение', 'Протокол', 'Иное') NOT NULL,
    document_date DATE NOT NULL,
    content TEXT,
    judge_id INT NOT NULL,
    FOREIGN KEY (case_id) REFERENCES CourtCases(id),
    FOREIGN KEY (judge_id) REFERENCES Participants(id)
);

-- Таблица судебных округов
CREATE TABLE JudicialDistricts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL
);

-- Связь между делами и округами
ALTER TABLE CourtCases ADD COLUMN district_id INT NOT NULL, 
ADD FOREIGN KEY (district_id) REFERENCES JudicialDistricts(id);

-- 2. Ограничения
-- Даты документов должны быть позже даты начала дела
ALTER TABLE Documents ADD CONSTRAINT chk_document_date CHECK (document_date >= (SELECT start_date FROM CourtCases WHERE CourtCases.id = case_id));

-- 3. Запросы

-- 3.1 Список дел, в которых участвует определённое лицо
SELECT c.case_number
FROM CourtCases c
JOIN CaseParticipants cp ON c.id = cp.case_id
JOIN Participants p ON cp.participant_id = p.id
WHERE p.full_name = ?;

-- 3.2 Список дел, над которыми работает судья
SELECT c.case_number
FROM CourtCases c
JOIN Documents d ON c.id = d.case_id
JOIN Participants p ON d.judge_id = p.id
WHERE p.full_name = ?;

-- 3.3 Средняя продолжительность рассмотрения дел судьёй
SELECT p.full_name, AVG(DATEDIFF(c.end_date, c.start_date)) AS avg_duration
FROM CourtCases c
JOIN Documents d ON c.id = d.case_id
JOIN Participants p ON d.judge_id = p.id
WHERE c.status = 'Завершено'
GROUP BY p.id;

-- 3.4 Рейтинг судей по количеству рассмотренных дел
SELECT p.full_name, COUNT(*) AS case_count
FROM Participants p
JOIN Documents d ON p.id = d.judge_id
JOIN CourtCases c ON d.case_id = c.id
WHERE c.status = 'Завершено'
GROUP BY p.id
ORDER BY case_count DESC;

-- 3.5 Судьи, рассмотревшие определённое количество дел за последний год
SELECT p.full_name
FROM Participants p
JOIN Documents d ON p.id = d.judge_id
JOIN CourtCases c ON d.case_id = c.id
WHERE c.status = 'Завершено' AND YEAR(c.end_date) = YEAR(CURDATE()) - 1
GROUP BY p.id
HAVING COUNT(*) > ?;

-- 3.6 Лица, выигравшие большинство дел в категории
SELECT p.full_name, COUNT(*) AS wins
FROM CaseParticipants cp
JOIN CourtCases c ON cp.case_id = c.id
JOIN Participants p ON cp.participant_id = p.id
WHERE cp.role_in_case = 'Истец' AND c.category = ? AND c.status = 'Завершено'
GROUP BY p.id
HAVING COUNT(*) > 1;

-- 3.7 Категории дел с наибольшим числом неудачных исходов
SELECT c.category, COUNT(*) AS losses
FROM CourtCases c
WHERE c.status = 'Закрыто'
GROUP BY c.category
ORDER BY losses DESC;

-- 3.8 Лица, выигравшие все свои дела, и судьи этих дел
SELECT p.full_name AS participant, j.full_name AS judge
FROM Participants p
JOIN CaseParticipants cp ON p.id = cp.participant_id
JOIN CourtCases c ON cp.case_id = c.id
JOIN Documents d ON c.id = d.case_id
JOIN Participants j ON d.judge_id = j.id
WHERE cp.role_in_case = 'Истец' AND c.status = 'Завершено'
GROUP BY p.id, j.id
HAVING COUNT(*) = (SELECT COUNT(*) FROM CourtCases WHERE case_id = cp.case_id);

-- 3.9 Изменение количества дел по категориям за временные периоды
SELECT c.category, YEAR(c.start_date) AS year, COUNT(*) AS case_count
FROM CourtCases c
GROUP BY c.category, YEAR(c.start_date)
ORDER BY c.category, year;

-- 3.10 Судебные округа с лучшей статистикой по делам
SELECT jd.name, AVG(DATEDIFF(c.end_date, c.start_date)) AS avg_duration
FROM JudicialDistricts jd
JOIN CourtCases c ON jd.id = c.district_id
WHERE c.status = 'Завершено'
GROUP BY jd.id
ORDER BY avg_duration;

-- 4. Примеры операций

-- Добавление участника процесса
INSERT INTO Participants (full_name, birth_date, contact_info, role)
VALUES ('Иван Иванов', '1980-01-01', 'example@example.com', 'Истец');

-- Обновление контактной информации участника
UPDATE Participants
SET contact_info = 'new_email@example.com'
WHERE full_name = 'Иван Иванов';

-- Удаление дела и связанных записей
DELETE FROM Documents WHERE case_id = 1;
DELETE FROM CaseParticipants WHERE case_id = 1;
DELETE FROM CourtCases WHERE id = 1;

-- Добавление нового документа
INSERT INTO Documents (case_id, document_type, document_date, content, judge_id)
VALUES (1, 'Решение', '2024-12-21', 'Пример решения', 2);