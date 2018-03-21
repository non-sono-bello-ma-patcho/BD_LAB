-- creazione schema corsi:
CREATE schema corsi;

set search_path to corsi;

-- creazione relazione:
CREATE TABLE professori
		(Id DECIMAL(5),
		 cognome VARCHAR(30),
		 nome VARCHAR(30),
		 stipendio DECIMAL(6,2) DEFAULT 15000,
		 PRIMARY KEY(Id),
		 UNIQUE(cognome, nome)
		);