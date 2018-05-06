--gruppo 49: Zazzera, Straforini, Storace
set search_path to unicorsi;

--1
--sotto-interrogazione correlata 
SELECT matricola
	FROM esami
	JOIN studenti S  on esami.studente=S.matricola
	JOIN corsi on esami.corso=corsi.id
	JOIN corsidilaurea ON S.corsodilaurea=corsidilaurea.id 
	WHERE corsi.denominazione='Basi Di Dati 1' 
	AND corsidilaurea.denominazione='Informatica' 
	AND esami.data BETWEEN '2010-06-01' AND '2010-06-30' 

	AND EXISTS(
	
	SELECT S.matricola
	FROM esami
	JOIN studenti on esami.studente=S.matricola
	JOIN corsi on esami.corso=corsi.id
	WHERE corsi.denominazione='Interfacce Grafiche' 
	AND corsidilaurea.denominazione='Informatica' 
	AND esami.data BETWEEN '2010-06-01' AND '2010-06-30');

--2
SELECT matricola
	FROM esami
	JOIN studenti  S on esami.studente=S.matricola
	JOIN corsi on esami.corso=corsi.id
	JOIN corsidilaurea ON S.corsodilaurea=corsidilaurea.id 
	WHERE corsi.denominazione='Basi Di Dati 1' 
	AND corsidilaurea.denominazione='Informatica' 
	AND esami.data BETWEEN '2010-06-01' AND '2010-06-30' 

	AND NOT EXISTS(
	
	SELECT S.matricola
	FROM esami
	JOIN studenti on esami.studente=S.matricola
	JOIN corsi on esami.corso=corsi.id
	WHERE corsi.denominazione='Interfacce Grafiche' 
	AND corsidilaurea.denominazione='Informatica' 
	AND esami.data BETWEEN '2010-06-01' AND '2010-06-30');


--3

/*select matricola
from studenti S 
JOIN corsidilaurea ON S.corsodilaurea=corsidilaurea.id 
group by matricola having AVG (select esami.voto
	from esami 
	join studenti on S.matricola = esami.studente)

	;*/
