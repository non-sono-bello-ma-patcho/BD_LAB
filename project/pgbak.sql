--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.10
-- Dumped by pg_dump version 9.6.10

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: bdproject; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE bdproject WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'it_IT.UTF-8' LC_CTYPE = 'it_IT.UTF-8';


ALTER DATABASE bdproject OWNER TO postgres;

\connect bdproject

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: bdproject; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA bdproject;


ALTER SCHEMA bdproject OWNER TO postgres;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: girone; Type: TYPE; Schema: bdproject; Owner: postgres
--

CREATE TYPE bdproject.girone AS ENUM (
    'italiana',
    'eliminazione diretta',
    'misto'
);


ALTER TYPE bdproject.girone OWNER TO postgres;

--
-- Name: privilege; Type: TYPE; Schema: bdproject; Owner: postgres
--

CREATE TYPE bdproject.privilege AS ENUM (
    'base',
    'premium'
);


ALTER TYPE bdproject.privilege OWNER TO postgres;

--
-- Name: sport; Type: TYPE; Schema: bdproject; Owner: postgres
--

CREATE TYPE bdproject.sport AS ENUM (
    'calcio',
    'basket',
    'tennis',
    'volley'
);


ALTER TYPE bdproject.sport OWNER TO postgres;

--
-- Name: state; Type: TYPE; Schema: bdproject; Owner: postgres
--

CREATE TYPE bdproject.state AS ENUM (
    'open',
    'closed'
);


ALTER TYPE bdproject.state OWNER TO postgres;

--
-- Name: MOD_confirm_team_for_match(character varying, bigint, character varying); Type: FUNCTION; Schema: bdproject; Owner: postgres
--

CREATE FUNCTION bdproject."MOD_confirm_team_for_match"("teamName" character varying, matchno bigint, confirmer character varying) RETURNS pg_trigger
    LANGUAGE plpgsql
    AS $$begin
 if not match_full() then
 update matchcandidatures
 set confirmed = confirmer
 where team = teamName and match = matchno;
 end if;
 return new;
end;
-- non sono proprio sicurissimo...
$$;


ALTER FUNCTION bdproject."MOD_confirm_team_for_match"("teamName" character varying, matchno bigint, confirmer character varying) OWNER TO postgres;

--
-- Name: FUNCTION "MOD_confirm_team_for_match"("teamName" character varying, matchno bigint, confirmer character varying); Type: COMMENT; Schema: bdproject; Owner: postgres
--

COMMENT ON FUNCTION bdproject."MOD_confirm_team_for_match"("teamName" character varying, matchno bigint, confirmer character varying) IS 'procedura che viene attivata quando si cerca di confermare una squadra che si candida per una partita';


--
-- Name: PROC_check_admin_confirmation_team_candidatures(); Type: FUNCTION; Schema: bdproject; Owner: postgres
--

CREATE FUNCTION bdproject."PROC_check_admin_confirmation_team_candidatures"() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
	if (team_full(new.team)) then
				  raise exception 'Impossibile confermare la candidatura per %, la squadra % è piena', old.applicant, old.team;
	end if;
	return new;
end;
$$;


ALTER FUNCTION bdproject."PROC_check_admin_confirmation_team_candidatures"() OWNER TO postgres;

--
-- Name: PROC_check_insert_match_result(); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject."PROC_check_insert_match_result"() RETURNS trigger
    LANGUAGE plpgsql
    AS $$begin
	if(not sameadminmatch(new.match,new.admin)) then
		raise exception 
		'Impossibile inserire esito partita(Permesso negato).';
	end if;
	if(not is_match_closed(new.match))then
		raise exception
		'Impossibile inserire esito partita(partita ancora aperta).';
	end if;
	return new;	
end;
$$;


ALTER FUNCTION bdproject."PROC_check_insert_match_result"() OWNER TO strafo;

--
-- Name: PROC_match_candidature_confirmation(); Type: FUNCTION; Schema: bdproject; Owner: postgres
--

CREATE FUNCTION bdproject."PROC_match_candidature_confirmation"() RETURNS trigger
    LANGUAGE plpgsql
    AS $$begin
	if (not valid_team(new.team)) then
	raise exception 'Impossibile confermare la candidatura per il match %, la squadra % non ha raggiunto il minimo dei giocatori o ha superato il massimo consentito.', old.match, old.team;
	end if;
	return new;
end;
$$;


ALTER FUNCTION bdproject."PROC_match_candidature_confirmation"() OWNER TO postgres;

--
-- Name: count_player(character varying); Type: FUNCTION; Schema: bdproject; Owner: postgres
--

CREATE FUNCTION bdproject.count_player("teamName" character varying) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
begin
	select count(*)
	from TeamCandidatures
	where name = teamName and admin is not null;
end;
$$;


ALTER FUNCTION bdproject.count_player("teamName" character varying) OWNER TO postgres;

--
-- Name: FUNCTION count_player("teamName" character varying); Type: COMMENT; Schema: bdproject; Owner: postgres
--

COMMENT ON FUNCTION bdproject.count_player("teamName" character varying) IS 'Conta i giocatori iscritti a una squadra, solo quelli confermati';


--
-- Name: is_match_closed(bigint); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.is_match_closed(matchno bigint) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
begin
	
	return 'closed'=
	(
		select matches.mstate
		from matches
		where matchno=matches.id
	);
end;
$$;


ALTER FUNCTION bdproject.is_match_closed(matchno bigint) OWNER TO strafo;

--
-- Name: FUNCTION is_match_closed(matchno bigint); Type: COMMENT; Schema: bdproject; Owner: strafo
--

COMMENT ON FUNCTION bdproject.is_match_closed(matchno bigint) IS 'ritorna true se il match è chiuso, false altrimenti';


--
-- Name: match_full(bigint); Type: FUNCTION; Schema: bdproject; Owner: postgres
--

CREATE FUNCTION bdproject.match_full(matchno bigint) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
begin
	return
		(select count (*)
			from (
					select team 
					from matchcandidatures
					where match = matchno 
						and confirmed is not null
			) AS aux
		) >= 2;
end;



$$;


ALTER FUNCTION bdproject.match_full(matchno bigint) OWNER TO postgres;

--
-- Name: FUNCTION match_full(matchno bigint); Type: COMMENT; Schema: bdproject; Owner: postgres
--

COMMENT ON FUNCTION bdproject.match_full(matchno bigint) IS 'Restituisce vero esistono due squadre confermate per una partita';


--
-- Name: referee_assigned(bigint); Type: FUNCTION; Schema: bdproject; Owner: postgres
--

CREATE FUNCTION bdproject.referee_assigned(matchno bigint) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
begin
	return
		(select count (*)
			from (
					select applicant 
					from refereecandidatures
					where match = matchno
						and confirmed is not null
			) AS aux
		) <> 0;
end;



$$;


ALTER FUNCTION bdproject.referee_assigned(matchno bigint) OWNER TO postgres;

--
-- Name: sameadminmatch(bigint, character varying); Type: FUNCTION; Schema: bdproject; Owner: postgres
--

CREATE FUNCTION bdproject.sameadminmatch(bigint, character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
begin
	return exists(
		select * from matches
		where id = $1 and admin = $2
		);
end;


$_$;


ALTER FUNCTION bdproject.sameadminmatch(bigint, character varying) OWNER TO postgres;

--
-- Name: sameadminteam(character varying, character varying); Type: FUNCTION; Schema: bdproject; Owner: postgres
--

CREATE FUNCTION bdproject.sameadminteam(character varying, character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$begin
	return exists(
		select * from teams
		where name = $1 and admin = $2
		);
end;
$_$;


ALTER FUNCTION bdproject.sameadminteam(character varying, character varying) OWNER TO postgres;

--
-- Name: sameadmintournaments(character varying, character varying); Type: FUNCTION; Schema: bdproject; Owner: postgres
--

CREATE FUNCTION bdproject.sameadmintournaments(character varying, character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
begin
	return exists(
		select * from tournaments
		where name = $1 and manager = $2
		);
end;


$_$;


ALTER FUNCTION bdproject.sameadmintournaments(character varying, character varying) OWNER TO postgres;

--
-- Name: team_full(character varying); Type: FUNCTION; Schema: bdproject; Owner: postgres
--

CREATE FUNCTION bdproject.team_full("TeamName" character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
begin
	return count_player(TeamName) =
	(
		select Categories.max
		from Teams join Categories on Teams.category = Categories.name
		where Teams.name = TeamName
	);
end;
$$;


ALTER FUNCTION bdproject.team_full("TeamName" character varying) OWNER TO postgres;

--
-- Name: FUNCTION team_full("TeamName" character varying); Type: COMMENT; Schema: bdproject; Owner: postgres
--

COMMENT ON FUNCTION bdproject.team_full("TeamName" character varying) IS 'restituisce true se il numero di giocatori è uguale al massimo consentito dalla categoria.';


--
-- Name: team_min(character varying); Type: FUNCTION; Schema: bdproject; Owner: postgres
--

CREATE FUNCTION bdproject.team_min(teamname character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
begin
	return count_player(TeamName) =
	(
		select Categories.min
		from Teams join Categories on Teams.category = Categories.name
		where Teams.name = TeamName
	);
end;
$$;


ALTER FUNCTION bdproject.team_min(teamname character varying) OWNER TO postgres;

--
-- Name: FUNCTION team_min(teamname character varying); Type: COMMENT; Schema: bdproject; Owner: postgres
--

COMMENT ON FUNCTION bdproject.team_min(teamname character varying) IS 'verifica che i giocatori di una squadra siano almeno il minimo specificato dalla categoria';


--
-- Name: valid_team(character varying); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.valid_team(teamname character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
	numero_giocatori numeric;
begin
	numero_giocatori:=count_player(TeamName);
	
	return numero_giocatori >=
	(
		select Categories.min
		from Teams join Categories on Teams.category = Categories.name
		where Teams.name = TeamName
	) 
	and numero_giocatori <=
	(
		select Categories.max
		from Teams join Categories on Teams.category = Categories.name
		where Teams.name = TeamName
	);
end;
$$;


ALTER FUNCTION bdproject.valid_team(teamname character varying) OWNER TO strafo;

--
-- Name: FUNCTION valid_team(teamname character varying); Type: COMMENT; Schema: bdproject; Owner: strafo
--

COMMENT ON FUNCTION bdproject.valid_team(teamname character varying) IS 'controlla se il numero di giocatori è:
categoria.min<=numero_giocatori<=categoria.max';


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: buildings; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.buildings (
    name character varying(64) NOT NULL,
    address character varying(128),
    phonenumber character varying(16),
    email character varying(64),
    longitude numeric(7,4),
    latitude numeric(7,4)
);


ALTER TABLE bdproject.buildings OWNER TO postgres;

--
-- Name: categories; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.categories (
    name bdproject.sport NOT NULL,
    regulation text,
    min numeric,
    max numeric
);


ALTER TABLE bdproject.categories OWNER TO postgres;

--
-- Name: TABLE categories; Type: COMMENT; Schema: bdproject; Owner: postgres
--

COMMENT ON TABLE bdproject.categories IS 'categorie di sport';


--
-- Name: evaluations; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.evaluations (
    evaluated character varying(64),
    evaluator character varying(64),
    evaluatedon date,
    match bigint NOT NULL,
    score integer,
    CONSTRAINT not_self_eval CHECK (((evaluated)::text <> (evaluator)::text))
);


ALTER TABLE bdproject.evaluations OWNER TO postgres;

--
-- Name: evaluations_match_seq; Type: SEQUENCE; Schema: bdproject; Owner: postgres
--

CREATE SEQUENCE bdproject.evaluations_match_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bdproject.evaluations_match_seq OWNER TO postgres;

--
-- Name: evaluations_match_seq; Type: SEQUENCE OWNED BY; Schema: bdproject; Owner: postgres
--

ALTER SEQUENCE bdproject.evaluations_match_seq OWNED BY bdproject.evaluations.match;


--
-- Name: fora; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.fora (
    studycourse character varying(64) NOT NULL,
    category character varying(64) NOT NULL,
    createdon date,
    description text,
    photo bigint NOT NULL
);


ALTER TABLE bdproject.fora OWNER TO postgres;

--
-- Name: fora_photo_seq; Type: SEQUENCE; Schema: bdproject; Owner: postgres
--

CREATE SEQUENCE bdproject.fora_photo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bdproject.fora_photo_seq OWNER TO postgres;

--
-- Name: fora_photo_seq; Type: SEQUENCE OWNED BY; Schema: bdproject; Owner: postgres
--

ALTER SEQUENCE bdproject.fora_photo_seq OWNED BY bdproject.fora.photo;


--
-- Name: matchcandidatures; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.matchcandidatures (
    team character varying(64) NOT NULL,
    match bigint NOT NULL,
    confirmed character varying(64),
    CONSTRAINT checkconfirmer CHECK (bdproject.sameadminmatch(match, confirmed))
);


ALTER TABLE bdproject.matchcandidatures OWNER TO postgres;

--
-- Name: matchcandidatures_match_seq; Type: SEQUENCE; Schema: bdproject; Owner: postgres
--

CREATE SEQUENCE bdproject.matchcandidatures_match_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bdproject.matchcandidatures_match_seq OWNER TO postgres;

--
-- Name: matchcandidatures_match_seq; Type: SEQUENCE OWNED BY; Schema: bdproject; Owner: postgres
--

ALTER SEQUENCE bdproject.matchcandidatures_match_seq OWNED BY bdproject.matchcandidatures.match;


--
-- Name: matches; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.matches (
    id bigint NOT NULL,
    building character varying(64),
    organizedon date NOT NULL,
    insertedon date NOT NULL,
    tournament character varying(64),
    mstate bdproject.state DEFAULT 'open'::bdproject.state,
    admin character varying(64),
    category bdproject.sport
);


ALTER TABLE bdproject.matches OWNER TO postgres;

--
-- Name: matches_id_seq; Type: SEQUENCE; Schema: bdproject; Owner: postgres
--

CREATE SEQUENCE bdproject.matches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bdproject.matches_id_seq OWNER TO postgres;

--
-- Name: matches_id_seq; Type: SEQUENCE OWNED BY; Schema: bdproject; Owner: postgres
--

ALTER SEQUENCE bdproject.matches_id_seq OWNED BY bdproject.matches.id;


--
-- Name: outcomes; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.outcomes (
    match bigint NOT NULL,
    otype bdproject.sport,
    scoreteam1 integer,
    scoreteam2 integer,
    goleadorteam1 text,
    goleadorteam2 text,
    winteam1 integer,
    winteam2 integer,
    admin character varying(64)
);


ALTER TABLE bdproject.outcomes OWNER TO postgres;

--
-- Name: outcomes_match_seq; Type: SEQUENCE; Schema: bdproject; Owner: postgres
--

CREATE SEQUENCE bdproject.outcomes_match_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bdproject.outcomes_match_seq OWNER TO postgres;

--
-- Name: outcomes_match_seq; Type: SEQUENCE OWNED BY; Schema: bdproject; Owner: postgres
--

ALTER SEQUENCE bdproject.outcomes_match_seq OWNED BY bdproject.outcomes.match;


--
-- Name: photos; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.photos (
    id bigint NOT NULL,
    photo integer NOT NULL
);


ALTER TABLE bdproject.photos OWNER TO postgres;

--
-- Name: photos_id_seq; Type: SEQUENCE; Schema: bdproject; Owner: postgres
--

CREATE SEQUENCE bdproject.photos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bdproject.photos_id_seq OWNER TO postgres;

--
-- Name: photos_id_seq; Type: SEQUENCE OWNED BY; Schema: bdproject; Owner: postgres
--

ALTER SEQUENCE bdproject.photos_id_seq OWNED BY bdproject.photos.id;


--
-- Name: photos_photo_seq; Type: SEQUENCE; Schema: bdproject; Owner: postgres
--

CREATE SEQUENCE bdproject.photos_photo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bdproject.photos_photo_seq OWNER TO postgres;

--
-- Name: photos_photo_seq; Type: SEQUENCE OWNED BY; Schema: bdproject; Owner: postgres
--

ALTER SEQUENCE bdproject.photos_photo_seq OWNED BY bdproject.photos.photo;


--
-- Name: posts; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.posts (
    id bigint NOT NULL,
    postedon date NOT NULL,
    photo bigint NOT NULL,
    description text,
    category character varying(64),
    studycourse character varying(64),
    postedby character varying(64)
);


ALTER TABLE bdproject.posts OWNER TO postgres;

--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: bdproject; Owner: postgres
--

CREATE SEQUENCE bdproject.posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bdproject.posts_id_seq OWNER TO postgres;

--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: bdproject; Owner: postgres
--

ALTER SEQUENCE bdproject.posts_id_seq OWNED BY bdproject.posts.id;


--
-- Name: posts_photo_seq; Type: SEQUENCE; Schema: bdproject; Owner: postgres
--

CREATE SEQUENCE bdproject.posts_photo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bdproject.posts_photo_seq OWNER TO postgres;

--
-- Name: posts_photo_seq; Type: SEQUENCE OWNED BY; Schema: bdproject; Owner: postgres
--

ALTER SEQUENCE bdproject.posts_photo_seq OWNED BY bdproject.posts.photo;


--
-- Name: refereecandidatures; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.refereecandidatures (
    applicant character varying(64) NOT NULL,
    match bigint NOT NULL,
    matchtime timestamp without time zone,
    confirmed character varying(64),
    CONSTRAINT checkconfirmer CHECK (bdproject.sameadminmatch(match, confirmed))
);


ALTER TABLE bdproject.refereecandidatures OWNER TO postgres;

--
-- Name: refereecandidatures_match_seq; Type: SEQUENCE; Schema: bdproject; Owner: postgres
--

CREATE SEQUENCE bdproject.refereecandidatures_match_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bdproject.refereecandidatures_match_seq OWNER TO postgres;

--
-- Name: refereecandidatures_match_seq; Type: SEQUENCE OWNED BY; Schema: bdproject; Owner: postgres
--

ALTER SEQUENCE bdproject.refereecandidatures_match_seq OWNED BY bdproject.refereecandidatures.match;


--
-- Name: studycourses; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.studycourses (
    coursename character varying(64) NOT NULL
);


ALTER TABLE bdproject.studycourses OWNER TO postgres;

--
-- Name: teamcandidatures; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.teamcandidatures (
    team character varying(64) NOT NULL,
    applicant character varying NOT NULL,
    role character varying(64),
    admin character varying(64),
    CONSTRAINT checkconfirmer CHECK (bdproject.sameadminteam(team, admin))
);


ALTER TABLE bdproject.teamcandidatures OWNER TO postgres;

--
-- Name: teams; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.teams (
    name character varying(64) NOT NULL,
    coloremaglia character varying(32),
    category character varying(64),
    description text,
    notes text,
    tstate bdproject.state DEFAULT 'open'::bdproject.state,
    admin character varying(64)
);


ALTER TABLE bdproject.teams OWNER TO postgres;

--
-- Name: tournaments; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.tournaments (
    name character varying(64) NOT NULL,
    ttype bdproject.girone DEFAULT 'italiana'::bdproject.girone,
    manager character varying(64)
);


ALTER TABLE bdproject.tournaments OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.users (
    username character varying(64) NOT NULL,
    password character varying(64),
    name character varying(64),
    surname character varying(64),
    birthdate date NOT NULL,
    birthplace character varying(64) NOT NULL,
    photo bigint NOT NULL,
    regnumber integer,
    uprivilege bdproject.privilege DEFAULT 'base'::bdproject.privilege,
    studycourse character varying(64),
    tennismatch numeric,
    volleymatch numeric,
    soccermatch numeric
);


ALTER TABLE bdproject.users OWNER TO postgres;

--
-- Name: users_photo_seq; Type: SEQUENCE; Schema: bdproject; Owner: postgres
--

CREATE SEQUENCE bdproject.users_photo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bdproject.users_photo_seq OWNER TO postgres;

--
-- Name: users_photo_seq; Type: SEQUENCE OWNED BY; Schema: bdproject; Owner: postgres
--

ALTER SEQUENCE bdproject.users_photo_seq OWNED BY bdproject.users.photo;


--
-- Name: evaluations match; Type: DEFAULT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.evaluations ALTER COLUMN match SET DEFAULT nextval('bdproject.evaluations_match_seq'::regclass);


--
-- Name: fora photo; Type: DEFAULT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.fora ALTER COLUMN photo SET DEFAULT nextval('bdproject.fora_photo_seq'::regclass);


--
-- Name: matchcandidatures match; Type: DEFAULT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.matchcandidatures ALTER COLUMN match SET DEFAULT nextval('bdproject.matchcandidatures_match_seq'::regclass);


--
-- Name: matches id; Type: DEFAULT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.matches ALTER COLUMN id SET DEFAULT nextval('bdproject.matches_id_seq'::regclass);


--
-- Name: outcomes match; Type: DEFAULT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.outcomes ALTER COLUMN match SET DEFAULT nextval('bdproject.outcomes_match_seq'::regclass);


--
-- Name: photos id; Type: DEFAULT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.photos ALTER COLUMN id SET DEFAULT nextval('bdproject.photos_id_seq'::regclass);


--
-- Name: photos photo; Type: DEFAULT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.photos ALTER COLUMN photo SET DEFAULT nextval('bdproject.photos_photo_seq'::regclass);


--
-- Name: posts id; Type: DEFAULT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.posts ALTER COLUMN id SET DEFAULT nextval('bdproject.posts_id_seq'::regclass);


--
-- Name: posts photo; Type: DEFAULT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.posts ALTER COLUMN photo SET DEFAULT nextval('bdproject.posts_photo_seq'::regclass);


--
-- Name: refereecandidatures match; Type: DEFAULT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.refereecandidatures ALTER COLUMN match SET DEFAULT nextval('bdproject.refereecandidatures_match_seq'::regclass);


--
-- Name: users photo; Type: DEFAULT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.users ALTER COLUMN photo SET DEFAULT nextval('bdproject.users_photo_seq'::regclass);


--
-- Data for Name: buildings; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.buildings (name, address, phonenumber, email, longitude, latitude) FROM stdin;
\.


--
-- Data for Name: categories; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.categories (name, regulation, min, max) FROM stdin;
\.


--
-- Data for Name: evaluations; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.evaluations (evaluated, evaluator, evaluatedon, match, score) FROM stdin;
\.


--
-- Name: evaluations_match_seq; Type: SEQUENCE SET; Schema: bdproject; Owner: postgres
--

SELECT pg_catalog.setval('bdproject.evaluations_match_seq', 1, false);


--
-- Data for Name: fora; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.fora (studycourse, category, createdon, description, photo) FROM stdin;
\.


--
-- Name: fora_photo_seq; Type: SEQUENCE SET; Schema: bdproject; Owner: postgres
--

SELECT pg_catalog.setval('bdproject.fora_photo_seq', 1, false);


--
-- Data for Name: matchcandidatures; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.matchcandidatures (team, match, confirmed) FROM stdin;
\.


--
-- Name: matchcandidatures_match_seq; Type: SEQUENCE SET; Schema: bdproject; Owner: postgres
--

SELECT pg_catalog.setval('bdproject.matchcandidatures_match_seq', 1, false);


--
-- Data for Name: matches; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.matches (id, building, organizedon, insertedon, tournament, mstate, admin, category) FROM stdin;
\.


--
-- Name: matches_id_seq; Type: SEQUENCE SET; Schema: bdproject; Owner: postgres
--

SELECT pg_catalog.setval('bdproject.matches_id_seq', 1, false);


--
-- Data for Name: outcomes; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.outcomes (match, otype, scoreteam1, scoreteam2, goleadorteam1, goleadorteam2, winteam1, winteam2, admin) FROM stdin;
\.


--
-- Name: outcomes_match_seq; Type: SEQUENCE SET; Schema: bdproject; Owner: postgres
--

SELECT pg_catalog.setval('bdproject.outcomes_match_seq', 1, false);


--
-- Data for Name: photos; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.photos (id, photo) FROM stdin;
\.


--
-- Name: photos_id_seq; Type: SEQUENCE SET; Schema: bdproject; Owner: postgres
--

SELECT pg_catalog.setval('bdproject.photos_id_seq', 1200, true);


--
-- Name: photos_photo_seq; Type: SEQUENCE SET; Schema: bdproject; Owner: postgres
--

SELECT pg_catalog.setval('bdproject.photos_photo_seq', 1200, true);


--
-- Data for Name: posts; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.posts (id, postedon, photo, description, category, studycourse, postedby) FROM stdin;
\.


--
-- Name: posts_id_seq; Type: SEQUENCE SET; Schema: bdproject; Owner: postgres
--

SELECT pg_catalog.setval('bdproject.posts_id_seq', 1, false);


--
-- Name: posts_photo_seq; Type: SEQUENCE SET; Schema: bdproject; Owner: postgres
--

SELECT pg_catalog.setval('bdproject.posts_photo_seq', 1, false);


--
-- Data for Name: refereecandidatures; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.refereecandidatures (applicant, match, matchtime, confirmed) FROM stdin;
\.


--
-- Name: refereecandidatures_match_seq; Type: SEQUENCE SET; Schema: bdproject; Owner: postgres
--

SELECT pg_catalog.setval('bdproject.refereecandidatures_match_seq', 1, false);


--
-- Data for Name: studycourses; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.studycourses (coursename) FROM stdin;
\.


--
-- Data for Name: teamcandidatures; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.teamcandidatures (team, applicant, role, admin) FROM stdin;
\.


--
-- Data for Name: teams; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.teams (name, coloremaglia, category, description, notes, tstate, admin) FROM stdin;
\.


--
-- Data for Name: tournaments; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.tournaments (name, ttype, manager) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.users (username, password, name, surname, birthdate, birthplace, photo, regnumber, uprivilege, studycourse, tennismatch, volleymatch, soccermatch) FROM stdin;
\.


--
-- Name: users_photo_seq; Type: SEQUENCE SET; Schema: bdproject; Owner: postgres
--

SELECT pg_catalog.setval('bdproject.users_photo_seq', 1, false);


--
-- Name: buildings buildings_pkey; Type: CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.buildings
    ADD CONSTRAINT buildings_pkey PRIMARY KEY (name);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (name);


--
-- Name: fora fora_pkey; Type: CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.fora
    ADD CONSTRAINT fora_pkey PRIMARY KEY (studycourse, category);


--
-- Name: matchcandidatures matchcandidatures_pkey; Type: CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.matchcandidatures
    ADD CONSTRAINT matchcandidatures_pkey PRIMARY KEY (team, match);


--
-- Name: matches matches_pkey; Type: CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.matches
    ADD CONSTRAINT matches_pkey PRIMARY KEY (id);


--
-- Name: outcomes outcomes_pkey; Type: CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.outcomes
    ADD CONSTRAINT outcomes_pkey PRIMARY KEY (match);


--
-- Name: photos photos_pkey; Type: CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.photos
    ADD CONSTRAINT photos_pkey PRIMARY KEY (id);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: refereecandidatures refereecandidatures_pkey; Type: CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.refereecandidatures
    ADD CONSTRAINT refereecandidatures_pkey PRIMARY KEY (applicant, match);


--
-- Name: studycourses studycourses_pkey; Type: CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.studycourses
    ADD CONSTRAINT studycourses_pkey PRIMARY KEY (coursename);


--
-- Name: teamcandidatures teamcandidatures_pkey; Type: CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.teamcandidatures
    ADD CONSTRAINT teamcandidatures_pkey PRIMARY KEY (team, applicant);


--
-- Name: teams teams_pkey; Type: CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (name);


--
-- Name: tournaments tournaments_pkey; Type: CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.tournaments
    ADD CONSTRAINT tournaments_pkey PRIMARY KEY (name);


--
-- Name: users users_name_surname_regnumber_key; Type: CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.users
    ADD CONSTRAINT users_name_surname_regnumber_key UNIQUE (name, surname, regnumber);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (username);


--
-- Name: teamcandidatures check_team_not_full; Type: TRIGGER; Schema: bdproject; Owner: postgres
--

CREATE CONSTRAINT TRIGGER check_team_not_full AFTER UPDATE OF admin ON bdproject.teamcandidatures NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW WHEN ((new.admin IS NOT NULL)) EXECUTE PROCEDURE bdproject."PROC_check_admin_confirmation_team_candidatures"();


--
-- Name: TRIGGER check_team_not_full ON teamcandidatures; Type: COMMENT; Schema: bdproject; Owner: postgres
--

COMMENT ON TRIGGER check_team_not_full ON bdproject.teamcandidatures IS 'Controlla se c''è posto nel team per confermare l''utente.';


--
-- Name: matchcandidatures check_team_validity; Type: TRIGGER; Schema: bdproject; Owner: postgres
--

CREATE CONSTRAINT TRIGGER check_team_validity AFTER UPDATE OF confirmed ON bdproject.matchcandidatures NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW WHEN ((new.confirmed IS NOT NULL)) EXECUTE PROCEDURE bdproject."PROC_match_candidature_confirmation"();


--
-- Name: TRIGGER check_team_validity ON matchcandidatures; Type: COMMENT; Schema: bdproject; Owner: postgres
--

COMMENT ON TRIGGER check_team_validity ON bdproject.matchcandidatures IS 'La  candidature  della  squadra  viene  confermata  solo  se  il  numero  minimo  di  iscritti  alla  squadra  è  stato  raggiunto  e  non  si  è  superato  il  numero  massimo  di  giocatori  per  quella  categoria. ';


--
-- Name: evaluations evaluations_evaluated_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.evaluations
    ADD CONSTRAINT evaluations_evaluated_fkey FOREIGN KEY (evaluated) REFERENCES bdproject.users(username);


--
-- Name: evaluations evaluations_evaluator_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.evaluations
    ADD CONSTRAINT evaluations_evaluator_fkey FOREIGN KEY (evaluator) REFERENCES bdproject.users(username);


--
-- Name: evaluations evaluations_match_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.evaluations
    ADD CONSTRAINT evaluations_match_fkey FOREIGN KEY (match) REFERENCES bdproject.matches(id) ON DELETE CASCADE;


--
-- Name: fora fora_photo_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.fora
    ADD CONSTRAINT fora_photo_fkey FOREIGN KEY (photo) REFERENCES bdproject.photos(id) ON UPDATE CASCADE;


--
-- Name: fora fora_studycourse_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.fora
    ADD CONSTRAINT fora_studycourse_fkey FOREIGN KEY (studycourse) REFERENCES bdproject.studycourses(coursename) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: matchcandidatures matchcandidatures_confirmed_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.matchcandidatures
    ADD CONSTRAINT matchcandidatures_confirmed_fkey FOREIGN KEY (confirmed) REFERENCES bdproject.users(username);


--
-- Name: matchcandidatures matchcandidatures_match_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.matchcandidatures
    ADD CONSTRAINT matchcandidatures_match_fkey FOREIGN KEY (match) REFERENCES bdproject.matches(id);


--
-- Name: matchcandidatures matchcandidatures_team_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.matchcandidatures
    ADD CONSTRAINT matchcandidatures_team_fkey FOREIGN KEY (team) REFERENCES bdproject.teams(name);


--
-- Name: matches matches_admin_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.matches
    ADD CONSTRAINT matches_admin_fkey FOREIGN KEY (admin) REFERENCES bdproject.users(username) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: matches matches_building_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.matches
    ADD CONSTRAINT matches_building_fkey FOREIGN KEY (building) REFERENCES bdproject.buildings(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: matches matches_tournament_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.matches
    ADD CONSTRAINT matches_tournament_fkey FOREIGN KEY (tournament) REFERENCES bdproject.tournaments(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: outcomes outcomes_admin_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.outcomes
    ADD CONSTRAINT outcomes_admin_fkey FOREIGN KEY (admin) REFERENCES bdproject.users(username) ON UPDATE CASCADE;


--
-- Name: outcomes outcomes_match_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.outcomes
    ADD CONSTRAINT outcomes_match_fkey FOREIGN KEY (match) REFERENCES bdproject.matches(id);


--
-- Name: posts posts_photo_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.posts
    ADD CONSTRAINT posts_photo_fkey FOREIGN KEY (photo) REFERENCES bdproject.photos(id);


--
-- Name: posts posts_postedby_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.posts
    ADD CONSTRAINT posts_postedby_fkey FOREIGN KEY (postedby) REFERENCES bdproject.users(username);


--
-- Name: posts posts_studycourse_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.posts
    ADD CONSTRAINT posts_studycourse_fkey FOREIGN KEY (studycourse) REFERENCES bdproject.studycourses(coursename) ON DELETE RESTRICT;


--
-- Name: refereecandidatures refereecandidatures_applicant_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.refereecandidatures
    ADD CONSTRAINT refereecandidatures_applicant_fkey FOREIGN KEY (applicant) REFERENCES bdproject.users(username);


--
-- Name: refereecandidatures refereecandidatures_confirmed_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.refereecandidatures
    ADD CONSTRAINT refereecandidatures_confirmed_fkey FOREIGN KEY (confirmed) REFERENCES bdproject.users(username);


--
-- Name: refereecandidatures refereecandidatures_match_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.refereecandidatures
    ADD CONSTRAINT refereecandidatures_match_fkey FOREIGN KEY (match) REFERENCES bdproject.matches(id);


--
-- Name: teamcandidatures teamcandidatures_admin_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.teamcandidatures
    ADD CONSTRAINT teamcandidatures_admin_fkey FOREIGN KEY (admin) REFERENCES bdproject.users(username);


--
-- Name: teamcandidatures teamcandidatures_applicant_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.teamcandidatures
    ADD CONSTRAINT teamcandidatures_applicant_fkey FOREIGN KEY (applicant) REFERENCES bdproject.users(username);


--
-- Name: teamcandidatures teamcandidatures_team_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.teamcandidatures
    ADD CONSTRAINT teamcandidatures_team_fkey FOREIGN KEY (team) REFERENCES bdproject.teams(name);


--
-- Name: teams teams_admin_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.teams
    ADD CONSTRAINT teams_admin_fkey FOREIGN KEY (admin) REFERENCES bdproject.users(username) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: tournaments tournaments_manager_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.tournaments
    ADD CONSTRAINT tournaments_manager_fkey FOREIGN KEY (manager) REFERENCES bdproject.users(username) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: users users_photo_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.users
    ADD CONSTRAINT users_photo_fkey FOREIGN KEY (photo) REFERENCES bdproject.photos(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: users users_studycourse_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.users
    ADD CONSTRAINT users_studycourse_fkey FOREIGN KEY (studycourse) REFERENCES bdproject.studycourses(coursename) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: SCHEMA bdproject; Type: ACL; Schema: -; Owner: postgres
--

GRANT ALL ON SCHEMA bdproject TO strafo;


--
-- PostgreSQL database dump complete
--

