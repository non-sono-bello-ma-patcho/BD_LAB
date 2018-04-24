set search_path to unicorsi;
--FUNZIONI DI GRUPPO-------

----esercizio1----
select max(stipendio),avg(stipendio),min(stipendio)
from professori;

---esercizio2---
select max(voto),min(voto),avg(voto)
from esami join corsi on esami.corso=corsi.id
	join corsidilaurea on corsi.corsodilaurea=corsidilaurea.id
where corsidilaurea.denominazione='Informatica';


----esercizio3----
select max(voto),corsidilaurea.denominazione
/* 	right outer join è necessario perché il join naturale escluderebbe
	tutte le tuple che non hanno voto, dal momento che noi vogliamo che
	vengano mostrati i voti per ogni corso di laurea, dobbiamo specificare
	sul secondo join che siano mostrate tutte le tuple per ogni corso diverso
*/
from esami join corsi on esami.corso=corsi.id
	right outer join corsidilaurea on corsi.corsodilaurea=corsidilaurea.id
group by corsidilaurea.denominazione -- la clausola group by è sempre necessaria nel caso di funzioni aggregate come max;
order by max(voto) desc;

-- avremmo potuto anche scrivere:
select max(voto), corsidilaurea.denominazione
from corsidilaurea left outer join corsi on corsi.corsodilaurea = corsidilaurea.id
left outer join esami on corsi.id = esami.corso
group by corsidilaurea.denominazione
order by max(voto) desc;
-- notare che in questo caso l'outer left join va propagato...


----esercizio4---
select nome, cognome, count(*)
from professori
left outer join corsi on corsi.professore=professori.id
left outer join corsidilaurea on corsi.corsodilaurea=corsidilaurea.id
group by nome,cognome having count(*)>2 --having filtra il risultato di group by ... una specie di where
order by count(*)  desc;


---esercizio5---
select corsi.denominazione,count(*)
from esami
join corsi on esami.corso=corsi.id
join corsidilaurea on corsi.corsodilaurea=corsidilaurea.id
where corsidilaurea.denominazione='Informatica'
group by corsi.denominazione having count(*)<5
;/*
union*/
select esami.studente,corsi.denominazione,data
from esami
full outer join corsi on esami.corso=corsi.id
join corsidilaurea on corsi.corsodilaurea=corsidilaurea.id
where corsidilaurea.denominazione='Informatica';

--esercizio6---
select professori.cognome,professori.nome,count(matricola)
from professori
join studenti on studenti.relatore=professori.id
group by professori.cognome,professori.nome
order by professori.cognome,professori.nome asc;


--esercizio7---


select professori.cognome,professori.nome,count(matricola)
from professori
left outer join studenti on studenti.relatore=professori.id
group by professori.cognome,professori.nome
order by professori.cognome,professori.nome asc;



----esercizio8----

select matricola ,avg(voto)--corsi.denominazione,esami.data,corsidilaurea.denominazione
from esami
join studenti on esami.studente=studenti.matricola
join corsidilaurea on studenti.corsodilaurea=corsidilaurea.id
join corsi on esami.corso=corsi.id
where corsidilaurea.denominazione='Informatica'
group by matricola having count(extract( month from esami.data))>=2
order by matricola;


----SOTTO INTERROGAZIONI--------

--esercizio1 ----



select corsidilaurea.denominazione,count(*)
from corsidilaurea
join studenti on studenti.corsodilaurea=corsidilaurea.id
where corsidilaurea.attivazione='2009/2010'
group by corsidilaurea.denominazione having count(*)>0;/*>(select count(*)
							from corsidilaurea
							join studenti on studenti.corsodilaurea=corsidilaurea.id
							where corsidilaurea.denominazione='Informatica');*/

----esercizio2------


select matricola
from studenti
join corsidilaurea on studenti.corsodilaurea=corsidilaurea.id as f
where corsidilaurea.denominazione='Informatica';
