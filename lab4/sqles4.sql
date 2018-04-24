SET search_path TO 'unicorsi';


SELECT max(stipendio),min(stipendio),avg(stipendio)
FROM professori;


SELECT  max(esami.voto) ,avg(voto),min(voto),corsi.denominazione,corsidilaurea.denominazione
FROM esami JOIN corsi ON esami.corso=corsi.id
	JOIN corsidilaurea ON corsi.corsodilaurea=corsidilaurea.id
WHERE corsidilaurea.denominazione='Informatica'
GROUP BY corsi.denominazione,corsidilaurea.denominazione;




SELECT  max(esami.voto) ,avg(voto),min(voto),corsi.denominazione,corsidilaurea.denominazione
FROM esami JOIN corsi ON esami.corso=corsi.id
	JOIN corsidilaurea ON corsi.corsodilaurea=corsidilaurea.id
GROUP BY corsi.denominazione,corsidilaurea.denominazione
ORDER BY corsidilaurea.denominazione ASC;



---esercizio 4 da completare----














