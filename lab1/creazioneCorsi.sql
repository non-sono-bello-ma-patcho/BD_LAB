-- creazione schema corsi:
CREATE schema corsi;

set search_path to corsi;

-- creazione relazione:
CREATE TABLE Professori
		(Id NUMERIC(5),
		 Cognome VARCHAR(30),
		 Nome VARCHAR(30),
		 Stipendio NUMERIC(6,2) DEFAULT 15000,
		 InCongedo boolean DEFAULT false,
		 PRIMARY KEY(Id),
		 UNIQUE(Cognome, Nome) -- this notation sucks, anyway...
		);

CREATE TABLE Corsi
		(Id VARCHAR(10) PRIMARY KEY,
		 CorsoDiLaurea VARCHAR(20) NOT NULL,
		 Nome VARCHAR(20) NOT NULL,
		 Professore REFERENCES Professori ON UPDATE CASCADE ON DELETE NO ACTION, -- no specification needed as the only primary key is Id, that's what I need
		 Attivato boolean DEFAULT false,
		);

CREATE TABLE Studenti
		(Matricola SERIAL(5) PRIMARY KEY,
		 Cognome VARCHAR(20),
		 Nome VARCHAR(20),
		 CorsoDiLaurea VARCHAR(20),
		 Iscrizione CHAR(9),
		 Relatore NUMERIC(5) REFERENCES Professori ON UPDATE CASCADE ON DELETE NO ACTION
		);

-- adding mutuada column
ALTER TABLE Corsi ADD COLUMN MutuaDa VARCHAR(10) REFERENCES Corsi ON UPDATE CASCADE ON DELETE NO ACTION;

-- modifying Stipendio Column on professori TABLE, not sure about this query
ALTER TABLE Professori ALTER COLUMN Stipendio NUMERIC(7,2) DEFAULT 15000;

-- mancano passaggi da c in poi
