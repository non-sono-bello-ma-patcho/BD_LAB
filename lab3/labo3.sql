SET search_path TO 'unicorsi';


SELECT matricola, nome,cognome
FROM Studenti JOIN CorsiDiLaurea
ON Studenti.CorsoDiLaurea = CorsiDiLaurea.id
WHERE Laurea < '2009-11-01' AND CorsiDiLaurea.Denominazione='Informatica';

SELECT corsi.id,cognome,nome,denominazione
FROM Professori JOIN  Corsi ON Professori.id = Corsi.professore
ORDER BY corsi.id DESC;

SELECT corsi.denominazione , Professori.cognome
FROM Corsi JOIN Professori  ON Professori.id = Corsi.professore
	JOIN CorsiDiLaurea ON Corsi.CorsoDiLaurea =CorsiDiLaurea.id
WHERE CorsiDiLaurea.attivazione < ' 2009-11-01'
ORDER BY Professori.cognome ASC;
/*

*/
-- We are going to join orizzontally many tables, so we must specify from which table to pick attributes:
SELECT corsi.denominazione, professori.cognome
-- pairs professori and corsi based on professor ID, the values of id for both professori and corsi has the same value for each row:
from professori JOIN corsi ON Professori.id = Corsi.professore
-- in the same way, join corsidilaurea table and  corsi table, each row has the same value for id and corsodilaurea...
	join corsidilaurea on corsi.corsodilaurea = corsidilaurea.id
-- last but not least apply filters:
WHERE CorsiDiLaurea.attivazione < ' 2009-11-01'
ORDER BY Professori.cognome ASC;



--
SELECT Studenti.nome, Studenti.cognome, Professori.cognome
-- join tables so that on each row every student it's paired with its supervisor:
FROM Studenti JOIN Professori ON Studenti.relatore= Professori.id
ORDER BY Studenti.cognome ASC;

SELECT Corsi.denominazione , CorsiDiLaurea.denominazione
FROM Corsi JOIN CorsiDiLaurea  ON Corsi.CorsoDiLaurea = CorsiDiLaurea.id
WHERE CorsiDiLaurea.denominazione='Informatica' AND Corsi.attivato
AND Corsi.denominazione LIKE '__s%';

-- la matricola degli studenti di matematica che hanno registrato voti sufficienti per l’esame di “Informatica Generale” svoltosi il 15 febbraio 2012;
--- non va ---

SELECT studenti.matricola
-- pair for each students its course:
FROM Studenti JOIN CorsiDiLaurea ON Studenti.CorsoDiLaurea = CorsiDiLaurea.id
-- pair for each students and given course its exams result:
	JOIN  Esami ON Studenti.matricola = Esami.studente
--
	JOIN Corsi ON CorsiDiLaurea.id = Corsi.corsodilaurea
WHERE corsidilaurea.denominazione = 'Matematica' and Esami.voto > 17 AND corsi.denominazione='Informatica Generale'
AND Corsidilaurea.denominazione='Matematica' AND esami.data='2012-02-15';

SELECT DISTINCT  matricola,relatore,annoaccademico,anno
FROM Studenti JOIN Pianidistudio ON Studenti.matricola=pianidistudio.studente
JOIN Corsidilaurea ON corsidilaurea.id=studenti.corsodilaurea
WHERE corsidilaurea.denominazione='Informatica' AND Pianidistudio.annoaccademico='2011'
AND pianidistudio.anno=5 AND Studenti.relatore  IS NOT NULL
ORDER BY matricola ASC;

SELECT  corsi.denominazione,professori.cognome,professori.nome
FROM Corsi
	FULL OUTER JOIN Professori ON Corsi.professore=professori.id
ORDER BY corsi.denominazione ASC;


SELECT professori.id, professori.cognome, studenti.matricola, studenti.cognome, studenti.nome
FROM Professori  JOIN Studenti ON Studenti.relatore=professori.id
ORDER BY Professori.id ASC;
