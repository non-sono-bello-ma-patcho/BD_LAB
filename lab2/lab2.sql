-- Database: "DB_BDuser49"
 
set search_path to "unicorsi";
 
-- common query
-- SELECT matricola FROM studenti ORDER BY cognome ASC;
 
 
-- looking for mario rossi
--SELECT matricola, cognome, nome FROM studenti WHERE cognome='Rossi' AND nome='Mario';
 
-- searching for non-graduate students
-- SELECT matricola, cognome, nome, laurea FROM studenti WHERE laurea IS NULL
 
-- listing residences
-- SELECT DISTINCT residenza FROM studenti ORDER BY residenza ASC
 
-- 
-- SELECT cognome, nome, residenza FROM studenti WHERE residenza!='Genova'; -- NOT IN ('Genova');
 
--
SELECT denominazione, attivazione FROM corsidilaurea WHERE attivazione NOT BETWEEN '2006/2007' AND '2009/2010' ORDER BY denominazione ASC; -- NOT IN ('2006/2007', '2007/2008', '2008/2009', '2009/2010');
 
SELECT cognome, nome, matricola, relatore FROM studenti WHERE relatore IS NULL AND iscrizione<2007;
 
SELECT studente, data FROM esami WHERE data > '2009-02-02';
 
SELECT denominazione, attivazione FROM corsidilaurea WHERE attivazione='2017/2018' AND denominazione NOT LIKE 'L%';
 
SELECT cognome FROM professori WHERE cognome LIKE '%te%' AND stipendio BETWEEN 12500 AND 16000;
 
SELECT matricola, cognome, nome, residenza FROM studenti WHERE residenza IN ('Genova', 'Savona', 'La Spezia') OR cognome NOT IN ('Serra', 'Melogno', 'Giunchi') ORDER BY matricola DESC;
 
SELECT denominazione, facolta FROM corsidilaurea WHERE attivazione BETWEEN '2004/2005' AND '2009/2010' ORDER BY facolta ASC;

--------------parte2------------------

SELECT matricola,laurea FROM studenti WHERE laurea < '2009-09-01';
SELECT cognome,nome,id FROM professori ORDER BY id DESC;



SELECT denominazione, nome,cognome 
FROM  corsi JOIN professori ON Corsi.Professore=Professori.id
WHERE  attivato  ORDER BY denominazione ASC;

SELECT studenti.cognome ,studenti.nome,professori.cognome,professori.nome
FROM studenti JOIN professori ON studenti.relatore=Professori.id
ORDER BY studenti.cognome ASC;


SELECT corsidilaurea.denominazione,corsi.denominazione,corsi.corsodilaurea
FROM corsi JOIN corsidilaurea ON corsi.corsodilaurea=corsidilaurea.id
WHERE corsidilaurea.attivazione = '2004/2005' --per il 2017/208 non c'e  niente
AND corsidilaurea.denominazione='Informatica' AND corsi.denominazione LIKE '__s%';

SELECT studenti.matricola , studenti.corsodilaurea
FROM  esami JOIN  studenti ON studenti.matricola=esami.studente 
JOIN corsidilaurea ON corsidilaurea.id=studenti.corsodilaurea
JOIN corsi ON corsi.id=esami.corso
WHERE esami.voto >= 18 AND esami.corso='infogenM' AND esami.data ='2012-02-15';

SELECT DISTINCT  studenti.cognome,studenti.nome,studenti.relatore,studenti.corsodilaurea
FROM pianidistudio JOIN studenti ON studenti.matricola=pianidistudio.studente
JOIN corsidilaurea ON corsidilaurea.id=studenti.corsodilaurea
WHERE studenti.relatore IS NOT NULL AND pianidistudio.annoaccademico='2011'
AND pianidistudio.anno=5 AND corsidilaurea.denominazione='Informatica'
ORDER BY studenti.cognome,studenti.nome ASC;




