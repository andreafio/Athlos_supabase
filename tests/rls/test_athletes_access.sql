-- Test automatico RLS: accesso tabella athletes
-- Esegui con pgTAP o in CI/CD

-- Test: un coach vede solo i propri atleti
SET jwt.claims.sub = 'coach-uuid';
SELECT * FROM athletes; -- Deve restituire solo gli atleti assegnati

-- Test: un admin vede tutto
SET jwt.claims.sub = 'admin-uuid';
SELECT count(*) FROM athletes; -- Deve restituire tutti gli atleti

-- Test: un atleta vede solo se stesso
SET jwt.claims.sub = 'athlete-uuid';
SELECT * FROM athletes WHERE user_id = 'athlete-uuid'; -- Deve restituire solo il proprio profilo
