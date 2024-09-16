--Обзорный запрос с атрибутами
SELECT * FROM logs.service_logs WHERE resources_string_value[1] = '/srv/resume-views/var/log/requests.slog' LIMIT 1
UNION ALL SELECT * FROM logs.service_logs WHERE resources_string_value[1] = '/srv/resume-views/var/log/service.slog' LIMIT 1;

---Узнаём всех клиентов сервиса
SELECT attributes_string_value[1], COUNT(*)
FROM logs.service_logs
WHERE service = 'resume-views'
  AND resources_string_value[1] = '/srv/resume-views/var/log/requests.slog'
GROUP BY 1 ORDER BY 2 DESC;

--Когда идет нагрузочное тестирование?
SELECT date_trunc('hour', timestamp), count(*)
FROM logs.service_logs
WHERE service = 'resume-views'
  AND resources_string_value[1] = '/srv/resume-views/var/log/requests.slog'
  AND attributes_string_value[1] = 'load-testing'
GROUP BY 1;

--Какие запросы подаются при нагрузочном тестировании?
SELECT body, COUNT(*)
FROM logs.service_logs
WHERE service = 'resume-views'
  AND resources_string_value[1] = '/srv/resume-views/var/log/requests.slog'
  AND timestamp >= '2024-09-04 00:00:00' AND timestamp < '2024-09-05 00:00:00'
  AND attributes_string_value[1] = 'load-testing'
GROUP BY 1;

--Смотрим на все ошибки
SELECT *
FROM logs.service_logs
WHERE service = 'resume-views'
  AND timestamp >= '2024-09-02 00:00:00' AND timestamp < '2024-09-03 00:00:00'
  AND (
    LOWER(body) LIKE '%except%'
    OR LOWER(body) LIKE '%error%'
    OR severity_text = 'ERROR'
    OR severity_text = 'WARN'
  );

--Группируем ошибки
SELECT multiIf(body LIKE '%rs/resume/short/%', '1 - запросы в xmlback, rs/resume/short/',
               body LIKE '%rs/resume/identifiers%', '1 - запросы в xmlback, rs/resume/identifiers',
               body LIKE '%/rs/resume/by_hash%', '1 - запросы в xmlback, rs/resume/by_hash',
               body LIKE '%/rs/manager/list/%', '1 - запросы в xmlback, rs/manager/list/',
               body LIKE '%low on threads, closing accepted socket%', '2 - пулы, low on threads, closing accepted socket',
               body LIKE '%MonitoredQueuedThreadPool%', '2 - пулы, MonitoredQueuedThreadPool',
               body LIKE '%jclient thread pool is low on threads%', '2 - пулы, jclient thread pool is low on threads',
               body LIKE '%connection usage duration exceeded%', '3 - БД, connection usage duration exceeded',
               body LIKE '%Connection is not available, request timed out after%', '3 - БД, Connection is not available, request timed out after',
               body LIKE '%JDBC exception executing SQL%', '3 - БД, JDBC exception executing SQL',
               '4 - прочее'
       ),
       COUNT(*)
FROM logs.service_logs
WHERE service = 'resume-views'
  AND timestamp >= '2024-09-02 00:00:00' AND timestamp < '2024-09-03 00:00:00'
  AND (
    LOWER(body) LIKE '%except%'
    OR LOWER(body) LIKE '%error%'
    OR severity_text = 'ERROR'
    OR severity_text = 'WARN'
  )
GROUP BY 1 ORDER BY 1;

--Ошибки группы 1 (запросы)
SELECT date_trunc('minute', timestamp), COUNT(*)
FROM logs.service_logs
WHERE service = 'resume-views'
  AND timestamp >= '2024-09-04 00:00:00' AND timestamp < '2024-09-05 00:00:00'
  AND (
    body LIKE '%rs/resume/short/%'
    OR body LIKE '%rs/resume/identifiers%'
    OR body LIKE '%/rs/resume/by_hash%'
    OR body LIKE '%/rs/manager/list/%'
  )
GROUP BY 1 ORDER BY 2 DESC;

--Распределение ошибок БД по минутам
SELECT date_trunc('minute', timestamp), COUNT(*)
FROM logs.service_logs
WHERE service = 'resume-views'
  AND timestamp >= '2024-09-02 00:00:00' AND timestamp < '2024-09-03 00:00:00'
  AND (
    body LIKE '%connection usage duration exceeded%'
    OR body LIKE '%Connection is not available, request timed out after%'
    OR body LIKE '%JDBC exception executing SQL%'
  )
GROUP BY 1 ORDER BY 1;

--Группировка ошибок БД
SELECT multiIf(body LIKE '%select rvh.resume_id as resumeId,%' OR body LIKE '%getResumeViews(ResumeViewsDao.java:144)%', 'getResumeViews(ResumeViewsDao.java:144)',
               body LIKE '%select resume_id, sum(count_) as total_count_sum%' OR body LIKE '%getResumeViewCounts(ResumeViewsDao.java:114)%', 'getResumeViewCounts(ResumeViewsDao.java:114)',
               body LIKE '%v.classifying_property_types && cast(ARRAY[''HH_ANONYMOUS'', ''ZP_ANONYMOUS'']%' OR body LIKE '%getResumeViews(ResumeViewsDao.java:51)%', 'getResumeViews(ResumeViewsDao.java:51)',
               body LIKE '%select resume_id, count_ as views_count, new_count, last_history_visit%' OR body LIKE '%getResumeViewCounts(ResumeViewsDao.java:76)%', 'getResumeViewCounts(ResumeViewsDao.java:76)',
               body LIKE '%select date(date) as view_date, count(1)%' OR body LIKE '%getViewsByDateSince(ResumeViewsDao.java:165)%', 'getViewsByDateSince(ResumeViewsDao.java:165)',
               body LIKE '%SELECT rvh.employer_id, rvh.resume_id, em.employer_manager_id%' OR body LIKE '%findByResumeAndEmployerLastView(EmployerResumeViewsDao.java:36)%', 'findByResumeAndEmployerLastView(EmployerResumeViewsDao.java:36)',
               '4 - прочее'
       ),
       COUNT(*)
FROM logs.service_logs
WHERE service = 'resume-views'
  AND timestamp >= '2024-09-02 12:00:00' AND timestamp < '2024-09-02 14:00:00'
  AND (body LIKE '%connection usage duration exceeded%' OR body LIKE '%JDBC exception executing SQL%')
GROUP BY 1 ORDER BY 2 DESC;

--Пятисотки по урлам
SELECT body, COUNT(*)
FROM logs.service_logs
WHERE service = 'resume-views'
  AND resources_string_value[1] = '/srv/resume-views/var/log/requests.slog'
  AND timestamp >= '2024-09-02 00:00:00' AND timestamp < '2024-09-03 00:00:00'
  AND attributes_int64_value[3] IN (500, 502, 502)
GROUP BY 1 ORDER BY 2 DESC;


--Группировка по кодам ответов
SELECT attributes_int64_value[3], COUNT(*)
FROM logs.service_logs
WHERE service = 'resume-views'
  AND resources_string_value[1] = '/srv/resume-views/var/log/requests.slog'
  AND timestamp >= '2024-09-02 00:00:00' AND timestamp < '2024-09-03 00:00:00'
GROUP BY 1 ORDER BY 2 DESC;