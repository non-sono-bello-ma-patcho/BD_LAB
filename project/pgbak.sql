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

CREATE DATABASE bdproject WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_GB.UTF-8' LC_CTYPE = 'en_GB.UTF-8';


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
-- Name: bdproject; Type: SCHEMA; Schema: -; Owner: andreo
--

CREATE SCHEMA bdproject;


ALTER SCHEMA bdproject OWNER TO andreo;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: gender; Type: TYPE; Schema: bdproject; Owner: strafo
--

CREATE TYPE bdproject.gender AS ENUM (
    'uomo',
    'donna',
    'non definito'
);


ALTER TYPE bdproject.gender OWNER TO strafo;

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
-- Name: ruolo; Type: TYPE; Schema: bdproject; Owner: strafo
--

CREATE TYPE bdproject.ruolo AS ENUM (
    'arbitro',
    'giocatore'
);


ALTER TYPE bdproject.ruolo OWNER TO strafo;

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
-- Name: aux_acceptmatches(character varying, integer); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.aux_acceptmatches(_tour character varying, _phase integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
  _manager  varchar(64)=(select  manager from tournaments where name = _tour );
BEGIN
  update matchcandidatures mc
   set confirmed = _manager
   where mc.match in ( select id
                  from matches m
                  where m.tournament = _tour and m.phase = _phase
                  );
END;
$$;


ALTER FUNCTION bdproject.aux_acceptmatches(_tour character varying, _phase integer) OWNER TO strafo;

--
-- Name: aux_assignmatch(character varying, character varying, integer); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.aux_assignmatch(_team character varying, _tour character varying, _phase integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
  _matchno bigint;
BEGIN

  select matches.id from matches where matches.tournament = _tour and matches.phase=_phase and matches.id
        not in (  
                      select m.id
                      from matches m left outer join matchcandidatures mc on m.id = mc.match
                      where tournament =_tour and m.phase=_phase and m.id is not null
                      group by m.id
                      having count(*)>=2
               )
  limit 1 into _matchno;

  if(_matchno is null)then return; end if ;
  insert into matchcandidatures values (_team, _matchno, null);

END;
$$;


ALTER FUNCTION bdproject.aux_assignmatch(_team character varying, _tour character varying, _phase integer) OWNER TO strafo;

--
-- Name: aux_competitors(bigint); Type: FUNCTION; Schema: bdproject; Owner: andreo
--

CREATE FUNCTION bdproject.aux_competitors(id bigint) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
  return array_to_string(
      array (select team
    from bdproject.matchcandidatures
    where match = id
    and confirmed notnull),
    ' vs ',
    '*'
  );
END;
$$;


ALTER FUNCTION bdproject.aux_competitors(id bigint) OWNER TO andreo;

--
-- Name: aux_ispremium(character varying); Type: FUNCTION; Schema: bdproject; Owner: andreo
--

CREATE FUNCTION bdproject.aux_ispremium(character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
BEGIN
  return $1 in (select username from bdproject.users where uprivilege = 'premium');
END;
$_$;


ALTER FUNCTION bdproject.aux_ispremium(character varying) OWNER TO andreo;

--
-- Name: aux_outcomesinmatch(bigint); Type: FUNCTION; Schema: bdproject; Owner: andreo
--

CREATE FUNCTION bdproject.aux_outcomesinmatch(_id bigint) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
  return (
      select count(*)
      from outcomes o
      where o.match = _id
    ) <=2;
END;
$$;


ALTER FUNCTION bdproject.aux_outcomesinmatch(_id bigint) OWNER TO andreo;

--
-- Name: aux_referee(bigint); Type: FUNCTION; Schema: bdproject; Owner: andreo
--

CREATE FUNCTION bdproject.aux_referee(bigint) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
BEGIN
  return (
    select applicant
    from matches
    left outer join refereecandidatures r on matches.id = r.match
    where id = $1 and confirmed notnull 
  );
END;
$_$;


ALTER FUNCTION bdproject.aux_referee(bigint) OWNER TO andreo;

--
-- Name: aux_samecat(bigint, character varying); Type: FUNCTION; Schema: bdproject; Owner: andreo
--

CREATE FUNCTION bdproject.aux_samecat(m bigint, t character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
  return(
    select category
    from matches
    where id = m
  ) = (
    select category
    from teams
    where name = t
  );
END;
$$;


ALTER FUNCTION bdproject.aux_samecat(m bigint, t character varying) OWNER TO andreo;

--
-- Name: aux_workingdays(date); Type: FUNCTION; Schema: bdproject; Owner: andreo
--

CREATE FUNCTION bdproject.aux_workingdays(cdate date) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
  cmonth integer:= date_part('month', (cdate));
  cyear integer:= date_part('year', (cdate));
  daysnum integer:= (select date_part('days',
                                      (cyear::text ||'-'|| cmonth::text ||'-01')::date
                                        + '1 month' :: interval
                                        - '1 day' :: interval
                                )
                    );
BEGIN
  return (with days as
  (
      select dd, extract(DOW from dd) dw
      from generate_series((cyear :: text ||'-'|| cmonth :: text ||'-01') :: date,
                           (cyear :: text ||'-'|| cmonth :: text || '-' ||daysnum :: text) :: date, '1 day' :: interval) dd
  )
  select count(*) from days where dw not in (6, 0)
  );
END;
$$;


ALTER FUNCTION bdproject.aux_workingdays(cdate date) OWNER TO andreo;

--
-- Name: calcola_squadre_vincitrici(character varying, integer); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.calcola_squadre_vincitrici(_tour character varying, _phase integer) RETURNS refcursor
    LANGUAGE plpgsql
    AS $$
declare
  teamset refcursor;
BEGIN
open teamset for
  select team
    from outcomes o1 join matches m1  on o1.match = m1.id
    where m1.tournament=_tour
    and m1.phase=_phase
    and
      (
        (
          (m1.category='calcio'or m1.category='basket')
          and
          (o1.score>(select o2.score from outcomes o2 where o2.match=m1.id and o2.team<>o1.team))

        )
        or
        (
          (m1.category='tennis'or m1.category='volley')
          and
          (o1.win>(select o3.score from outcomes o3 where o3.match=m1.id and o3.team<>o1.team))

        )


      );
return teamset;
END;
$$;


ALTER FUNCTION bdproject.calcola_squadre_vincitrici(_tour character varying, _phase integer) OWNER TO strafo;

--
-- Name: count_match_played_by_category(character varying, bdproject.sport); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.count_match_played_by_category(_username character varying, _categoria bdproject.sport) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
begin
	select count(*)
	from matches
	left join matchcandidatures on matches.id=matchcandidatures.match
	left join teamscandidatures on matchcandidatures.team=teamcandidatures.team
	where 
	matches.mstate='closed' 
	and matches.category=_categoria 
	and matchcandidatures.confirmed is not null
	and teamcandidatures.applicant=_username;
end;
$$;


ALTER FUNCTION bdproject.count_match_played_by_category(_username character varying, _categoria bdproject.sport) OWNER TO strafo;

--
-- Name: FUNCTION count_match_played_by_category(_username character varying, _categoria bdproject.sport); Type: COMMENT; Schema: bdproject; Owner: strafo
--

COMMENT ON FUNCTION bdproject.count_match_played_by_category(_username character varying, _categoria bdproject.sport) IS 'funzione  che  restituisce  il  numero  delle partite  a  cui  un  singolo  utente  ha  partecipato  in  una  specifica  categoria.';


--
-- Name: count_player(character varying); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.count_player(teamname character varying) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
begin
	return (
	select count(*)
	from TeamCandidatures
	where teamcandidatures.team = teamName and teamcandidatures.admin is not null 
			);
end;
$$;


ALTER FUNCTION bdproject.count_player(teamname character varying) OWNER TO strafo;

--
-- Name: FUNCTION count_player(teamname character varying); Type: COMMENT; Schema: bdproject; Owner: strafo
--

COMMENT ON FUNCTION bdproject.count_player(teamname character varying) IS 'Conta i giocatori iscritti a una squadra, solo quelli confermati';


--
-- Name: fase_terminata(character varying, integer); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.fase_terminata(_tournament character varying, _phase integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
  ttype varchar(64)=(select tournaments.ttype from tournaments where tournaments.name=_tournament);
  numberofmatches int;
  n int;
begin

if(ttype='italiana')then

  else if(ttype='eliminazione diretta')then
        numberofmatches:=power(2,_phase)*2;--perchè gli outcomes sono 2 per partita
        select count(distinct team) from outcomes join matches on outcomes.match = matches.id where matches.tournament=_tournament and matches.phase=_phase into n;
        return (n=numberofmatches);
      else--eliminazione mista
        --gestito manualmente dall'utente
        --il trigger match insert permette l'inserimento manuale per questa tipologia di torneo
      end if;
end if;

return true;
end;
$$;


ALTER FUNCTION bdproject.fase_terminata(_tournament character varying, _phase integer) OWNER TO strafo;

--
-- Name: incrementapartitegiocateutente(character varying, character varying); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.incrementapartitegiocateutente(_tipo character varying, _username character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  if (_tipo='calcio') then
    update users
    set soccermatch=soccermatch+1
    where username=_username;
  else if (_tipo='basket') then
          update users
          set basketmatch=basketmatch+1
          where username=_username;
      else if (_tipo='pallavolo') then
              update users
              set volleymatch=volleymatch+1
              where username=_username;
          else if (_tipo='tennis') then
                  update users
                  set tennismatch=tennismatch+1
                  where username=_username;
                end if;
          end if;
      end if;
  end if;
end;
$$;


ALTER FUNCTION bdproject.incrementapartitegiocateutente(_tipo character varying, _username character varying) OWNER TO strafo;

--
-- Name: int_analysis_best_behaviour_cs(); Type: FUNCTION; Schema: bdproject; Owner: andreo
--

CREATE FUNCTION bdproject.int_analysis_best_behaviour_cs() RETURNS TABLE(category bdproject.sport, studycourse character varying, avgscore double precision)
    LANGUAGE plpgsql
    AS $$
begin
return query(
  select csy.category, csy.studycourse, csy."average score"::double precision
  from cs_yield csy
  where "average score" in (
    select max("average score")
    from cs_yield cy
    group by cy.category
    )
);
end;
$$;


ALTER FUNCTION bdproject.int_analysis_best_behaviour_cs() OWNER TO andreo;

--
-- Name: int_analysis_best_mactive_course(); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.int_analysis_best_mactive_course() RETURNS TABLE(studycourse character varying, category bdproject.sport, type character varying)
    LANGUAGE plpgsql
    AS $$
begin
return query

  select U.studycourse,M.category,'massima scelta'
  from matches M join matchcandidatures on M.id = matchcandidatures.match
  join teamcandidatures on teamcandidatures.team=matchcandidatures.team
  join users U on U.username=teamcandidatures.applicant
  where teamcandidatures.admin is not null and matchcandidatures.confirmed is not null
  group by U.studycourse,M.category
  having count(M.category)=(
                            select max(T.max)
                            from (select count(matches.id) as max
                                  from matches
                                         join matchcandidatures on matches.id = matchcandidatures.match
                                         join teamcandidatures on teamcandidatures.team = matchcandidatures.team
                                         join users on users.username = teamcandidatures.applicant
                                  where teamcandidatures.admin is not null
                                    and matchcandidatures.confirmed is not null
                                    and users.studycourse = U.studycourse
                                  group by users.studycourse, matches.category
                                 ) as T
                           )
  union
  select U.studycourse,M.category,'minima scelta'
  from matches M join matchcandidatures on M.id = matchcandidatures.match
  join teamcandidatures on teamcandidatures.team=matchcandidatures.team
  join users U on U.username=teamcandidatures.applicant
  where teamcandidatures.admin is not null and matchcandidatures.confirmed is not null
  group by U.studycourse,M.category
  having count(M.category)=(
                            select min(T.max)
                            from (select count(matches.id) as max
                                  from matches
                                         join matchcandidatures on matches.id = matchcandidatures.match
                                         join teamcandidatures on teamcandidatures.team = matchcandidatures.team
                                         join users on users.username = teamcandidatures.applicant
                                  where teamcandidatures.admin is not null
                                    and matchcandidatures.confirmed is not null
                                    and users.studycourse = U.studycourse
                                  group by users.studycourse, matches.category
                                 ) as T
                           )

order by studycourse,category;

end;
$$;


ALTER FUNCTION bdproject.int_analysis_best_mactive_course() OWNER TO strafo;

--
-- Name: int_analysis_course_category_bestplayer(); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.int_analysis_course_category_bestplayer() RETURNS TABLE(category bdproject.sport, study_course character varying, player character varying, win_n bigint)
    LANGUAGE plpgsql
    AS $$
begin
return query(
select t1.category,u1.studycourse,u1.username,count(*)
from tournaments  t1
left join teamcandidatures   on t1.winner = teamcandidatures.team
left join users u1  on teamcandidatures.applicant = u1.username
group by t1.category,u1.studycourse,u1.username
having count(*)=(

  select max(T.n_win1)
  from (
         select t.category,u.studycourse,u.username,count(*) as n_win1
         from tournaments t
                left join teamcandidatures tc on t.winner = tc.team
                left join users u on tc.applicant = u.username
         group by t.category,u.studycourse,u.username
       ) as T
  where T.category=t1.category and T.studycourse=u1.studycourse
  group by T.category,T.studycourse
  )
order by t1.category,u1.studycourse
);
end;
$$;


ALTER FUNCTION bdproject.int_analysis_course_category_bestplayer() OWNER TO strafo;

--
-- Name: int_analysis_most_pop_cat(); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.int_analysis_most_pop_cat() RETURNS TABLE(category bdproject.sport)
    LANGUAGE plpgsql
    AS $$
begin
  return query
  select matches.category as Category
  from matches join matchcandidatures  on matches.id = matchcandidatures.match
  join teamcandidatures on teamcandidatures.team=matchcandidatures.team
  where teamcandidatures.admin is not  null and matchcandidatures.confirmed is not null
  group by matches.category
  having count(distinct matches.category)=(select distinct categories.name  from categories);
end;
$$;


ALTER FUNCTION bdproject.int_analysis_most_pop_cat() OWNER TO strafo;

--
-- Name: int_analysis_most_popular_active_tournament(); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.int_analysis_most_popular_active_tournament() RETURNS TABLE(team character varying)
    LANGUAGE plpgsql
    AS $$
begin
  return query(
    select t1.team from (
      select tourc.tournament as team,count(*) as npartecipanti
      from tournamentscandidatures tourc join teamcandidatures teamc on tourc.team=teamc.team
      group by tourc.tournament order by npartecipanti desc
      limit 1
    )as t1
    union
    select t2.team from (
      select tournaments.name as team
      from tournaments
      order by tournaments.name desc
      limit 1
    )as t2
  );
end;
$$;


ALTER FUNCTION bdproject.int_analysis_most_popular_active_tournament() OWNER TO strafo;

--
-- Name: int_analysis_woman_cat_course(); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.int_analysis_woman_cat_course() RETURNS TABLE(category bdproject.sport, studycourse character varying, womanpercentage real)
    LANGUAGE plpgsql
    AS $$
begin
return query
  select M.category as Category,U.studycourse,
         (cast(count(distinct username) as decimal(5,2))/
         (
            select count(distinct username)
            from matches join matchcandidatures on matches.id = matchcandidatures.match
            join teamcandidatures on matchcandidatures.team=teamcandidatures.team
            join users  on users.username=teamcandidatures.applicant
            where teamcandidatures.admin is not null and matchcandidatures.confirmed is not null
            and matches.mstate='closed' and users.studycourse=U.studycourse and M.category=matches.category
         ))*100 as WomanPercentage
  from matches M join matchcandidatures on M.id = matchcandidatures.match
  join teamcandidatures on matchcandidatures.team=teamcandidatures.team
  join users U on U.username=teamcandidatures.applicant
  where teamcandidatures.admin is not null and matchcandidatures.confirmed is not null
  and M.mstate='closed'
  group by M.category,U.studycourse
  order by M.category,U.studycourse;
end;
$$;


ALTER FUNCTION bdproject.int_analysis_woman_cat_course() OWNER TO strafo;

--
-- Name: int_simpl_always_acc_ref(bdproject.sport); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.int_simpl_always_acc_ref(_category bdproject.sport) RETURNS TABLE(username character varying, type character varying)
    LANGUAGE plpgsql
    AS $$
begin
  return query
  (
    select T.applicant as Username,'sempre_accettato' as Type
    from matches join matchcandidatures on matches.id=matchcandidatures.match
    join teamcandidatures T on T.team=matchcandidatures.team
    where matches.mstate='closed' and matchcandidatures.confirmed is not null
    and T.admin is not null and matches.category=_category
    group  by T.applicant
    having count(*)=
           (
               select count(*)
               from matches join matchcandidatures on matches.id=matchcandidatures.match
               join teamcandidatures  on teamcandidatures.team=matchcandidatures.team
               where matches.mstate='closed' and matchcandidatures.confirmed is not null
               and matches.category=_category and teamcandidatures.applicant=T.applicant
            )
    union
    select T.applicant as Username,'sempre_rifiutato' as Type
    from matches join matchcandidatures on matches.id=matchcandidatures.match
    join teamcandidatures T on T.team=matchcandidatures.team
    where matches.mstate='closed' and matchcandidatures.confirmed is not null
    and T.admin is  null and matches.category=_category
    group  by T.applicant
    having count(*)=
           (
               select count(*)
               from matches join matchcandidatures on matches.id=matchcandidatures.match
               join teamcandidatures  on teamcandidatures.team=matchcandidatures.team
               where matches.mstate='closed' and matchcandidatures.confirmed is not null
               and matches.category=_category and teamcandidatures.applicant=T.applicant
            )
  );
end;
$$;


ALTER FUNCTION bdproject.int_simpl_always_acc_ref(_category bdproject.sport) OWNER TO strafo;

--
-- Name: int_simpl_free_facilities(interval, interval); Type: FUNCTION; Schema: bdproject; Owner: andreo
--

CREATE FUNCTION bdproject.int_simpl_free_facilities(_begin interval, _end interval) RETURNS TABLE(name character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
  return query (
    select building
    from program p
    left outer join buildings b on p.building = b.name
    where date_part('hour', opening) <= date_part('hours',_begin) and date_part('hour', closure)>= date_part('hour', _end) and usagePercentage < (
      select avg(usagePercentage)
      from program
      )
  );
END;
$$;


ALTER FUNCTION bdproject.int_simpl_free_facilities(_begin interval, _end interval) OWNER TO andreo;

--
-- Name: int_simpl_multiple_referee(bdproject.sport); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.int_simpl_multiple_referee(_category bdproject.sport) RETURNS TABLE(matchid bigint, refereenumber numeric)
    LANGUAGE plpgsql
    AS $$
begin
  return query
  (
    select Ma.id as MatchId,count(*) as RefereeNumber
    from refereecandidatures  join matches Ma  on refereecandidatures.match = Ma.id
    where Ma.category=_category and Ma.mstate='open'
    and not exists(--non esiste un arbitro già confermato
                    select refereecandidatures.applicant
                    from matches join refereecandidatures on matches.id = refereecandidatures.match
                    where matches.id=Ma.id and refereecandidatures.confirmed is not null
                  )
    group by Ma.id

  );
end;
$$;


ALTER FUNCTION bdproject.int_simpl_multiple_referee(_category bdproject.sport) OWNER TO strafo;

--
-- Name: int_simpl_open_events(character varying); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.int_simpl_open_events(buildingname character varying) RETURNS TABLE(matchid bigint, category bdproject.sport, freeslot bigint)
    LANGUAGE plpgsql
    AS $$
begin
  select matches.id as MatchId,categories.name as Category, 2*categories.max-count() as FreeSlot
  from matches
  inner join categories  on matches.category = categories.name
  inner join matchcandidatures  on matches.id = matchcandidatures.match
  inner join teamcandidatures on matchcandidatures.team=teamcandidatures.team
  where matches.mstate='open'
  and teamcandidatures.admin is not null
  and matches.building=buildingName
  and matchcandidatures.confirmed is not null 
  group by matches.id,categories.name,categories.max;

end;
$$;


ALTER FUNCTION bdproject.int_simpl_open_events(buildingname character varying) OWNER TO strafo;

--
-- Name: FUNCTION int_simpl_open_events(buildingname character varying); Type: COMMENT; Schema: bdproject; Owner: strafo
--

COMMENT ON FUNCTION bdproject.int_simpl_open_events(buildingname character varying) IS 'Interrogazione semplice 1:determinare le categorie per cui ci sono eventi non ancora chiusi in programma in un certo impianto insieme al numero di posti giocatori ancora disponibili per quell’evento';


--
-- Name: int_simpl_veterans(bigint); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.int_simpl_veterans(eventoid bigint) RETURNS TABLE(username character varying, teamname character varying, role character varying, matchesnumber numeric)
    LANGUAGE plpgsql
    AS $$
declare
  nome_categoria bdproject.sport:=(select category from matches where id=eventoId);
begin
  if(nome_categoria='volley')then
    return query
    select username,teamcandidatures.team,teamcandidatures.role,users.volleymatch
    from matchcandidatures
    join teamcandidatures on matchcandidatures.team=teamcandidatures.team
    join users  on teamcandidatures.applicant = users.username
    where matchcandidatures.confirmed is not null
    and teamcandidatures is not null
    order by users.volleymatch;
  end if;

  if(nome_categoria='tennis')then
    return query
    select username,teamcandidatures.team,teamcandidatures.role,users.tennismatch
    from matchcandidatures
    join teamcandidatures on matchcandidatures.team=teamcandidatures.team
    join users  on teamcandidatures.applicant = users.username
    where matchcandidatures.confirmed is not null
    and teamcandidatures is not null
    order by users.tennismatch;
  end if;

  if(nome_categoria='calcio')then
    return query
    select username,teamcandidatures.team,teamcandidatures.role,users.soccermatch
    from matchcandidatures join teamcandidatures on matchcandidatures.team=teamcandidatures.team
    join users  on teamcandidatures.applicant = users.username
    where matchcandidatures.confirmed is not null and teamcandidatures is not null
    order by users.soccermatch;
  end if;

  if(nome_categoria='basket')then
    return query
    select username,teamcandidatures.team,teamcandidatures.role,users.basketmatch
    from matchcandidatures
    join teamcandidatures on matchcandidatures.team=teamcandidatures.team
    join users  on teamcandidatures.applicant = users.username
    where matchcandidatures.confirmed is not null
    and teamcandidatures is not null
    order by users.basketmatch;
  end if;
end;
$$;


ALTER FUNCTION bdproject.int_simpl_veterans(eventoid bigint) OWNER TO strafo;

--
-- Name: FUNCTION int_simpl_veterans(eventoid bigint); Type: COMMENT; Schema: bdproject; Owner: strafo
--

COMMENT ON FUNCTION bdproject.int_simpl_veterans(eventoid bigint) IS 'Int_simpl_veterans determina, per un certo evento, i giocatori candidati e confermati con un numero di partite disputate nella categoria dell’evento più alto.';


--
-- Name: int_simpl_winner_tournament_phase(character varying, integer); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.int_simpl_winner_tournament_phase(_tour character varying, _phase integer) RETURNS TABLE(teams character varying)
    LANGUAGE plpgsql
    AS $$
begin
return query
(
    select team
    from outcomes o1 join matches m1  on o1.match = m1.id
    where m1.tournament=_tour
    and m1.phase=_phase
    and
      (
        (
          (m1.category='calcio'or m1.category='basket')
          and
          (o1.score>(select o2.score from outcomes o2 where o2.match=m1.id and o2.team<>o1.team))

        )
        or
        (
          (m1.category='tennis'or m1.category='volley')
          and
          (o1.win>(select o3.score from outcomes o3 where o3.match=m1.id and o3.team<>o1.team))

        )


      )
);
end;
$$;


ALTER FUNCTION bdproject.int_simpl_winner_tournament_phase(_tour character varying, _phase integer) OWNER TO strafo;

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
		) > 2;--le partite in questo caso sono sempre giocate da 2 squadre
end;


$$;


ALTER FUNCTION bdproject.match_full(matchno bigint) OWNER TO postgres;

--
-- Name: FUNCTION match_full(matchno bigint); Type: COMMENT; Schema: bdproject; Owner: postgres
--

COMMENT ON FUNCTION bdproject.match_full(matchno bigint) IS 'Restituisce vero esistono due squadre confermate per una partita';


--
-- Name: match_full_plus_1(bigint); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.match_full_plus_1(matchno bigint) RETURNS boolean
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
		) >=2;--le partite in questo caso sono sempre giocate da 2 squadre
end;


$$;


ALTER FUNCTION bdproject.match_full_plus_1(matchno bigint) OWNER TO strafo;

--
-- Name: FUNCTION match_full_plus_1(matchno bigint); Type: COMMENT; Schema: bdproject; Owner: strafo
--

COMMENT ON FUNCTION bdproject.match_full_plus_1(matchno bigint) IS 'Serve per controllare se la partita può passare da aperta a chiusa-';


--
-- Name: proc_trigger_evaluation_insert(); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.proc_trigger_evaluation_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  partiteincomune integer;
begin
      select count(*) into partiteincomune
      from
      (
          select outcomes.match, teamcandidatures.applicant
					from outcomes
					inner join matchcandidatures on outcomes.match=matchcandidatures.match
          inner join teamcandidatures on teamcandidatures.team=matchcandidatures.team
          where teamcandidatures.admin is not NULL and applicant=new.evaluated
      ) as aux1
      inner join
      (
          select outcomes.match, teamcandidatures.applicant
          from outcomes
          inner join matchcandidatures on outcomes.match = matchcandidatures.match
          inner join teamcandidatures on teamcandidatures.team = matchcandidatures.team
          where teamcandidatures.admin is not NULL and applicant = new.evaluator


      ) as aux2 on aux1.match=aux2.match;

      if (partiteincomune=0) then
      raise exception 'Impossibile inserire recension.Nessuna partita in comune.';
      end if;
      
     
  return new;
end;
$$;


ALTER FUNCTION bdproject.proc_trigger_evaluation_insert() OWNER TO strafo;

--
-- Name: proc_trigger_matchcandidatures_insert(); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.proc_trigger_matchcandidatures_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
	  if (new.confirmed is not NULL ) then
		  		  raise exception 'Impossibile inserire la candidatura già confermata per % .Eseguire inserimento e conferma separatamente' ,new.match;
	  end if;
	  return new;
end;
$$;


ALTER FUNCTION bdproject.proc_trigger_matchcandidatures_insert() OWNER TO strafo;

--
-- Name: proc_trigger_matchcandidatures_update(); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.proc_trigger_matchcandidatures_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  cursorePartecipantiSquadraGiaInserita cursor is
			select applicant
			from matchcandidatures inner join teamcandidatures on matchcandidatures.team=teamcandidatures.team
			where matchcandidatures.match=new.match
        and matchcandidatures.confirmed is not null
        and teamcandidatures.admin is not null
        and teamcandidatures.team<>new.team;
  cursorePartecipantiSquadra cursor is
			select applicant
			from matchcandidatures inner join teamcandidatures on matchcandidatures.team=teamcandidatures.team
			where matchcandidatures.match=new.match
        and matchcandidatures.confirmed is not null
        and teamcandidatures.admin is not null
        and teamcandidatures.team=new.team;
begin
  if  match_full(new.match) then
      raise exception 'Impossibile confermare la candidatura della squadra % per il match % la partita è già piena.', new.team,new.match;
  end if;

  if (not valid_team(new.team)) then
	    raise exception 'Impossibile confermare la candidatura per il match %, la squadra % non ha raggiunto il minimo dei giocatori o ha superato il massimo consentito.', new.match, new.team;
	end if;

  for partecipante1 in cursorePartecipantiSquadraGiaInserita
  loop
    for partecipante2 in cursorePartecipantiSquadra
    loop
      if(partecipante1=partecipante2)then
        raise exception 'Impossibile confermare squadra %s, %s gioca già per la squadra avversaria confermata per il match.',new.team,partecipante1;
      end if;
    end loop;
  end loop;

  if  match_full_plus_1(new.match) then
    update matches
    set mstate='closed'
    where matches.id=new.match;
  end if;
  return new;
end;
$$;


ALTER FUNCTION bdproject.proc_trigger_matchcandidatures_update() OWNER TO strafo;

--
-- Name: proc_trigger_matches_insert(); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.proc_trigger_matches_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  teamname1 varchar(64);
  teamname2 varchar(64);
begin
  if(new.tournament is NULL) then
    teamname1:=concat(new.id,'_1');
    teamname2:=concat(new.id,'_2');
    insert into teams values(teamname1,NULL,new.category,NULL,NULL,new.admin,'open');
    insert into teams values(teamname2,NULL,new.category,NULL,NULL,new.admin,'open');
    insert into matchcandidatures values(teamname1,new.id,NULL);
    insert into matchcandidatures values(teamname2,new.id,NULL);
  else
      if((select ttype from tournaments where tournaments.name=new.tournament)='misto')then
        if(not sameadmintournaments(new.tournament,new.admin)) then
          raise exception 'L''admin % del match non corrisponde al manager del torneo % associato.',new.admin,new.tournament;
        end if;
      else
          --raise exception 'Le partite dei tornei vengono inserite automaticamente.(tranne per il misto)';
      end if;
  end if ;
	return new;
end;
$$;


ALTER FUNCTION bdproject.proc_trigger_matches_insert() OWNER TO strafo;

--
-- Name: proc_trigger_outcomes_insert_update(); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.proc_trigger_outcomes_insert_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
	cursorePartecipanti cursor is
			select applicant
			from matchcandidatures inner join teamcandidatures on matchcandidatures.team=teamcandidatures.team
			where matchcandidatures.match=new.match and matchcandidatures.confirmed is not null  and teamcandidatures.admin is not null ;
	categoria varchar(64);
  _tournament varchar(64)=(select distinct tournament from outcomes join matches  on outcomes.match = matches.id where matches.id=new.match);
  teamset refcursor;
  phase int =(select distinct phase from outcomes join matches  on outcomes.match = matches.id where matches.id=new.match);
  _team varchar(64);
begin
	--esiste la partita in questione? sì perchè match è chiave primaria sulla tabella match--

	categoria:=(select category from matches where matches.id=new.match);
	--l'admin che la conferma è quello giusto?--
	if(not sameadminmatch(new.match,new.admin)) then
		raise exception
		'Impossibile inserire esito partita(Permesso negato).';
	end if;
	--il match è ancora aperto--
	if(not is_match_closed(new.match))then
		raise exception
		'Impossibile inserire esito partita(partita ancora aperta).';
	end if;
	--la data di inserimeto è congruente con quella del match?--
	if(date_cmp(new.insertedon,(select organizedon from matches where matches.id=new.match))<0)then
		raise exception
		'Impossibile inserire esito partita(data inserimento precedente all data della partita).';
	end if;
	for  partecipante in cursorePartecipanti
	loop
		execute incrementapartitegiocateutente(categoria,partecipante.applicant);
	end loop;

	--se partita fa parte di un torneo controlla se la fase è già terminata e assegna i vincitori alle partite successive
	if(_tournament is not null) then
		if(fase_terminata(_tournament,phase))then
			teamset:=calcola_squadre_vincitrici(_tournament,phase );
			--open teamset;
			fetch teamset into _team;
		  if(phase>0)then
		    while (FOUND) loop
		      raise  notice 'assign %',_team;
					execute aux_assignmatch(_team,_tournament,phase-1);
					fetch teamset into _team;
				end loop;
				execute aux_acceptmatches(_tournament, phase-1);
		  else--setta vincitore
				update tournaments
		    set winner=_team
		    where name=_tournament;
		  end if;

		end if ;
		if(teamset is not  null) then 
		close teamset;
		end if;
	end if;

	return new;
end;
$$;


ALTER FUNCTION bdproject.proc_trigger_outcomes_insert_update() OWNER TO strafo;

--
-- Name: proc_trigger_refereecandidatures_insert(); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.proc_trigger_refereecandidatures_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if(new.confirmed is not null) then
    raise exception 'Impossibile inserire e confermare l''utente allo stesso tempo';
  end if;
  return new;
end;
$$;


ALTER FUNCTION bdproject.proc_trigger_refereecandidatures_insert() OWNER TO strafo;

--
-- Name: proc_trigger_refereecandidatures_update(); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.proc_trigger_refereecandidatures_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if(new.confirmed is not NULL) then
    if(referee_assigned(new.match)) then
      raise exception 'Arbitro già assegnato per la partita %',new.match;
    end if;
  end if;
  return new;
end;
$$;


ALTER FUNCTION bdproject.proc_trigger_refereecandidatures_update() OWNER TO strafo;

--
-- Name: proc_trigger_teamcandidatures_insert(); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.proc_trigger_teamcandidatures_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
	  if (new.admin is not NULL ) then
		  		  raise exception 'Impossibile inserire la candidatura già confermata per % .Eseguire inserimento e conferma separatamente' ,old.applicant;
	  end if;
	  return new;
end;
$$;


ALTER FUNCTION bdproject.proc_trigger_teamcandidatures_insert() OWNER TO strafo;

--
-- Name: proc_trigger_teamcandidatures_update(); Type: FUNCTION; Schema: bdproject; Owner: postgres
--

CREATE FUNCTION bdproject.proc_trigger_teamcandidatures_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
	  if (team_full(new.team)) then
		  		  raise exception 'Impossibile confermare la candidatura per %, la squadra % è piena', old.applicant, old.team;
	  end if;
	  return new;

end;
$$;


ALTER FUNCTION bdproject.proc_trigger_teamcandidatures_update() OWNER TO postgres;

--
-- Name: proc_trigger_tournaments_insert(); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.proc_trigger_tournaments_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  i int;
  livello int ;
begin

if(new.ttype='italiana')then
    if(new.teamsNumber<3)then raise exception 'Impossibile creare il torneo; il numero di squadre non è sufficente.';end if;
    --to be done
  else if(new.ttype='eliminazione diretta')then
        if(mod(new.teamsNumber,2)!=0 or new.teamsNumber<4)then raise exception 'Impossibile creare il torneo; il numero di squadre non è una potenza di 2.';end if;
        livello:=log(2,new.teamsnumber)-1;
        while(livello>=0) loop
          i:=1;
          while (i<=power(2,livello)) loop
          insert into matches (id,building, organizedon, tournament, admin, category,phase) VALUES
                              (default,new.building,current_date,new.name,new.manager,new.category,livello);
          i:=i+1;
          end loop;
          livello:=livello-1;
        end loop;
      else--eliminazione mista
        --gestito manualmente dall'utente
        --il trigger match insert permette l'inserimento manuale per questa tipologia di torneo
      end if;
end if;

return new;
end;
$$;


ALTER FUNCTION bdproject.proc_trigger_tournaments_insert() OWNER TO strafo;

--
-- Name: proc_trigger_tournamentscandidatures_insert(); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.proc_trigger_tournamentscandidatures_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin 
   if(new.confirmed is not null) then
    raise exception 'Impossibile inserire e confermare la candidatura allo stesso tempo';
  end if;
	return new;
end;
$$;


ALTER FUNCTION bdproject.proc_trigger_tournamentscandidatures_insert() OWNER TO strafo;

--
-- Name: proc_trigger_tournamentscandidatures_update(); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.proc_trigger_tournamentscandidatures_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare 
maxlevel int:=(select max(m.phase) from matches m where new.tournament=m.tournament);
competitor cursor for select team from tournamentscandidatures where tournament = new.tournament and confirmed is not null;
begin
  if(tournament_full(new.tournament)) then
    update tournaments set state='closed' where tournaments.name=new.tournament;
    -- creo il cursore su cui iterare
    for teamname in competitor
    loop
      execute aux_assignmatch(teamname.team, new.tournament,maxlevel);
      end loop;
    execute aux_acceptmatches(new.tournament, maxlevel);
  end if;
return new;
end;
$$;


ALTER FUNCTION bdproject.proc_trigger_tournamentscandidatures_update() OWNER TO strafo;

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
-- Name: remaning_slot_match(bigint); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.remaning_slot_match(matchno bigint) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
begin
	return
		2-(select count (*)
			from (
					select team 
					from matchcandidatures
					where match = matchno 
						and confirmed is not null
			) as AUX 
		);
end;

$$;


ALTER FUNCTION bdproject.remaning_slot_match(matchno bigint) OWNER TO strafo;

--
-- Name: FUNCTION remaning_slot_match(matchno bigint); Type: COMMENT; Schema: bdproject; Owner: strafo
--

COMMENT ON FUNCTION bdproject.remaning_slot_match(matchno bigint) IS 'Restituisce numero di slot team liberi per il match passato';


--
-- Name: remaning_slot_team(character varying); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.remaning_slot_team(teamname character varying) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
begin

  return (select Categories.max
		from Teams join Categories on Teams.category = Categories.name
		where Teams.name = TeamName) -count_player(teamname);
end;
$$;


ALTER FUNCTION bdproject.remaning_slot_team(teamname character varying) OWNER TO strafo;

--
-- Name: FUNCTION remaning_slot_team(teamname character varying); Type: COMMENT; Schema: bdproject; Owner: strafo
--

COMMENT ON FUNCTION bdproject.remaning_slot_team(teamname character varying) IS 'Restituisce il numero di posti ancora liberi per il team';


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
-- Name: team_full(character varying); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.team_full(teamname character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
begin
	return count_player(TeamName) >
	(
		select Categories.max
		from Teams join Categories on Teams.category = Categories.name
		where Teams.name = TeamName
	);
end;
$$;


ALTER FUNCTION bdproject.team_full(teamname character varying) OWNER TO strafo;

--
-- Name: team_is_registered_tournament(character varying, character varying); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.team_is_registered_tournament(team character varying, tournament character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
begin
	return team<@(select from tournaments where tournaments.name=tournament);
end;
$$;


ALTER FUNCTION bdproject.team_is_registered_tournament(team character varying, tournament character varying) OWNER TO strafo;

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
-- Name: tournament_full(character varying); Type: FUNCTION; Schema: bdproject; Owner: strafo
--

CREATE FUNCTION bdproject.tournament_full(_tournament character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
numerosquadre int;
n int:= (select teamsnumber  from tournaments where tournaments.name=_tournament);
begin
	select count(*)
	from tournamentscandidatures where tournamentscandidatures.tournament=_tournament and confirmed is not null into numerosquadre;
	return (numerosquadre=n);
end;
$$;


ALTER FUNCTION bdproject.tournament_full(_tournament character varying) OWNER TO strafo;

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


--
-- Name: assignmatch(character varying, character varying, integer); Type: FUNCTION; Schema: public; Owner: andreo
--

CREATE FUNCTION public.assignmatch(team character varying, tour character varying, phase integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
  manager  varchar(64);
  matchno bigint;

BEGIN
  -- per ogni elemento del cursore inserisce ciascuna delle squadre
  select manager from tournaments where name = tour limit 1 into manager;
  select id
    from matches
        where tournament = tour and matches.phase=phase
        not in (  select id
                  from matches
                  right outer join matchcandidatures m on matches.id = m."match"
                  where tournament = tour and matches.phase=phase)
                  limit 1 into matchno;
      insert into matchcandidatures values (team, matchno, manager);
END;
$$;


ALTER FUNCTION public.assignmatch(team character varying, tour character varying, phase integer) OWNER TO andreo;

--
-- Name: aux_referee(bigint); Type: FUNCTION; Schema: public; Owner: andreo
--

CREATE FUNCTION public.aux_referee(bigint) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
BEGIN
  return (
    select applicant
    from matches
    left outer join refereecandidatures r on matches.id = r.match
    where id = $1 and confirmed notnull 
  );
END;
$_$;


ALTER FUNCTION public.aux_referee(bigint) OWNER TO andreo;

--
-- Name: competitors(bigint); Type: FUNCTION; Schema: public; Owner: andreo
--

CREATE FUNCTION public.competitors(id bigint) RETURNS character varying[]
    LANGUAGE plpgsql
    AS $$
BEGIN
  return (
    select team
    from bdproject.matchcandidatures
    where match = id
    and confirmed notnull
  );
END;
$$;


ALTER FUNCTION public.competitors(id bigint) OWNER TO andreo;

--
-- Name: ispremium(character varying); Type: FUNCTION; Schema: public; Owner: andreo
--

CREATE FUNCTION public.ispremium(character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
BEGIN
  return $1 in (select username from bdproject.users where uprivilege = 'premium');
END;
$_$;


ALTER FUNCTION public.ispremium(character varying) OWNER TO andreo;

--
-- Name: proc_trigger_matches_insert(); Type: FUNCTION; Schema: public; Owner: andreo
--

CREATE FUNCTION public.proc_trigger_matches_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  teamname1 character varying(64);
  teamname2 character varying(64);
begin
  if(new.tournament is NULL) then
    teamname1:=concat(new.id,'_1');
    teamname2:=concat(new.id,'_2');
    insert into teams values(teamname1,NULL,new.category,NULL,NULL,new.admin);
    insert into teams values(teamname2,NULL,new.category,NULL,NULL,new.admin);
    insert into matchcandidatures values(cast(teamname1 as varchar) ,new.id,NULL);
    insert into matchcandidatures values(cast(teamname2 as varchar) ,new.id,NULL);
  else
    if(not bdproject.sameadmintournaments(new.tournament,new.admin)) then
      raise exception 'Admin match diverso da admin torneo.';
    end if;
  end if;
	return new;
end;
$$;


ALTER FUNCTION public.proc_trigger_matches_insert() OWNER TO andreo;

--
-- Name: proc_trigger_outcomes_insert_update(); Type: FUNCTION; Schema: public; Owner: andreo
--

CREATE FUNCTION public.proc_trigger_outcomes_insert_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
	datediff integer;
	cursorePartecipanti cursor is
			select applicant
			from matchcandidatures inner join teamcandidatures on matchcandidatures.team=teamcandidatures.team
			where matchcandidatures.match=new.match and matchcandidatures.confirmed is not null  and teamcandidatures.admin is not null ;
	categoria bdproject.sport;

begin
	--esiste la partita in questione? sì perchè match è chiave primaria sulla tabella match--

	--l'admin che la conferma è quello giusto?--
	if(not bdproject.sameadminmatch(new.match,new.admin)) then
		raise exception
		'Impossibile inserire esito partita(Permesso negato).';
	end if;
	--il match è ancora aperto--
	if(not bdproject.is_match_closed(new.match))then
		raise exception
		'Impossibile inserire esito partita(partita ancora aperta).';
	end if;
	--la data di inserimeto è congruente con quella del match?--
	select datediff(day,(select organizedon from matches),new.insertedon) into datediff;
	if(datediff<0)then
		raise exception
		'Impossibile inserire esito partita(data inserimento precedente all data della partita).';
	end if;
	select category from matches where matches.id=new.match into categoria;
	for  partecipante in cursorePartecipanti
	loop
		execute incrementapartitegiocateutente(categoria,partecipante);
	end loop;
	return new;
end;
$$;


ALTER FUNCTION public.proc_trigger_outcomes_insert_update() OWNER TO andreo;

--
-- Name: proc_trigger_teamcandidatures_insert(); Type: FUNCTION; Schema: public; Owner: andreo
--

CREATE FUNCTION public.proc_trigger_teamcandidatures_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
	  if (new.admin is not NULL ) then
		  		  raise exception 'Impossibile inserire la candidatura già confermata per % .Eseguire inserimento e conferma separatamente' ,new.applicant;
	  end if;
	  return new;
end;
$$;


ALTER FUNCTION public.proc_trigger_teamcandidatures_insert() OWNER TO andreo;

--
-- Name: proc_trigger_tournaments_insert(); Type: FUNCTION; Schema: public; Owner: andreo
--

CREATE FUNCTION public.proc_trigger_tournaments_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  i int;
  numberOfMatch int=0;
  livello int ;
begin

if(new.tournamentsteams is not null) then raise exception 'Aggiungere le squadre successivamente tramite update.';end if ;
if(new.ttype='italiana')then
    if(new.teamsNumber<3)then raise exception 'Impossibile creare il torneo; il numero di squadre non è una potenza di 2.';end if;
    numberOfMatch:=new.teamsnumber*(new.teamsnumber-1)/2;

  else if(new.ttype='eliminazione diretta')then
        if(mod(new.teamsNumber,2)!=0 or new.teamsNumber<4)then raise exception 'Impossibile creare il torneo; il numero di squadre non è una potenza di 2.';end if;
        livello:=log(2,new.teamsnumber)-1;
        while(livello>=0) loop
          numberOfMatch:=numberOfMatch+power(2,livello);
          livello:=livello-1;
        end loop;
      else--eliminazione mista
        --gestito manualmente dall'utente
        --il trigger match insert permette l'inserimento manuale per questa tipologia di torneo
      end if;
end if;
i:=1;
while (i<=numberOfMatch) loop
  insert into matches (id,building, organizedon, tournament, admin, category) VALUES
                      (default,null,current_date,new.name,new.manager,new.category);
end loop;

end;
$$;


ALTER FUNCTION public.proc_trigger_tournaments_insert() OWNER TO andreo;

--
-- Name: sameadminmatch(bigint, character varying); Type: FUNCTION; Schema: public; Owner: andreo
--

CREATE FUNCTION public.sameadminmatch(bigint, character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
begin
	return exists(
		select * from bdproject.matches
		where id = $1 and admin = $2
		);
end;


$_$;


ALTER FUNCTION public.sameadminmatch(bigint, character varying) OWNER TO andreo;

--
-- Name: sameadmintournaments(character varying, character varying); Type: FUNCTION; Schema: public; Owner: andreo
--

CREATE FUNCTION public.sameadmintournaments(character varying, character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
begin
	return exists(
		select * from bdproject.tournaments
		where name = $1 and manager = $2
		);
end;


$_$;


ALTER FUNCTION public.sameadmintournaments(character varying, character varying) OWNER TO andreo;

--
-- Name: workinghours(date); Type: FUNCTION; Schema: public; Owner: andreo
--

CREATE FUNCTION public.workinghours(cdate date) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
  cmonth int:= extract('month' from cdate);
  cyear int:= extract('year' from cdate);
  daysnum int:= date_part('days', date_trunc('month', cdate) + '1 month'::interval - '1 day' :: interval)::integer;
BEGIN
  return (with days as
  (
      select dd, extract(DOW from dd) dw
      from generate_series((cyear :: text ||'-'|| cmonth :: text ||'-01') :: date,
                           (cyear :: text ||'-'|| cmonth :: text || '-' || daysnum :: text) :: date, '1 day' :: interval) dd
  )
  select count(*) from days where dw not in (6, 0)
  );
END;
$$;


ALTER FUNCTION public.workinghours(cdate date) OWNER TO andreo;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: buildings; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.buildings (
    name character varying(64) NOT NULL,
    address character varying(128),
    phonenumber character varying(10),
    email character varying(64),
    longitude numeric(7,4),
    latitude numeric(7,4),
    opening time without time zone DEFAULT '08:00:00'::time without time zone,
    closure time without time zone DEFAULT '19:00:00'::time without time zone
);


ALTER TABLE bdproject.buildings OWNER TO postgres;

--
-- Name: categories; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.categories (
    name bdproject.sport NOT NULL,
    regulation text,
    min numeric,
    max numeric,
    photo bigint
);


ALTER TABLE bdproject.categories OWNER TO postgres;

--
-- Name: TABLE categories; Type: COMMENT; Schema: bdproject; Owner: postgres
--

COMMENT ON TABLE bdproject.categories IS 'categorie di sport';


--
-- Name: teamcandidatures; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.teamcandidatures (
    team character varying(64) NOT NULL,
    applicant character varying NOT NULL,
    admin character varying(64),
    role character varying(64) DEFAULT 'undefined'::character varying NOT NULL,
    CONSTRAINT checkconfirmer CHECK (((admin IS NULL) OR bdproject.sameadminteam(team, admin)))
);


ALTER TABLE bdproject.teamcandidatures OWNER TO postgres;

--
-- Name: teams; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.teams (
    name character varying(64) NOT NULL,
    coloremaglia character varying(32),
    category bdproject.sport NOT NULL,
    description text,
    notes text,
    admin character varying(64),
    state bdproject.state DEFAULT 'open'::bdproject.state NOT NULL
);


ALTER TABLE bdproject.teams OWNER TO postgres;

--
-- Name: compositions; Type: VIEW; Schema: bdproject; Owner: postgres
--

CREATE VIEW bdproject.compositions AS
 SELECT teamcandidatures.team,
    teamcandidatures.applicant AS player,
    teamcandidatures.role
   FROM (bdproject.teamcandidatures
     JOIN bdproject.teams t ON (((teamcandidatures.team)::text = (t.name)::text)))
  WHERE (teamcandidatures.admin IS NOT NULL);


ALTER TABLE bdproject.compositions OWNER TO postgres;

--
-- Name: evaluations; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.evaluations (
    evaluated character varying(64) NOT NULL,
    evaluator character varying(64) NOT NULL,
    evaluatedon date DEFAULT ('now'::text)::date,
    match bigint NOT NULL,
    score integer,
    comment text,
    CONSTRAINT evaluation_range CHECK (((score >= 0) AND (score <= 10))),
    CONSTRAINT not_self_eval CHECK (((evaluated)::text <> (evaluator)::text))
);


ALTER TABLE bdproject.evaluations OWNER TO postgres;

--
-- Name: matches; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.matches (
    id bigint NOT NULL,
    building character varying(64) NOT NULL,
    organizedon date NOT NULL,
    insertedon date DEFAULT now() NOT NULL,
    tournament character varying(64),
    mstate bdproject.state DEFAULT 'open'::bdproject.state NOT NULL,
    admin character varying(64) NOT NULL,
    category bdproject.sport NOT NULL,
    phase integer
);


ALTER TABLE bdproject.matches OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.users (
    username character varying(64) NOT NULL,
    password character varying(64),
    name character varying(64) NOT NULL,
    surname character varying(64) NOT NULL,
    birthdate date NOT NULL,
    birthplace character varying(64) NOT NULL,
    photo bigint,
    regnumber integer NOT NULL,
    uprivilege bdproject.privilege DEFAULT 'base'::bdproject.privilege NOT NULL,
    studycourse character varying(64) NOT NULL,
    tennismatch numeric DEFAULT 0 NOT NULL,
    volleymatch numeric DEFAULT 0 NOT NULL,
    soccermatch numeric DEFAULT 0 NOT NULL,
    phonenumber character varying(10),
    basketmatch numeric DEFAULT 0 NOT NULL,
    gender bdproject.gender DEFAULT 'non definito'::bdproject.gender NOT NULL
);


ALTER TABLE bdproject.users OWNER TO postgres;

--
-- Name: cs_yield; Type: VIEW; Schema: bdproject; Owner: andreo
--

CREATE VIEW bdproject.cs_yield AS
 SELECT m.category,
    u.studycourse,
    avg(e.score) AS "average score"
   FROM ((bdproject.evaluations e
     LEFT JOIN bdproject.matches m ON ((e.match = m.id)))
     LEFT JOIN bdproject.users u ON (((e.evaluated)::text = (u.username)::text)))
  GROUP BY m.category, u.studycourse;


ALTER TABLE bdproject.cs_yield OWNER TO andreo;

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
    category bdproject.sport NOT NULL,
    createdon date DEFAULT ('now'::text)::date,
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
    CONSTRAINT checkconfirmer CHECK (((confirmed IS NULL) OR bdproject.sameadminmatch(match, confirmed))),
    CONSTRAINT same_category CHECK (bdproject.aux_samecat(match, team))
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
    score integer DEFAULT 0 NOT NULL,
    goleador text,
    win integer NOT NULL,
    admin character varying(64) NOT NULL,
    insertedon date DEFAULT ('now'::text)::date NOT NULL,
    duration time without time zone DEFAULT '00:00:00'::time without time zone,
    team character varying(64) NOT NULL,
    CONSTRAINT outcome_allowed CHECK (bdproject.aux_outcomesinmatch(match))
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
    photo integer
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
    postedon date DEFAULT ('now'::text)::date NOT NULL,
    photo bigint,
    description text NOT NULL,
    category bdproject.sport NOT NULL,
    studycourse character varying(64),
    postedby character varying(64) NOT NULL
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
-- Name: program; Type: VIEW; Schema: bdproject; Owner: postgres
--

CREATE VIEW bdproject.program AS
 SELECT matches.building,
    date_part('month'::text, matches.organizedon) AS cmonth,
    matches.category,
    count(DISTINCT matches.tournament) AS tournaments,
    count(DISTINCT matches.id) AS matches,
    count(DISTINCT c.player) AS participants,
    count(DISTINCT u.studycourse) AS cs,
    date_part('hours'::text, sum((outcomes.duration)::interval)) AS totalduration,
    (date_part('hours'::text, sum((outcomes.duration)::interval)) / avg((date_part('hour'::text, (buildings.closure - buildings.opening)) * (bdproject.aux_workingdays(matches.organizedon))::double precision))) AS usagepercentage
   FROM (((((bdproject.matches
     LEFT JOIN bdproject.matchcandidatures mc ON ((matches.id = mc.match)))
     LEFT JOIN bdproject.compositions c ON (((mc.team)::text = (c.team)::text)))
     LEFT JOIN bdproject.users u ON (((c.player)::text = (u.username)::text)))
     LEFT JOIN bdproject.outcomes ON ((matches.id = outcomes.match)))
     LEFT JOIN bdproject.buildings ON (((matches.building)::text = (buildings.name)::text)))
  GROUP BY matches.building, (date_part('month'::text, matches.organizedon)), matches.category;


ALTER TABLE bdproject.program OWNER TO postgres;

--
-- Name: refereecandidatures; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.refereecandidatures (
    applicant character varying(64) NOT NULL,
    match bigint NOT NULL,
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
-- Name: tournamentprogram; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.tournamentprogram (
    tournament character varying(64),
    building character varying(64),
    organizedon date,
    id bigint,
    competitors text,
    referee character varying,
    phase integer,
    winner character varying(64)
);

ALTER TABLE ONLY bdproject.tournamentprogram REPLICA IDENTITY NOTHING;


ALTER TABLE bdproject.tournamentprogram OWNER TO postgres;

--
-- Name: tournaments; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.tournaments (
    name character varying(64) NOT NULL,
    ttype bdproject.girone DEFAULT 'italiana'::bdproject.girone NOT NULL,
    manager character varying(64) NOT NULL,
    teamsnumber integer DEFAULT 2 NOT NULL,
    state bdproject.state DEFAULT 'open'::bdproject.state NOT NULL,
    category bdproject.sport,
    winner character varying(64) DEFAULT NULL::character varying,
    building character varying(64) NOT NULL,
    CONSTRAINT manager_premium CHECK (public.ispremium(manager))
);


ALTER TABLE bdproject.tournaments OWNER TO postgres;

--
-- Name: tournamentscandidatures; Type: TABLE; Schema: bdproject; Owner: postgres
--

CREATE TABLE bdproject.tournamentscandidatures (
    team character varying(64) NOT NULL,
    tournament character varying(64) NOT NULL,
    confirmed character varying(64),
    CONSTRAINT checkconfirmer CHECK (((confirmed IS NULL) OR bdproject.sameadmintournaments(tournament, confirmed)))
);


ALTER TABLE bdproject.tournamentscandidatures OWNER TO postgres;

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
-- Name: fora photo; Type: DEFAULT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.fora ALTER COLUMN photo SET DEFAULT nextval('bdproject.fora_photo_seq'::regclass);


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
-- Name: refereecandidatures match; Type: DEFAULT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.refereecandidatures ALTER COLUMN match SET DEFAULT nextval('bdproject.refereecandidatures_match_seq'::regclass);


--
-- Data for Name: buildings; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.buildings (name, address, phonenumber, email, longitude, latitude, opening, closure) FROM stdin;
A.s. Gymnotecnica 	9, Via San Pio X (Genova) 	010 318954	AG@supereva.it 	33.4111	177.1625	08:00:00	19:00:00
A.s. Karate Team Bruno Da Boit 	17/R, Via Vicenza (Sampierdarena) 	010 415856	AKTBDB@fastweb.it 	76.8250	70.7949	08:00:00	19:00:00
A.s. Karate Team Bruno Da Boit Palestra Karate Kung-fu Taichi 	17/A, Via Vicenza (Genova) 	010 415856	AKTBDBPKKT@atlavia.it 	41.6041	27.9673	08:00:00	19:00:00
Associazione Dilettanti Pesca Sportiva Pra-sapello 	43/B, Via Pra  (Genova) 	010 663767	ADPSP@yahoo.it 	87.4177	68.0060	08:00:00	19:00:00
Associazione Bocciofila Genovese 	130/C, Corso Monte Grappa (Genova) 	010 810770	ABG@cheapnet.it 	16.9165	11.3121	08:00:00	19:00:00
Associazione Sportiva Blue Wave Palestra Fitness Danza 	Via Di Robilant Marina 49/R. (Genova) 	010 352618	ASBWPFD@jumpy.it 	68.1362	18.4394	08:00:00	19:00:00
Associazione Sportiva Sisport Gym 	24, Via San Fruttuoso (Genova) 	010 511449	ASSG@email.it 	35.2484	127.4005	08:00:00	19:00:00
Bocciofila Quarto Dei Mille 	27, Via Maggio Giovanni (Genova) 	010 391361	BQDM@lycos.it 	73.5203	134.6017	08:00:00	19:00:00
Body Line Center 	109/R, Via Archimede (Genova) 	010 508938	BLC@virgilio.it 	66.3475	167.4001	08:00:00	19:00:00
Campi Bocce 	10, Via Giovanni Amarena (Genova) 	010 884903	CB@fastweb.it 	86.5240	32.2994	08:00:00	19:00:00
Campi Bocce Belvedere 	21, Corso Belvedere (Sampierdarena) 	010 465984	CBB@atlavia.it 	65.8641	26.9370	08:00:00	19:00:00
Campi Bocce Societa  Pasubio 	46, Salita Oregina (Genova) 	010 217208	CBSP@lycos.it 	70.3039	104.3306	08:00:00	19:00:00
Campi Da Bocce Sardelli 	150/A, Via Struppa (San Siro) 	010 809278	CDBS@libero.it 	21.6314	38.3341	08:00:00	19:00:00
Campo Atletica Leggera Villa Gentile 	6, Via Brigata Salerno (Genova) 	010 397531	CALVG@email.it 	17.5970	78.8906	08:00:00	19:00:00
Centro Universitario Sportivo Genovese 	21/A, Via Monte Zovetto (Genova) 	010 315443	CUSG@tele2.it 	1.1214	148.0881	08:00:00	19:00:00
Circolo Tennis Dipendenti Italimpianti Circolo Tennis 	Via Liri Alberto 8 (Genova) 	010 311892	CTDICT@lycos.it 	38.7790	107.4877	08:00:00	19:00:00
City Gym 	1, Via V Dicembre (Genova) 	010 580412	CG@cheapnet.it 	75.2836	24.1564	08:00:00	19:00:00
Club Alpino Italiano 	7, Gall. Mazzini Giuseppe (Genova) 	010 592122	CAI@email.it 	10.0844	168.6647	08:00:00	19:00:00
Cus Genova 	21/A, Via Monte Zovetto (Genova) 	010 230558	CG@lycos.it 	34.1867	171.3487	08:00:00	19:00:00
Cus Genova Golf Academy Campo Pratica 	Via Degli Anemoni (Genova) 	010 393839	CGGACP@vodafone.it 	30.5880	85.8054	08:00:00	19:00:00
Cus Genova Palazzetto Dello Sport 	54/R, Viale Gambaro Francesco (Genova) 	010 314669	CGPDS@lycos.it 	10.7078	149.4802	08:00:00	19:00:00
Eden Gym 	2/A, Via Santa Maria Via Lata (Genova) 	010 564600	EG@supereva.it 	50.4331	134.6218	08:00:00	19:00:00
Eden Gym S.s.d. A R.l. 	2, Via S. Maria In V. Lata (Genova) 	010 564600	EGSAR@fastweb.it 	15.6184	101.1732	08:00:00	19:00:00
Empire 	63/R, Via Fieschi (Genova) 	010 586671	E@jumpy.it 	70.7326	33.5283	08:00:00	19:00:00
Engi Spa 	2, Via Al Porto Antico (Genova) 	010 252463	ES@galactica.it 	28.4877	107.6781	08:00:00	19:00:00
European Sub Service 	5, Via Del Tritone (Genova) 	010 384264	ESS@blu.it 	23.3775	37.6361	08:00:00	19:00:00
Fitness Center 	68, Via Al Santuario N.S. Della Guardia (Bolzaneto) 	010 714272	FC@tele2.it 	37.4732	102.7956	08:00:00	19:00:00
Fratellanza Nuoto Associazione Sportiva Dilettantistica 	Via Coni Zugna (Genova) 	010 782968	FNASD@worldonline.it 	29.3885	80.4834	08:00:00	19:00:00
Golf Garden Peirano 	32/canc., v. Jenner (Genova) 	010 317978	GGP@cheapnet.it 	62.2747	155.7408	08:00:00	19:00:00
Gymnastic Club 	12/R, Via Cassini (Sampierdarena) 	010 463455	GC@libero.it 	38.1365	114.4848	08:00:00	19:00:00
Il Tempio Della Salute 	54/R, Via Alla Porta Degli Archi (Genova) 	010 591541	ITDS@worldonline.it 	48.0828	130.8285	08:00:00	19:00:00
Immagine Danza 	1/R, Via Carlo Varese (Genova) 	010 504417	ID@worldonline.it 	1.2103	113.5030	08:00:00	19:00:00
La Baia Degli Angeli 	19, Corso Italia (Genova) 	010 314247	LBDA@yahoo.it 	18.7841	132.6286	08:00:00	19:00:00
La Palestra Di Nervi 	32/R, Via Del Commercio (Nervi) 	010 322626	LPDN@email.it 	70.3921	130.7391	08:00:00	19:00:00
Margone Marco 	Corso Italia 19 (Genova) 	010 314247	MM@jumpy.it 	69.6055	125.0211	08:00:00	19:00:00
Masters  Gym 	3, Via Livorno (Genova) 	010 312374	MG@fastweb.it 	10.3806	7.7705	08:00:00	19:00:00
Oasi Tennis E Calcetto 	18, Via Capolungo (Nervi) 	010 323296	OTEC@fastweb.it 	4.2846	48.8992	08:00:00	19:00:00
Palestra 	38, Via Donghi (Genova) 	010 518110	P@yahoo.it 	75.6904	131.0552	08:00:00	19:00:00
Palestra Benefit 	99/R, Via Cesarea (Genova) 	010 543039	PB@lycos.it 	57.2738	66.9251	08:00:00	19:00:00
Palestra Fitness 	2/3, Piazza Galeazzo Alessi (Genova) 	010 588330	PF@alice.it 	31.2551	100.5543	08:00:00	19:00:00
Palestra Italia 	Societa  Sportiva Dilettantistica A Responsabilita  Limitata - V 	010 318587	PI@fastweb.it 	51.6464	140.9201	08:00:00	19:00:00
Palme Sport Apd Tennis 	3, Salita Della Madonnetta (Genova) 	010 219669	PSAT@cheapnet.it 	61.3325	56.2913	08:00:00	19:00:00
Park Tennis Club 	18, Via Zara (Genova) 	010 315546	PTC@fastweb.it 	70.6626	40.1213	08:00:00	19:00:00
Piscina Di San Fruttuoso 	7, Via G. B. D Albertis (Genova) 	010 513873	PDSF@lycos.it 	45.1299	37.0240	08:00:00	19:00:00
Polisportiva La Fratellanza 	Sezione Nuoto - 2, Piazzale Attilio Ghiglione (Pontedecimo) 	010 782968	PLF@alice.it 	56.3509	159.7408	08:00:00	19:00:00
Porto Antico 	Via Al Porto Antico (Genova) 	010 782968	PA@email.it 	18.8739	37.8225	08:00:00	19:00:00
Rio San Michele 	24, Via Giuseppe Ungaretti (Pra) 	010 663286	RSM@lycos.it 	16.8571	125.1325	08:00:00	19:00:00
Rubattino Raffaele Societa  Ginnastica Artistica Ritmica Fitness	17/C, Via Saluzzo (Genova) 	010 317586	RRSGARF@lycos.it 	83.0769	10.9306	08:00:00	19:00:00
S. S. D. Dlf Per Lo Sport 	8, Via Roggerone (Rivarolo Ligure) 	010 261627	SSDDPLS@cheapnet.it 	39.7153	106.3417	08:00:00	19:00:00
Scuola Di Taekwondo Genova Asd 	63, v. Sturla (Genova) 	010 389682	SDTGA@vodafone.it 	38.7552	69.4698	08:00:00	19:00:00
Sezione Cai Di Genova 	1, Via Parmigiani (Genova) 	010 565564	SCDG@cheapnet.it 	16.8679	98.8781	08:00:00	19:00:00
Sezione Cai Di Sampierdarena 	1, Via Battista Agnese (Sampierdarena) 	010 466709	SCDS@yahoo.it 	70.4912	70.2974	08:00:00	19:00:00
Societa  Ginnastica Andrea Doria 	2, Viale Aspromonte (Genova) 	010 582853	SGAD@tiscali.it 	23.9353	148.9566	08:00:00	19:00:00
Societa  Ginnastica Andrea Doria Segreteria 	Viale Aspromonte 2 (Genova) 	010 561850	SGADS@libero.it 	72.7257	19.7712	08:00:00	19:00:00
Societa  Ginnastica Andrea Doria Sezione Tennis 	2, Viale Aspromonte (Genova) 	010 594012	SGADST@worldonline.it 	49.9435	8.6066	08:00:00	19:00:00
Stadio Carlini 	31, Via Vernazza (Genova) 	010 388630	SC@tiscali.it 	45.0358	101.1892	08:00:00	19:00:00
Stadio Luigi Ferraris 	Corso A. De Stefanis (Genova) 	010 612831	SLF@galactica.it 	23.5769	151.0014	08:00:00	19:00:00
Tanny & Sinewy 	139, Via Angelo Scarsellini (Sampierdarena) 	010 415247	TS@blu.it 	64.6840	81.3498	08:00:00	19:00:00
Tennis Club Le Palme Campi Da Tennis 	4, Via Campanella Tommaso (Genova) 	010 313056	TCLPCDT@virgilio.it 	38.0093	134.5888	08:00:00	19:00:00
Tiro A Segno Nazionale 	31, Via Vernazza (Genova) 	010 388888	TASN@worldonline.it 	14.0898	14.1166	08:00:00	19:00:00
Tiro Al Segno 	50, Via Al Poligono Di Quezzi (Genova) 	010 389100	TAS@tele2.it 	22.7039	40.0484	08:00:00	19:00:00
Virgin Active Genova 	153/R, Via Paolo Mantovani (Sampierdarena) 	800 914555	VAG@atlavia.it 	75.9089	70.7233	08:00:00	19:00:00
A. S. D. Castelletto	2, Via Di San Pantaleo (Genova) 	010 810006	ASDC@alice.it 	4.0128	109.0448	08:00:00	19:00:00
\.


--
-- Data for Name: categories; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.categories (name, regulation, min, max, photo) FROM stdin;
tennis	tennis regulation your honor	1	2	\N
calcio	è bello	7	20	\N
volley	super  bello	5	12	\N
basket	molto bello	2	10	\N
\.


--
-- Data for Name: evaluations; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.evaluations (evaluated, evaluator, evaluatedon, match, score, comment) FROM stdin;
straforiniandrea	tascaandrea	2018-12-03	33	5	\N
straforiniandrea	conteandrea	2018-12-03	33	5	\N
malattoandrea	armaninoaurora	2019-01-05	409177	1	non si lava
campisigaetano	armaninoaurora	2019-01-05	409177	5	bono
contegemma	armaninoaurora	2019-01-05	409177	7	nzomma
storacegaetano	armaninoaurora	2019-01-05	409177	3	falloso
storacegaetano	campisigaetano	2019-01-05	409177	4	dorme in panchina
tavellaandrea	campisigaetano	2019-01-05	409177	8	bravino ino
conteaurora	campisigaetano	2019-01-05	409177	1	mezzora per capire che non si trattava di una parttia di squash
polveriniandrea	campisigaetano	2019-01-05	409177	4	sempre in ritardo
malattomonica	malattoandrea	2019-01-05	409177	10	mi ha rotto un dente
malattoandrea	malattomonica	2019-01-05	409177	10	gli ho rotto un dente
campisigaetano	zazzeraandrea	2019-01-05	409177	5	non capiva quale era la sua squadra
campisigaetano	storacegaetano	2019-01-05	409178	10	si chiama come me
storacegaetano	campisigaetano	2019-01-05	409178	1	si chiama come me
contegemma	campisigaetano	2019-01-05	409178	1	mi ha fatto lo sgmabetto
armaninogaetano	campisigaetano	2019-01-05	409178	7	non ce ne sono tredici in una dozzina
straforiniadriana	simoniadriana	2019-01-07	409178	7	banana ammock
straforiniadriana	simoniadriana	2019-01-07	409181	7	banana ammock
straforiniadriana	sangalettiadriana	2019-01-07	409181	7	banana ammock
straforiniadriana	gentiloniandrea	2019-01-07	409181	7	banana ammock
straforiniadriana	ferrariadriana	2019-01-07	409181	7	banana ammock
straforiniadriana	basileadriana	2019-01-07	409181	7	banana ammock
pianforinialberto	basileadriana	2019-01-07	409181	2	banana ammock
pianforinialberto	straforiniadriana	2019-01-07	409181	2	banana ammock
pianforinialberto	simoniadriana	2019-01-07	409181	2	banana ammock
pianforinialberto	pianforiniandrea	2019-01-07	409181	2	banana ammock
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
squadracalcio1	409181	straforiniandrea
squadracalcio3	409181	straforiniandrea
33_1	33	straforiniandrea
33_2	33	straforiniandrea
squadratorneo3	409175	gardellaandrea
Non sono bello ma patcho	409175	gardellaandrea
squadratorneo3	409176	gardellaandrea
squadratorneo4	409176	gardellaandrea
Team1	409177	gardellaandrea
Non sono bello ma patcho	409177	gardellaandrea
squadratorneo3	409178	gardellaandrea
Non sono bello ma patcho	409178	gardellaandrea
squadratorneo3	409173	gardellaandrea
squadratorneo4	409173	gardellaandrea
Team1	409174	gardellaandrea
Non sono bello ma patcho	409174	gardellaandrea
squadracalcio1	409179	straforiniandrea
squadracalcio2	409179	straforiniandrea
squadracalcio3	409180	straforiniandrea
squadracalcio4	409180	straforiniandrea
\.


--
-- Name: matchcandidatures_match_seq; Type: SEQUENCE SET; Schema: bdproject; Owner: postgres
--

SELECT pg_catalog.setval('bdproject.matchcandidatures_match_seq', 1, false);


--
-- Data for Name: matches; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.matches (id, building, organizedon, insertedon, tournament, mstate, admin, category, phase) FROM stdin;
409173	A.s. Gymnotecnica 	2018-12-23	2018-12-23	torneotest	closed	gardellaandrea	basket	1
409174	A.s. Gymnotecnica 	2018-12-23	2018-12-23	torneotest	closed	gardellaandrea	basket	1
409175	A.s. Gymnotecnica 	2018-12-23	2018-12-23	torneotest	closed	gardellaandrea	basket	0
33	A. S. D. Castelletto	2018-11-30	2018-11-30	\N	closed	straforiniandrea	basket	\N
409179	Cus Genova 	2019-01-05	2019-01-05	torneocalcio	closed	straforiniandrea	calcio	1
409180	Cus Genova 	2019-01-05	2019-01-05	torneocalcio	closed	straforiniandrea	calcio	1
409181	Cus Genova 	2019-01-05	2019-01-05	torneocalcio	closed	straforiniandrea	calcio	0
409176	A.s. Gymnotecnica 	2018-12-24	2018-12-24	torneotest1	closed	gardellaandrea	basket	1
409177	A.s. Gymnotecnica 	2018-12-24	2018-12-24	torneotest1	closed	gardellaandrea	basket	1
409178	A.s. Gymnotecnica 	2018-12-24	2018-12-24	torneotest1	closed	gardellaandrea	basket	0
\.


--
-- Name: matches_id_seq; Type: SEQUENCE SET; Schema: bdproject; Owner: postgres
--

SELECT pg_catalog.setval('bdproject.matches_id_seq', 409181, true);


--
-- Data for Name: outcomes; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.outcomes (match, score, goleador, win, admin, insertedon, duration, team) FROM stdin;
409173	2	tascaaurora tavellaaurora	0	gardellaandrea	2018-12-24	00:20:00	squadratorneo3
409173	1	saperdigaetano	0	gardellaandrea	2018-12-24	00:20:00	squadratorneo4
409174	2	straforiniandrea storacegaetano	0	gardellaandrea	2018-12-24	00:20:00	Non sono bello ma patcho
409174	1	tavellaandrea	0	gardellaandrea	2018-12-24	00:20:00	Team1
409175	2	straforiniandrea storacegaetano	0	gardellaandrea	2018-12-24	00:20:00	Non sono bello ma patcho
409175	1	tascaaurora	0	gardellaandrea	2018-12-24	00:20:00	squadratorneo3
409176	2	tascaaurora tavellaaurora	0	gardellaandrea	2018-12-24	00:20:00	squadratorneo3
409176	1	saperdigaetano	0	gardellaandrea	2018-12-24	00:20:00	squadratorneo4
409177	2	straforiniandrea storacegaetano	0	gardellaandrea	2018-12-24	00:20:00	Non sono bello ma patcho
409177	1	tavellaandrea	0	gardellaandrea	2018-12-24	00:20:00	Team1
409178	2	straforiniandrea storacegaetano	0	gardellaandrea	2018-12-24	00:20:00	Non sono bello ma patcho
409178	1	tascaaurora	0	gardellaandrea	2018-12-24	00:20:00	squadratorneo3
409179	1	pianforinialberto	0	straforiniandrea	2019-01-05	00:20:00	squadracalcio1
409179	0		0	straforiniandrea	2019-01-05	00:20:00	squadracalcio2
409180	1	simoniadriana	0	straforiniandrea	2019-01-05	00:20:00	squadracalcio3
409180	0		0	straforiniandrea	2019-01-05	00:20:00	squadracalcio4
409181	1	pianforinialberto	0	straforiniandrea	2019-01-05	00:20:00	squadracalcio1
409181	0		0	straforiniandrea	2019-01-05	00:20:00	squadracalcio3
33	0	storaceandrea	0	straforiniandrea	2018-12-07	01:00:00	33_1
33	3	storaceandrea	0	straforiniandrea	2018-12-07	01:00:00	33_2
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

COPY bdproject.refereecandidatures (applicant, match, confirmed) FROM stdin;
\.


--
-- Name: refereecandidatures_match_seq; Type: SEQUENCE SET; Schema: bdproject; Owner: postgres
--

SELECT pg_catalog.setval('bdproject.refereecandidatures_match_seq', 1, false);


--
-- Data for Name: studycourses; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.studycourses (coursename) FROM stdin;
informatica
matematica
biologia
lettere
medicina
fisica
chimica
giurisprudenza
Biotecnologie
Chimica e tecnologia farmaceutiche
Chimica e tecnologie chimiche
Conservazione dei beni culturali
Design del prodotto e della nautica
Dietistica
Economia aziendale
Economia e commercio
Farmacia
Filosofia
Fisica
Fisioterapia
Giurisprudenza
Servizi legali all impresa e alla pubblica amministrazione
Igiene dentale
Infermieristica
Infermieristica pediatrica
Informatica
Ingegneria biomedica
Ingegneria chimica e di processo
Ingegneria civile e ambientale
Ingegneria elettrica
Ingegneria elettronica e tecnologie dell informazione
Ingegneria gestionale
Ingegneria informatica
Ingegneria meccanica
Ingegneria nautica
Ingegneria navale
Lettere
Lingue e culture moderne
Logopedia
Matematica
Medicina e chirurgia
Odontoiatria e protesi dentaria
Ortottica ed assistenza oftalmologica
Ostetricia
Podologia
Scienza dei materiali
Scienze ambientali e naturali
Scienze biologiche
Scienze del turismo: impresa, cultura e territorio
Scienze dell architettura
Scienze della comunicazione
Scienze della formazione primaria
Scienze e tecniche psicologiche
Scienze geologiche
Scienze internazionali e diplomatiche
Scienze motorie, sport e salute
Scienze dell educazione e della formazione
Scienze politiche e dell amministrazione
Servizio sociale
Storia
Tecnica della riabilitazione psichiatrica
Tecniche di laboratorio biomedico
Tecniche di radiologia medica, per immagini e radioterapia
Tecniche ortopediche
Teorie e tecniche della mediazione interlinguistica
Terapia della neuro e psicomotricità dell età evolutiva
\.


--
-- Data for Name: teamcandidatures; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.teamcandidatures (team, applicant, admin, role) FROM stdin;
squadratorneo4	contealberto	contealberto	undefined
Non sono bello ma patcho	straforiniandrea	straforiniandrea	ah boh
Non sono bello ma patcho	zazzeraandrea	straforiniandrea	ah boh
Non sono bello ma patcho	conteaurora	straforiniandrea	ah boh
Non sono bello ma patcho	storacegaetano	straforiniandrea	ah boh
Non sono bello ma patcho	contegemma	straforiniandrea	ah boh
Non sono bello ma patcho	malattomonica	straforiniandrea	ah boh
Non sono bello ma patcho	armaninoaurora	straforiniandrea	undefined
squadratorneo4	saperdigaetano	contealberto	undefined
Team1	zolezziandrea	malattoandrea	undefined
Team1	oliveriandrea	malattoandrea	undefined
Team1	malattoandrea	malattoandrea	undefined
Team1	polveriniandrea	malattoandrea	undefined
Team1	stefaniniandrea	malattoandrea	undefined
Team1	tavellaandrea	malattoandrea	undefined
Team1	scipioniandrea	malattoandrea	undefined
squadracalcio1	pianforinialberto	pianforinialberto	player
Non sono bello ma patcho	armaninogaetano	straforiniandrea	undefined
Non sono bello ma patcho	campisigaetano	straforiniandrea	undefined
squadra1	straforiniandrea	\N	role1
squadra1	simoniandrea	\N	role1
squadra1	campisiandrea	\N	role1
squadra1	basileandrea	\N	role1
squadra1	tascaandrea	\N	role1
squadra1	gardellaandrea	\N	role1
squadra2	scipioniandrea	\N	role1
squadracalcio1	gardellaandrea	pianforinialberto	player
squadracalcio1	pianforiniandrea	pianforinialberto	player
squadracalcio1	mattarellaandrea	pianforinialberto	player
squadra2	pannellaandrea	\N	role1
squadra2	ferrariandrea	\N	role1
squadracalcio1	gentiloniandrea	pianforinialberto	player
squadracalcio1	napolitanoandrea	pianforinialberto	player
squadracalcio1	straforiniadriana	pianforinialberto	player
squadracalcio2	tavellaalberto	tavellaalberto	player
squadracalcio2	zazzeraadriana	tavellaalberto	player
squadracalcio2	storaceadriana	tavellaalberto	player
squadracalcio2	armaninoadriana	tavellaalberto	player
squadracalcio2	campisiadriana	tavellaalberto	player
squadracalcio2	scipioniadriana	tavellaalberto	player
squadracalcio2	scottiadriana	tavellaalberto	player
squadracalcio3	mattarellaalberto	mattarellaalberto	player
squadracalcio3	simoniadriana	mattarellaalberto	player
squadracalcio3	basileadriana	mattarellaalberto	player
squadracalcio3	saperdiadriana	mattarellaalberto	player
squadracalcio3	sangalettiadriana	mattarellaalberto	player
squadracalcio3	paganiadriana	mattarellaalberto	player
squadracalcio3	ferrariadriana	mattarellaalberto	player
squadracalcio4	napolitanoalberto	napolitanoalberto	player
squadracalcio4	pannellaadriana	napolitanoalberto	player
squadracalcio4	tascaadriana	napolitanoalberto	player
squadracalcio4	gardellaadriana	napolitanoalberto	player
squadracalcio4	zolezziadriana	napolitanoalberto	player
squadracalcio4	oliveriadriana	napolitanoalberto	player
squadracalcio4	malattoadriana	napolitanoalberto	player
squadra2	scottiandrea	\N	role1
squadra2	storaceandrea	\N	role1
squadra2	paganiandrea	\N	role1
squadratorneo3	tascaaurora	tascaaurora	undefined
squadratorneo3	tavellaaurora	tascaaurora	undefined
33_1	straforiniandrea	straforiniandrea	player
33_1	conteandrea	straforiniandrea	player
33_1	zazzeraandrea	straforiniandrea	player
33_1	storaceandrea	straforiniandrea	player
33_1	armaninoandrea	straforiniandrea	player
33_1	campisiandrea	straforiniandrea	player
33_1	scipioniandrea	straforiniandrea	player
33_1	scottiandrea	straforiniandrea	player
33_1	simoniandrea	straforiniandrea	player
33_2	basileandrea	straforiniandrea	player
33_2	saperdiandrea	straforiniandrea	player
33_2	sangalettiandrea	straforiniandrea	player
33_2	paganiandrea	straforiniandrea	player
33_2	ferrariandrea	straforiniandrea	player
33_2	pannellaandrea	straforiniandrea	player
33_2	tascaandrea	straforiniandrea	player
\.


--
-- Data for Name: teams; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.teams (name, coloremaglia, category, description, notes, admin, state) FROM stdin;
Team1	\N	basket	\N	\N	malattoandrea	closed
Non sono bello ma patcho	\N	basket	ci mettiamo impegno	\N	straforiniandrea	closed
squadra2	rosso	tennis	team2desc	team2notes	armaninoandrea	open
33_1	\N	basket	\N	\N	straforiniandrea	open
33_2	\N	basket	\N	\N	straforiniandrea	open
squadra1	blu	tennis	team1desc	team1notes	zazzeraandrea	open
squadratorneo3	\N	basket	torneoprova	ciaozio3	tascaaurora	open
squadratorneo4	\N	basket	torneoprova	ciaozio4	contealberto	open
squadracalcio1	\N	calcio	una bella squadra	ciao	pianforinialberto	open
squadracalcio2	\N	calcio	una bella squadra	ciao	tavellaalberto	open
squadracalcio3	\N	calcio	una bella squadra	ciao	mattarellaalberto	open
squadracalcio4	\N	calcio	una bella squadra	ciao	napolitanoalberto	open
\.


--
-- Data for Name: tournaments; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.tournaments (name, ttype, manager, teamsnumber, state, category, winner, building) FROM stdin;
torneotest1	eliminazione diretta	gardellaandrea	6	closed	basket	Non sono bello ma patcho	A.s. Gymnotecnica 
torneotest	eliminazione diretta	gardellaandrea	4	closed	basket	Non sono bello ma patcho	A.s. Gymnotecnica 
torneocalcio	eliminazione diretta	straforiniandrea	4	closed	calcio	squadracalcio1	Cus Genova 
\.


--
-- Data for Name: tournamentscandidatures; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.tournamentscandidatures (team, tournament, confirmed) FROM stdin;
squadratorneo4	torneotest1	gardellaandrea
Team1	torneotest1	gardellaandrea
Non sono bello ma patcho	torneotest1	gardellaandrea
squadratorneo3	torneotest	gardellaandrea
squadratorneo4	torneotest	gardellaandrea
Team1	torneotest	gardellaandrea
Non sono bello ma patcho	torneotest	gardellaandrea
squadracalcio1	torneocalcio	straforiniandrea
squadracalcio2	torneocalcio	straforiniandrea
squadracalcio3	torneocalcio	straforiniandrea
squadracalcio4	torneocalcio	straforiniandrea
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: bdproject; Owner: postgres
--

COPY bdproject.users (username, password, name, surname, birthdate, birthplace, photo, regnumber, uprivilege, studycourse, tennismatch, volleymatch, soccermatch, phonenumber, basketmatch, gender) FROM stdin;
polveriniadriana	5197	adriana	polverini	1995-07-20	Milano	\N	1046	base	lettere	0	0	0	\N	0	non definito
pianforiniadriana	5815	adriana	pianforini	1993-02-08	Bogliasco	\N	1047	premium	medicina	0	0	0	\N	0	non definito
stefaniniadriana	1882	adriana	stefanini	1990-10-20	Roma	\N	1048	base	giurisprudenza	0	0	0	\N	0	non definito
tavellaadriana	3949	adriana	tavella	1995-03-12	Roma	\N	1049	premium	chimica	0	0	0	\N	0	non definito
conteadriana	9424	adriana	conte	1991-05-13	Milano	\N	1050	base	medicina	0	0	0	\N	0	non definito
mattarellaadriana	1815	adriana	mattarella	1996-11-05	Roma	\N	1051	premium	lettere	0	0	0	\N	0	non definito
gentiloniadriana	80	adriana	gentiloni	1992-03-02	Bogliasco	\N	1052	base	fisica	0	0	0	\N	0	non definito
napolitanoadriana	7832	adriana	napolitano	1990-06-10	Roma	\N	1053	premium	lettere	0	0	0	\N	0	non definito
straforiniadamo	3409	adamo	straforini	1991-08-21	Bogliasco	\N	1054	base	fisica	0	0	0	\N	0	non definito
zazzeraadamo	6671	adamo	zazzera	1991-01-10	SestriCapitale	\N	1055	premium	biologia	0	0	0	\N	0	non definito
storaceadamo	8623	adamo	storace	1994-02-25	Roma	\N	1056	base	fisica	0	0	0	\N	0	non definito
armaninoadamo	673	adamo	armanino	1991-12-04	Roma	\N	1057	premium	biologia	0	0	0	\N	0	non definito
campisiadamo	5098	adamo	campisi	1991-02-20	Roma	\N	1058	base	giurisprudenza	0	0	0	\N	0	non definito
scipioniadamo	5548	adamo	scipioni	1994-10-11	Bogliasco	\N	1059	premium	chimica	0	0	0	\N	0	non definito
scottiadamo	4310	adamo	scotti	1994-08-11	SestriCapitale	\N	1060	base	lettere	0	0	0	\N	0	non definito
simoniadamo	5827	adamo	simoni	1994-09-06	Bogliasco	\N	1061	premium	medicina	0	0	0	\N	0	non definito
basileadamo	9410	adamo	basile	1995-11-13	Milano	\N	1062	base	matematica	0	0	0	\N	0	non definito
saperdiadamo	3193	adamo	saperdi	1994-07-21	SestriCapitale	\N	1063	premium	chimica	0	0	0	\N	0	non definito
sangalettiadamo	8079	adamo	sangaletti	1991-02-22	SestriCapitale	\N	1064	base	medicina	0	0	0	\N	0	non definito
polveriniandrea	6843	andrea	polverini	1991-03-21	Roma	\N	1019	premium	giurisprudenza	0	0	0	\N	11	non definito
stefaniniandrea	1730	andrea	stefanini	1990-11-18	SestriCapitale	\N	1021	premium	fisica	0	0	0	\N	11	non definito
tavellaandrea	2670	andrea	tavella	1995-09-03	Milano	\N	1022	base	medicina	0	0	0	\N	11	non definito
zolezziandrea	7903	andrea	zolezzi	1993-02-04	SestriCapitale	\N	1016	base	matematica	0	0	0	\N	11	non definito
oliveriandrea	8029	andrea	oliveri	1992-04-19	Bogliasco	\N	1017	premium	matematica	0	0	0	\N	11	non definito
malattoandrea	8785	andrea	malatto	1991-08-15	Bogliasco	\N	1018	base	medicina	0	0	0	\N	11	non definito
gardellaandrea	8863	andrea	gardella	1990-07-06	Roma	\N	1015	premium	chimica	0	0	4	\N	0	non definito
pianforiniandrea	9527	andrea	pianforini	1990-11-09	Roma	\N	1020	base	lettere	0	0	4	\N	0	non definito
mattarellaandrea	2539	andrea	mattarella	1994-02-17	Roma	\N	1024	base	lettere	0	0	4	\N	0	non definito
gentiloniandrea	1636	andrea	gentiloni	1990-09-18	SestriCapitale	\N	1025	premium	matematica	0	0	4	\N	0	non definito
napolitanoandrea	9521	andrea	napolitano	1992-02-10	SestriCapitale	\N	1026	base	biologia	0	0	4	\N	0	non definito
straforiniadriana	9535	adriana	straforini	1995-10-02	Bogliasco	\N	1027	premium	medicina	0	0	4	\N	0	non definito
zazzeraadriana	5483	adriana	zazzera	1991-05-06	Milano	\N	1028	base	matematica	0	0	2	\N	0	non definito
storaceadriana	3632	adriana	storace	1991-02-02	SestriCapitale	\N	1029	premium	fisica	0	0	2	\N	0	non definito
armaninoadriana	6735	adriana	armanino	1993-07-02	SestriCapitale	\N	1030	base	lettere	0	0	2	\N	0	non definito
campisiadriana	3586	adriana	campisi	1995-12-17	Bogliasco	\N	1031	premium	lettere	0	0	2	\N	0	non definito
scipioniadriana	5091	adriana	scipioni	1992-02-17	SestriCapitale	\N	1032	base	biologia	0	0	2	\N	0	non definito
scottiadriana	3982	adriana	scotti	1996-07-02	Roma	\N	1033	premium	lettere	0	0	2	\N	0	non definito
simoniadriana	6055	adriana	simoni	1993-08-14	SestriCapitale	\N	1034	base	giurisprudenza	0	0	4	\N	0	non definito
basileadriana	2897	adriana	basile	1991-05-04	Roma	\N	1035	premium	giurisprudenza	0	0	4	\N	0	non definito
saperdiadriana	8311	adriana	saperdi	1993-02-20	SestriCapitale	\N	1036	base	fisica	0	0	4	\N	0	non definito
sangalettiadriana	1135	adriana	sangaletti	1995-09-17	Milano	\N	1037	premium	lettere	0	0	4	\N	0	non definito
paganiadriana	5891	adriana	pagani	1991-07-03	Roma	\N	1038	base	giurisprudenza	0	0	4	\N	0	non definito
ferrariadriana	6842	adriana	ferrari	1995-09-23	Bogliasco	\N	1039	premium	fisica	0	0	4	\N	0	non definito
pannellaadriana	1556	adriana	pannella	1993-11-06	Milano	\N	1040	base	matematica	0	0	2	\N	0	non definito
tascaadriana	2476	adriana	tasca	1992-03-18	SestriCapitale	\N	1041	premium	lettere	0	0	2	\N	0	non definito
gardellaadriana	4102	adriana	gardella	1990-05-09	Roma	\N	1042	base	giurisprudenza	0	0	2	\N	0	non definito
zolezziadriana	7126	adriana	zolezzi	1992-02-09	Bogliasco	\N	1043	premium	matematica	0	0	2	\N	0	non definito
oliveriadriana	6565	adriana	oliveri	1990-12-16	Roma	\N	1044	base	lettere	0	0	2	\N	0	non definito
malattoadriana	5916	adriana	malatto	1993-10-04	Milano	\N	1045	premium	lettere	0	0	2	\N	0	non definito
paganiadamo	518	adamo	pagani	1992-09-05	Roma	\N	1065	premium	giurisprudenza	0	0	0	\N	0	non definito
ferrariadamo	8791	adamo	ferrari	1995-01-05	Bogliasco	\N	1066	base	lettere	0	0	0	\N	0	non definito
pannellaadamo	3851	adamo	pannella	1994-06-09	SestriCapitale	\N	1067	premium	fisica	0	0	0	\N	0	non definito
tascaadamo	4608	adamo	tasca	1993-04-24	SestriCapitale	\N	1068	base	medicina	0	0	0	\N	0	non definito
gardellaadamo	8843	adamo	gardella	1995-12-10	Bogliasco	\N	1069	premium	medicina	0	0	0	\N	0	non definito
zolezziadamo	9076	adamo	zolezzi	1992-04-13	Bogliasco	\N	1070	base	giurisprudenza	0	0	0	\N	0	non definito
oliveriadamo	3887	adamo	oliveri	1991-04-14	Bogliasco	\N	1071	premium	biologia	0	0	0	\N	0	non definito
malattoadamo	2150	adamo	malatto	1996-07-23	Roma	\N	1072	base	giurisprudenza	0	0	0	\N	0	non definito
polveriniadamo	7020	adamo	polverini	1996-09-12	Milano	\N	1073	premium	chimica	0	0	0	\N	0	non definito
pianforiniadamo	2859	adamo	pianforini	1995-05-07	Bogliasco	\N	1074	base	fisica	0	0	0	\N	0	non definito
stefaniniadamo	397	adamo	stefanini	1995-03-18	SestriCapitale	\N	1075	premium	fisica	0	0	0	\N	0	non definito
tavellaadamo	6250	adamo	tavella	1990-09-03	Bogliasco	\N	1076	base	chimica	0	0	0	\N	0	non definito
conteadamo	1279	adamo	conte	1991-05-03	Bogliasco	\N	1077	premium	matematica	0	0	0	\N	0	non definito
mattarellaadamo	2010	adamo	mattarella	1991-01-16	Roma	\N	1078	base	matematica	0	0	0	\N	0	non definito
gentiloniadamo	5910	adamo	gentiloni	1995-12-16	Milano	\N	1079	premium	giurisprudenza	0	0	0	\N	0	non definito
napolitanoadamo	9503	adamo	napolitano	1996-07-13	Milano	\N	1080	base	fisica	0	0	0	\N	0	non definito
straforinialberto	9155	alberto	straforini	1995-11-05	Roma	\N	1081	premium	lettere	0	0	0	\N	0	non definito
zazzeraalberto	3033	alberto	zazzera	1994-01-25	Milano	\N	1082	base	giurisprudenza	0	0	0	\N	0	non definito
storacealberto	6696	alberto	storace	1995-05-10	Roma	\N	1083	premium	giurisprudenza	0	0	0	\N	0	non definito
armaninoalberto	385	alberto	armanino	1995-05-21	Bogliasco	\N	1084	base	giurisprudenza	0	0	0	\N	0	non definito
campisialberto	5745	alberto	campisi	1996-10-07	SestriCapitale	\N	1085	premium	chimica	0	0	0	\N	0	non definito
scipionialberto	1848	alberto	scipioni	1991-06-06	SestriCapitale	\N	1086	base	fisica	0	0	0	\N	0	non definito
scottialberto	6615	alberto	scotti	1993-07-16	Milano	\N	1087	premium	giurisprudenza	0	0	0	\N	0	non definito
simonialberto	5302	alberto	simoni	1994-07-21	Bogliasco	\N	1088	base	fisica	0	0	0	\N	0	non definito
basilealberto	8155	alberto	basile	1990-04-21	SestriCapitale	\N	1089	premium	chimica	0	0	0	\N	0	non definito
saperdialberto	4100	alberto	saperdi	1993-06-21	Bogliasco	\N	1090	base	medicina	0	0	0	\N	0	non definito
sangalettialberto	532	alberto	sangaletti	1995-04-15	Bogliasco	\N	1091	premium	medicina	0	0	0	\N	0	non definito
paganialberto	8111	alberto	pagani	1991-04-08	Milano	\N	1092	base	chimica	0	0	0	\N	0	non definito
ferrarialberto	6767	alberto	ferrari	1992-08-18	Milano	\N	1093	premium	lettere	0	0	0	\N	0	non definito
pannellaalberto	1649	alberto	pannella	1991-08-25	Roma	\N	1094	base	fisica	0	0	0	\N	0	non definito
tascaalberto	8441	alberto	tasca	1992-04-10	Roma	\N	1095	premium	chimica	0	0	0	\N	0	non definito
gardellaalberto	7078	alberto	gardella	1993-01-19	SestriCapitale	\N	1096	base	medicina	0	0	0	\N	0	non definito
zolezzialberto	1491	alberto	zolezzi	1992-07-05	Milano	\N	1097	premium	fisica	0	0	0	\N	0	non definito
oliverialberto	176	alberto	oliveri	1994-02-01	Milano	\N	1098	base	fisica	0	0	0	\N	0	non definito
malattoalberto	4665	alberto	malatto	1996-02-20	Milano	\N	1099	premium	matematica	0	0	0	\N	0	non definito
polverinialberto	7295	alberto	polverini	1996-01-02	Roma	\N	1100	base	fisica	0	0	0	\N	0	non definito
stefaninialberto	5994	alberto	stefanini	1993-12-25	SestriCapitale	\N	1102	base	lettere	0	0	0	\N	0	non definito
gentilonialberto	4257	alberto	gentiloni	1990-12-18	Milano	\N	1106	base	matematica	0	0	0	\N	0	non definito
straforiniaurora	8031	aurora	straforini	1993-04-05	Bogliasco	\N	1108	base	lettere	0	0	0	\N	0	non definito
zazzeraaurora	5276	aurora	zazzera	1991-05-19	Roma	\N	1109	premium	giurisprudenza	0	0	0	\N	0	non definito
storaceaurora	5956	aurora	storace	1992-03-07	SestriCapitale	\N	1110	base	chimica	0	0	0	\N	0	non definito
campisiaurora	783	aurora	campisi	1990-03-05	Milano	\N	1112	base	medicina	0	0	0	\N	0	non definito
scipioniaurora	6175	aurora	scipioni	1996-04-11	Roma	\N	1113	premium	lettere	0	0	0	\N	0	non definito
scottiaurora	2010	aurora	scotti	1995-02-07	SestriCapitale	\N	1114	base	giurisprudenza	0	0	0	\N	0	non definito
simoniaurora	6988	aurora	simoni	1995-07-04	Roma	\N	1115	premium	giurisprudenza	0	0	0	\N	0	non definito
basileaurora	5992	aurora	basile	1994-12-20	SestriCapitale	\N	1116	base	fisica	0	0	0	\N	0	non definito
saperdiaurora	4155	aurora	saperdi	1991-07-22	Bogliasco	\N	1117	premium	fisica	0	0	0	\N	0	non definito
sangalettiaurora	3108	aurora	sangaletti	1991-12-18	Roma	\N	1118	base	matematica	0	0	0	\N	0	non definito
paganiaurora	5279	aurora	pagani	1991-04-14	Milano	\N	1119	premium	lettere	0	0	0	\N	0	non definito
ferrariaurora	671	aurora	ferrari	1995-01-08	SestriCapitale	\N	1120	base	chimica	0	0	0	\N	0	non definito
pannellaaurora	467	aurora	pannella	1993-01-02	Milano	\N	1121	premium	giurisprudenza	0	0	0	\N	0	non definito
gardellaaurora	7288	aurora	gardella	1996-09-20	Bogliasco	\N	1123	premium	chimica	0	0	0	\N	0	non definito
zolezziaurora	6582	aurora	zolezzi	1996-01-19	Roma	\N	1124	base	matematica	0	0	0	\N	0	non definito
oliveriaurora	6964	aurora	oliveri	1990-12-13	Roma	\N	1125	premium	fisica	0	0	0	\N	0	non definito
malattoaurora	9725	aurora	malatto	1990-03-11	Milano	\N	1126	base	fisica	0	0	0	\N	0	non definito
polveriniaurora	3488	aurora	polverini	1994-08-22	Roma	\N	1127	premium	biologia	0	0	0	\N	0	non definito
pianforiniaurora	6647	aurora	pianforini	1995-01-10	Roma	\N	1128	base	fisica	0	0	0	\N	0	non definito
stefaniniaurora	5893	aurora	stefanini	1990-06-15	Bogliasco	\N	1129	premium	matematica	0	0	0	\N	0	non definito
armaninoaurora	5038	aurora	armanino	1990-05-14	Roma	\N	1111	premium	biologia	0	0	0	\N	15	non definito
pianforinialberto	2744	alberto	pianforini	1990-01-08	Roma	\N	1101	premium	medicina	0	0	4	\N	0	non definito
tavellaalberto	3155	alberto	tavella	1995-10-04	SestriCapitale	\N	1103	premium	fisica	0	0	2	\N	0	non definito
mattarellaalberto	7641	alberto	mattarella	1995-11-08	SestriCapitale	\N	1105	premium	medicina	0	0	4	\N	0	non definito
napolitanoalberto	2719	alberto	napolitano	1994-07-23	SestriCapitale	\N	1107	premium	matematica	0	0	2	\N	0	non definito
mattarellaaurora	2150	aurora	mattarella	1995-03-09	Milano	\N	1132	base	matematica	0	0	0	\N	0	non definito
gentiloniaurora	2583	aurora	gentiloni	1995-06-09	Bogliasco	\N	1133	premium	biologia	0	0	0	\N	0	non definito
napolitanoaurora	3860	aurora	napolitano	1993-04-10	Bogliasco	\N	1134	base	fisica	0	0	0	\N	0	non definito
straforinigaetano	6055	gaetano	straforini	1992-02-05	Roma	\N	1135	premium	matematica	0	0	0	\N	0	non definito
zazzeragaetano	3073	gaetano	zazzera	1995-12-12	Bogliasco	\N	1136	base	matematica	0	0	0	\N	0	non definito
scipionigaetano	3330	gaetano	scipioni	1994-12-20	Roma	\N	1140	base	medicina	0	0	0	\N	0	non definito
scottigaetano	7603	gaetano	scotti	1995-01-02	Milano	\N	1141	premium	fisica	0	0	0	\N	0	non definito
simonigaetano	3946	gaetano	simoni	1991-09-06	SestriCapitale	\N	1142	base	biologia	0	0	0	\N	0	non definito
basilegaetano	9789	gaetano	basile	1990-04-15	SestriCapitale	\N	1143	premium	matematica	0	0	0	\N	0	non definito
sangalettigaetano	320	gaetano	sangaletti	1996-05-11	Milano	\N	1145	premium	medicina	0	0	0	\N	0	non definito
paganigaetano	339	gaetano	pagani	1994-02-11	SestriCapitale	\N	1146	base	fisica	0	0	0	\N	0	non definito
ferrarigaetano	7811	gaetano	ferrari	1991-06-02	Bogliasco	\N	1147	premium	biologia	0	0	0	\N	0	non definito
pannellagaetano	1893	gaetano	pannella	1993-05-06	Roma	\N	1148	base	lettere	0	0	0	\N	0	non definito
tascagaetano	2999	gaetano	tasca	1990-04-18	Bogliasco	\N	1149	premium	chimica	0	0	0	\N	0	non definito
gardellagaetano	3300	gaetano	gardella	1995-10-19	Bogliasco	\N	1150	base	matematica	0	0	0	\N	0	non definito
zolezzigaetano	9687	gaetano	zolezzi	1996-08-06	Roma	\N	1151	premium	matematica	0	0	0	\N	0	non definito
oliverigaetano	6428	gaetano	oliveri	1992-06-16	Roma	\N	1152	base	matematica	0	0	0	\N	0	non definito
malattogaetano	6841	gaetano	malatto	1990-06-11	Milano	\N	1153	premium	fisica	0	0	0	\N	0	non definito
polverinigaetano	5625	gaetano	polverini	1994-04-24	Bogliasco	\N	1154	base	giurisprudenza	0	0	0	\N	0	non definito
pianforinigaetano	9992	gaetano	pianforini	1996-08-08	SestriCapitale	\N	1155	premium	chimica	0	0	0	\N	0	non definito
stefaninigaetano	3901	gaetano	stefanini	1994-05-18	Roma	\N	1156	base	medicina	0	0	0	\N	0	non definito
tavellagaetano	2019	gaetano	tavella	1990-04-07	SestriCapitale	\N	1157	premium	giurisprudenza	0	0	0	\N	0	non definito
contegaetano	998	gaetano	conte	1990-07-03	SestriCapitale	\N	1158	base	lettere	0	0	0	\N	0	non definito
mattarellagaetano	8511	gaetano	mattarella	1995-02-04	SestriCapitale	\N	1159	premium	matematica	0	0	0	\N	0	non definito
gentilonigaetano	547	gaetano	gentiloni	1994-06-06	SestriCapitale	\N	1160	base	biologia	0	0	0	\N	0	non definito
napolitanogaetano	4157	gaetano	napolitano	1995-05-23	SestriCapitale	\N	1161	premium	fisica	0	0	0	\N	0	non definito
straforinigemma	2091	gemma	straforini	1993-05-20	Bogliasco	\N	1162	base	biologia	0	0	0	\N	0	non definito
zazzeragemma	209	gemma	zazzera	1996-09-08	Bogliasco	\N	1163	premium	biologia	0	0	0	\N	0	non definito
storacegemma	2099	gemma	storace	1993-10-10	Milano	\N	1164	base	medicina	0	0	0	\N	0	non definito
armaninogemma	8327	gemma	armanino	1992-03-17	Bogliasco	\N	1165	premium	matematica	0	0	0	\N	0	non definito
campisigemma	1442	gemma	campisi	1993-11-06	Milano	\N	1166	base	medicina	0	0	0	\N	0	non definito
scipionigemma	9531	gemma	scipioni	1995-06-11	SestriCapitale	\N	1167	premium	biologia	0	0	0	\N	0	non definito
scottigemma	5227	gemma	scotti	1991-05-15	Bogliasco	\N	1168	base	matematica	0	0	0	\N	0	non definito
simonigemma	1901	gemma	simoni	1996-01-03	Roma	\N	1169	premium	lettere	0	0	0	\N	0	non definito
basilegemma	3806	gemma	basile	1995-10-08	SestriCapitale	\N	1170	base	chimica	0	0	0	\N	0	non definito
saperdigemma	4134	gemma	saperdi	1995-06-17	SestriCapitale	\N	1171	premium	biologia	0	0	0	\N	0	non definito
sangalettigemma	9955	gemma	sangaletti	1993-06-06	Roma	\N	1172	base	chimica	0	0	0	\N	0	non definito
paganigemma	1779	gemma	pagani	1991-02-13	Milano	\N	1173	premium	chimica	0	0	0	\N	0	non definito
ferrarigemma	3389	gemma	ferrari	1994-06-10	Milano	\N	1174	base	lettere	0	0	0	\N	0	non definito
pannellagemma	1251	gemma	pannella	1992-06-18	Bogliasco	\N	1175	premium	chimica	0	0	0	\N	0	non definito
tascagemma	6367	gemma	tasca	1990-06-01	Roma	\N	1176	base	matematica	0	0	0	\N	0	non definito
gardellagemma	9351	gemma	gardella	1996-10-21	SestriCapitale	\N	1177	premium	medicina	0	0	0	\N	0	non definito
zolezzigemma	3622	gemma	zolezzi	1991-05-02	Bogliasco	\N	1178	base	fisica	0	0	0	\N	0	non definito
oliverigemma	1103	gemma	oliveri	1992-05-18	Milano	\N	1179	premium	lettere	0	0	0	\N	0	non definito
malattogemma	7402	gemma	malatto	1994-07-02	SestriCapitale	\N	1180	base	lettere	0	0	0	\N	0	non definito
polverinigemma	5524	gemma	polverini	1994-06-10	SestriCapitale	\N	1181	premium	giurisprudenza	0	0	0	\N	0	non definito
pianforinigemma	7402	gemma	pianforini	1995-11-09	Roma	\N	1182	base	biologia	0	0	0	\N	0	non definito
stefaninigemma	1647	gemma	stefanini	1994-07-15	Roma	\N	1183	premium	biologia	0	0	0	\N	0	non definito
tavellagemma	5242	gemma	tavella	1991-12-11	SestriCapitale	\N	1184	base	matematica	0	0	0	\N	0	non definito
mattarellagemma	4772	gemma	mattarella	1992-06-06	SestriCapitale	\N	1186	base	chimica	0	0	0	\N	0	non definito
gentilonigemma	5507	gemma	gentiloni	1995-06-19	Milano	\N	1187	premium	fisica	0	0	0	\N	0	non definito
napolitanogemma	2241	gemma	napolitano	1993-05-02	SestriCapitale	\N	1188	base	giurisprudenza	0	0	0	\N	0	non definito
straforinigelsomina	6092	gelsomina	straforini	1994-05-22	SestriCapitale	\N	1189	premium	giurisprudenza	0	0	0	\N	0	non definito
zazzeragelsomina	2315	gelsomina	zazzera	1995-10-23	SestriCapitale	\N	1190	base	chimica	0	0	0	\N	0	non definito
storacegelsomina	773	gelsomina	storace	1996-11-08	Roma	\N	1191	premium	biologia	0	0	0	\N	0	non definito
armaninogelsomina	4233	gelsomina	armanino	1995-10-12	Bogliasco	\N	1192	base	chimica	0	0	0	\N	0	non definito
campisigelsomina	2395	gelsomina	campisi	1993-01-25	Roma	\N	1193	premium	matematica	0	0	0	\N	0	non definito
scipionigelsomina	9294	gelsomina	scipioni	1995-09-03	Bogliasco	\N	1194	base	chimica	0	0	0	\N	0	non definito
scottigelsomina	8810	gelsomina	scotti	1994-05-20	Roma	\N	1195	premium	matematica	0	0	0	\N	0	non definito
conteaurora	795	aurora	conte	1995-04-10	Roma	\N	1131	premium	fisica	0	0	0	\N	15	non definito
simonigelsomina	3846	gelsomina	simoni	1991-04-11	Roma	\N	1196	base	fisica	0	0	0	\N	0	non definito
basilegelsomina	3162	gelsomina	basile	1995-06-06	Bogliasco	\N	1197	premium	fisica	0	0	0	\N	0	non definito
saperdigelsomina	5158	gelsomina	saperdi	1995-06-07	Roma	\N	1198	base	biologia	0	0	0	\N	0	non definito
sangalettigelsomina	1246	gelsomina	sangaletti	1992-03-01	Milano	\N	1199	premium	lettere	0	0	0	\N	0	non definito
paganigelsomina	4663	gelsomina	pagani	1994-12-22	Roma	\N	1200	base	matematica	0	0	0	\N	0	non definito
ferrarigelsomina	1331	gelsomina	ferrari	1996-05-21	SestriCapitale	\N	1201	premium	chimica	0	0	0	\N	0	non definito
pannellagelsomina	2278	gelsomina	pannella	1993-04-18	SestriCapitale	\N	1202	base	chimica	0	0	0	\N	0	non definito
tascagelsomina	9099	gelsomina	tasca	1991-01-18	Roma	\N	1203	premium	lettere	0	0	0	\N	0	non definito
gardellagelsomina	3027	gelsomina	gardella	1993-10-23	SestriCapitale	\N	1204	base	matematica	0	0	0	\N	0	non definito
zolezzigelsomina	5084	gelsomina	zolezzi	1992-11-20	Roma	\N	1205	premium	chimica	0	0	0	\N	0	non definito
oliverigelsomina	2461	gelsomina	oliveri	1992-03-15	SestriCapitale	\N	1206	base	lettere	0	0	0	\N	0	non definito
malattogelsomina	3361	gelsomina	malatto	1994-02-07	Roma	\N	1207	premium	biologia	0	0	0	\N	0	non definito
polverinigelsomina	1694	gelsomina	polverini	1991-10-16	SestriCapitale	\N	1208	base	biologia	0	0	0	\N	0	non definito
pianforinigelsomina	2164	gelsomina	pianforini	1994-01-15	SestriCapitale	\N	1209	premium	medicina	0	0	0	\N	0	non definito
stefaninigelsomina	2720	gelsomina	stefanini	1994-08-19	SestriCapitale	\N	1210	base	giurisprudenza	0	0	0	\N	0	non definito
tavellagelsomina	2910	gelsomina	tavella	1993-06-22	Roma	\N	1211	premium	giurisprudenza	0	0	0	\N	0	non definito
contegelsomina	5588	gelsomina	conte	1994-11-09	Milano	\N	1212	base	biologia	0	0	0	\N	0	non definito
mattarellagelsomina	9507	gelsomina	mattarella	1993-05-09	SestriCapitale	\N	1213	premium	lettere	0	0	0	\N	0	non definito
gentilonigelsomina	7347	gelsomina	gentiloni	1996-04-11	Bogliasco	\N	1214	base	chimica	0	0	0	\N	0	non definito
napolitanogelsomina	6438	gelsomina	napolitano	1995-08-17	Roma	\N	1215	premium	giurisprudenza	0	0	0	\N	0	non definito
straforinidavide	4588	davide	straforini	1994-07-17	Roma	\N	1216	base	medicina	0	0	0	\N	0	non definito
zazzeradavide	7325	davide	zazzera	1992-06-15	Milano	\N	1217	premium	chimica	0	0	0	\N	0	non definito
storacedavide	7904	davide	storace	1996-12-08	Bogliasco	\N	1218	base	medicina	0	0	0	\N	0	non definito
armaninodavide	8314	davide	armanino	1995-03-17	Milano	\N	1219	premium	matematica	0	0	0	\N	0	non definito
campisidavide	8917	davide	campisi	1992-04-25	Bogliasco	\N	1220	base	medicina	0	0	0	\N	0	non definito
scipionidavide	879	davide	scipioni	1993-07-20	Roma	\N	1221	premium	chimica	0	0	0	\N	0	non definito
scottidavide	3917	davide	scotti	1992-01-24	SestriCapitale	\N	1222	base	lettere	0	0	0	\N	0	non definito
simonidavide	1203	davide	simoni	1991-07-22	SestriCapitale	\N	1223	premium	lettere	0	0	0	\N	0	non definito
basiledavide	842	davide	basile	1992-07-10	SestriCapitale	\N	1224	base	giurisprudenza	0	0	0	\N	0	non definito
saperdidavide	126	davide	saperdi	1996-09-09	SestriCapitale	\N	1225	premium	lettere	0	0	0	\N	0	non definito
sangalettidavide	4841	davide	sangaletti	1992-12-20	Roma	\N	1226	base	biologia	0	0	0	\N	0	non definito
paganidavide	5014	davide	pagani	1995-03-15	Milano	\N	1227	premium	giurisprudenza	0	0	0	\N	0	non definito
ferraridavide	9184	davide	ferrari	1991-11-21	Roma	\N	1228	base	biologia	0	0	0	\N	0	non definito
pannelladavide	222	davide	pannella	1991-09-09	Roma	\N	1229	premium	biologia	0	0	0	\N	0	non definito
tascadavide	6206	davide	tasca	1994-01-11	Roma	\N	1230	base	biologia	0	0	0	\N	0	non definito
gardelladavide	5681	davide	gardella	1993-12-07	Roma	\N	1231	premium	chimica	0	0	0	\N	0	non definito
zolezzidavide	9893	davide	zolezzi	1992-08-16	Milano	\N	1232	base	lettere	0	0	0	\N	0	non definito
oliveridavide	3079	davide	oliveri	1996-02-06	Milano	\N	1233	premium	chimica	0	0	0	\N	0	non definito
malattodavide	3199	davide	malatto	1994-06-14	Bogliasco	\N	1234	base	biologia	0	0	0	\N	0	non definito
polverinidavide	2011	davide	polverini	1996-11-19	Roma	\N	1235	premium	medicina	0	0	0	\N	0	non definito
pianforinidavide	7506	davide	pianforini	1994-03-11	Bogliasco	\N	1236	base	giurisprudenza	0	0	0	\N	0	non definito
stefaninidavide	4688	davide	stefanini	1992-05-09	Bogliasco	\N	1237	premium	chimica	0	0	0	\N	0	non definito
tavelladavide	6697	davide	tavella	1994-04-01	SestriCapitale	\N	1238	base	lettere	0	0	0	\N	0	non definito
contedavide	407	davide	conte	1995-01-14	SestriCapitale	\N	1239	premium	fisica	0	0	0	\N	0	non definito
mattarelladavide	7529	davide	mattarella	1993-04-14	Milano	\N	1240	base	giurisprudenza	0	0	0	\N	0	non definito
gentilonidavide	7446	davide	gentiloni	1995-03-04	Milano	\N	1241	premium	chimica	0	0	0	\N	0	non definito
napolitanodavide	4676	davide	napolitano	1996-11-11	SestriCapitale	\N	1242	base	giurisprudenza	0	0	0	\N	0	non definito
straforinimonica	528	monica	straforini	1994-01-04	SestriCapitale	\N	1243	premium	giurisprudenza	0	0	0	\N	0	non definito
zazzeramonica	3638	monica	zazzera	1996-01-24	Milano	\N	1244	base	lettere	0	0	0	\N	0	non definito
storacemonica	9380	monica	storace	1992-04-20	Bogliasco	\N	1245	premium	chimica	0	0	0	\N	0	non definito
armaninomonica	7138	monica	armanino	1993-12-08	SestriCapitale	\N	1246	base	medicina	0	0	0	\N	0	non definito
campisimonica	1724	monica	campisi	1990-07-21	SestriCapitale	\N	1247	premium	matematica	0	0	0	\N	0	non definito
scipionimonica	400	monica	scipioni	1993-12-05	Bogliasco	\N	1248	base	fisica	0	0	0	\N	0	non definito
scottimonica	3116	monica	scotti	1990-01-15	Roma	\N	1249	premium	matematica	0	0	0	\N	0	non definito
simonimonica	3581	monica	simoni	1996-02-11	Roma	\N	1250	base	biologia	0	0	0	\N	0	non definito
basilemonica	940	monica	basile	1991-02-12	Milano	\N	1251	premium	giurisprudenza	0	0	0	\N	0	non definito
saperdimonica	2663	monica	saperdi	1994-08-05	Roma	\N	1252	base	lettere	0	0	0	\N	0	non definito
sangalettimonica	1723	monica	sangaletti	1990-05-11	SestriCapitale	\N	1253	premium	giurisprudenza	0	0	0	\N	0	non definito
paganimonica	8716	monica	pagani	1993-03-21	Milano	\N	1254	base	medicina	0	0	0	\N	0	non definito
ferrarimonica	9049	monica	ferrari	1995-09-05	Milano	\N	1255	premium	matematica	0	0	0	\N	0	non definito
pannellamonica	5382	monica	pannella	1990-01-16	SestriCapitale	\N	1256	base	fisica	0	0	0	\N	0	non definito
tascamonica	807	monica	tasca	1995-07-05	Bogliasco	\N	1257	premium	medicina	0	0	0	\N	0	non definito
gardellamonica	797	monica	gardella	1991-10-08	Milano	\N	1258	base	matematica	0	0	0	\N	0	non definito
zolezzimonica	9575	monica	zolezzi	1991-08-14	Roma	\N	1259	premium	medicina	0	0	0	\N	0	non definito
oliverimonica	1681	monica	oliveri	1991-11-11	Bogliasco	\N	1260	base	fisica	0	0	0	\N	0	non definito
polverinimonica	3898	monica	polverini	1990-11-22	Roma	\N	1262	base	giurisprudenza	0	0	0	\N	0	non definito
pianforinimonica	6548	monica	pianforini	1991-11-24	SestriCapitale	\N	1263	premium	giurisprudenza	0	0	0	\N	0	non definito
stefaninimonica	9575	monica	stefanini	1996-02-09	Roma	\N	1264	base	medicina	0	0	0	\N	0	non definito
tavellamonica	104	monica	tavella	1996-07-25	SestriCapitale	\N	1265	premium	lettere	0	0	0	\N	0	non definito
contemonica	3816	monica	conte	1992-08-06	Milano	\N	1266	base	fisica	0	0	0	\N	0	non definito
mattarellamonica	8648	monica	mattarella	1991-11-23	Milano	\N	1267	premium	medicina	0	0	0	\N	0	non definito
gentilonimonica	9056	monica	gentiloni	1992-02-18	Roma	\N	1268	base	medicina	0	0	0	\N	0	non definito
napolitanomonica	7516	monica	napolitano	1990-12-04	Milano	\N	1269	premium	matematica	0	0	0	\N	0	non definito
straforinialice	8258	alice	straforini	1992-04-03	Milano	\N	1270	base	fisica	0	0	0	\N	0	non definito
zazzeraalice	5316	alice	zazzera	1990-03-17	Bogliasco	\N	1271	premium	chimica	0	0	0	\N	0	non definito
storacealice	5630	alice	storace	1990-03-11	SestriCapitale	\N	1272	base	lettere	0	0	0	\N	0	non definito
armaninoalice	2430	alice	armanino	1995-07-05	Bogliasco	\N	1273	premium	medicina	0	0	0	\N	0	non definito
campisialice	7232	alice	campisi	1991-05-22	SestriCapitale	\N	1274	base	giurisprudenza	0	0	0	\N	0	non definito
scipionialice	4326	alice	scipioni	1990-12-12	SestriCapitale	\N	1275	premium	fisica	0	0	0	\N	0	non definito
scottialice	6814	alice	scotti	1991-04-08	Roma	\N	1276	base	biologia	0	0	0	\N	0	non definito
simonialice	3734	alice	simoni	1991-08-02	Roma	\N	1277	premium	chimica	0	0	0	\N	0	non definito
basilealice	5461	alice	basile	1991-05-01	Bogliasco	\N	1278	base	medicina	0	0	0	\N	0	non definito
saperdialice	3603	alice	saperdi	1992-06-10	Milano	\N	1279	premium	giurisprudenza	0	0	0	\N	0	non definito
sangalettialice	2726	alice	sangaletti	1995-11-12	SestriCapitale	\N	1280	base	chimica	0	0	0	\N	0	non definito
paganialice	9256	alice	pagani	1995-05-01	SestriCapitale	\N	1281	premium	medicina	0	0	0	\N	0	non definito
ferrarialice	7002	alice	ferrari	1991-07-09	Milano	\N	1282	base	biologia	0	0	0	\N	0	non definito
pannellaalice	714	alice	pannella	1993-08-08	Bogliasco	\N	1283	premium	medicina	0	0	0	\N	0	non definito
tascaalice	2600	alice	tasca	1993-06-03	Bogliasco	\N	1284	base	lettere	0	0	0	\N	0	non definito
gardellaalice	5712	alice	gardella	1994-08-11	Roma	\N	1285	premium	giurisprudenza	0	0	0	\N	0	non definito
zolezzialice	4375	alice	zolezzi	1992-09-14	SestriCapitale	\N	1286	base	biologia	0	0	0	\N	0	non definito
oliverialice	3926	alice	oliveri	1994-10-02	SestriCapitale	\N	1287	premium	medicina	0	0	0	\N	0	non definito
malattoalice	1724	alice	malatto	1995-09-08	Milano	\N	1288	base	fisica	0	0	0	\N	0	non definito
polverinialice	4214	alice	polverini	1990-12-04	SestriCapitale	\N	1289	premium	chimica	0	0	0	\N	0	non definito
pianforinialice	1977	alice	pianforini	1995-04-07	SestriCapitale	\N	1290	base	fisica	0	0	0	\N	0	non definito
stefaninialice	1979	alice	stefanini	1995-12-18	Roma	\N	1291	premium	medicina	0	0	0	\N	0	non definito
tavellaalice	1577	alice	tavella	1990-05-21	SestriCapitale	\N	1292	base	fisica	0	0	0	\N	0	non definito
contealice	8282	alice	conte	1996-08-15	SestriCapitale	\N	1293	premium	chimica	0	0	0	\N	0	non definito
mattarellaalice	3676	alice	mattarella	1995-01-05	Milano	\N	1294	base	giurisprudenza	0	0	0	\N	0	non definito
gentilonialice	5654	alice	gentiloni	1993-08-08	Milano	\N	1295	premium	matematica	0	0	0	\N	0	non definito
napolitanoalice	8139	alice	napolitano	1990-02-22	SestriCapitale	\N	1296	base	lettere	0	0	0	\N	0	non definito
straforinijacopo	6887	jacopo	straforini	1990-01-10	Bogliasco	\N	1297	premium	lettere	0	0	0	\N	0	non definito
zazzerajacopo	8913	jacopo	zazzera	1994-01-09	SestriCapitale	\N	1298	base	matematica	0	0	0	\N	0	non definito
storacejacopo	479	jacopo	storace	1990-11-13	Bogliasco	\N	1299	premium	chimica	0	0	0	\N	0	non definito
armaninojacopo	5692	jacopo	armanino	1990-07-17	Milano	\N	1300	base	biologia	0	0	0	\N	0	non definito
campisijacopo	6451	jacopo	campisi	1993-07-10	Bogliasco	\N	1301	premium	chimica	0	0	0	\N	0	non definito
scipionijacopo	823	jacopo	scipioni	1992-08-21	Bogliasco	\N	1302	base	lettere	0	0	0	\N	0	non definito
scottijacopo	8986	jacopo	scotti	1990-03-25	Roma	\N	1303	premium	biologia	0	0	0	\N	0	non definito
simonijacopo	8013	jacopo	simoni	1993-08-07	SestriCapitale	\N	1304	base	biologia	0	0	0	\N	0	non definito
basilejacopo	668	jacopo	basile	1994-11-01	Milano	\N	1305	premium	giurisprudenza	0	0	0	\N	0	non definito
saperdijacopo	6165	jacopo	saperdi	1992-03-13	Roma	\N	1306	base	chimica	0	0	0	\N	0	non definito
sangalettijacopo	8592	jacopo	sangaletti	1992-08-16	Milano	\N	1307	premium	biologia	0	0	0	\N	0	non definito
paganijacopo	7933	jacopo	pagani	1994-01-19	Roma	\N	1308	base	biologia	0	0	0	\N	0	non definito
ferrarijacopo	1162	jacopo	ferrari	1995-01-03	Roma	\N	1309	premium	matematica	0	0	0	\N	0	non definito
pannellajacopo	6268	jacopo	pannella	1994-04-15	Bogliasco	\N	1310	base	matematica	0	0	0	\N	0	non definito
tascajacopo	857	jacopo	tasca	1995-11-14	Bogliasco	\N	1311	premium	lettere	0	0	0	\N	0	non definito
gardellajacopo	6752	jacopo	gardella	1996-11-05	Milano	\N	1312	base	biologia	0	0	0	\N	0	non definito
zolezzijacopo	4018	jacopo	zolezzi	1991-09-18	SestriCapitale	\N	1313	premium	medicina	0	0	0	\N	0	non definito
oliverijacopo	4904	jacopo	oliveri	1996-12-22	Roma	\N	1314	base	matematica	0	0	0	\N	0	non definito
malattojacopo	8372	jacopo	malatto	1993-12-05	Roma	\N	1315	premium	fisica	0	0	0	\N	0	non definito
polverinijacopo	6343	jacopo	polverini	1991-05-01	SestriCapitale	\N	1316	base	giurisprudenza	0	0	0	\N	0	non definito
pianforinijacopo	1504	jacopo	pianforini	1990-12-18	SestriCapitale	\N	1317	premium	biologia	0	0	0	\N	0	non definito
stefaninijacopo	5358	jacopo	stefanini	1992-07-15	Milano	\N	1318	base	fisica	0	0	0	\N	0	non definito
tavellajacopo	539	jacopo	tavella	1990-06-04	Milano	\N	1319	premium	lettere	0	0	0	\N	0	non definito
contejacopo	7677	jacopo	conte	1992-03-19	Roma	\N	1320	base	fisica	0	0	0	\N	0	non definito
mattarellajacopo	3258	jacopo	mattarella	1990-07-09	Milano	\N	1321	premium	biologia	0	0	0	\N	0	non definito
gentilonijacopo	9614	jacopo	gentiloni	1992-06-01	Roma	\N	1322	base	matematica	0	0	0	\N	0	non definito
napolitanojacopo	8578	jacopo	napolitano	1994-02-18	Milano	\N	1323	premium	medicina	0	0	0	\N	0	non definito
straforinigabriele	5239	gabriele	straforini	1993-09-18	Milano	\N	1324	base	medicina	0	0	0	\N	0	non definito
zazzeragabriele	3091	gabriele	zazzera	1996-09-21	Roma	\N	1325	premium	fisica	0	0	0	\N	0	non definito
storacegabriele	498	gabriele	storace	1995-03-23	SestriCapitale	\N	1326	base	fisica	0	0	0	\N	0	non definito
armaninogabriele	9848	gabriele	armanino	1991-05-09	Roma	\N	1327	premium	biologia	0	0	0	\N	0	non definito
campisigabriele	2209	gabriele	campisi	1995-11-01	Roma	\N	1328	base	fisica	0	0	0	\N	0	non definito
scipionigabriele	5076	gabriele	scipioni	1990-04-12	Bogliasco	\N	1329	premium	biologia	0	0	0	\N	0	non definito
scottigabriele	3931	gabriele	scotti	1992-05-06	SestriCapitale	\N	1330	base	chimica	0	0	0	\N	0	non definito
simonigabriele	3267	gabriele	simoni	1993-01-24	SestriCapitale	\N	1331	premium	giurisprudenza	0	0	0	\N	0	non definito
basilegabriele	6822	gabriele	basile	1994-05-11	Roma	\N	1332	base	medicina	0	0	0	\N	0	non definito
saperdigabriele	7427	gabriele	saperdi	1991-03-05	SestriCapitale	\N	1333	premium	lettere	0	0	0	\N	0	non definito
sangalettigabriele	2441	gabriele	sangaletti	1992-11-16	Bogliasco	\N	1334	base	lettere	0	0	0	\N	0	non definito
paganigabriele	4038	gabriele	pagani	1992-10-05	Roma	\N	1335	premium	matematica	0	0	0	\N	0	non definito
ferrarigabriele	248	gabriele	ferrari	1996-07-04	SestriCapitale	\N	1336	base	medicina	0	0	0	\N	0	non definito
pannellagabriele	719	gabriele	pannella	1990-12-19	SestriCapitale	\N	1337	premium	biologia	0	0	0	\N	0	non definito
tascagabriele	7042	gabriele	tasca	1993-09-13	Roma	\N	1338	base	lettere	0	0	0	\N	0	non definito
gardellagabriele	3293	gabriele	gardella	1995-08-01	Bogliasco	\N	1339	premium	matematica	0	0	0	\N	0	non definito
zolezzigabriele	5858	gabriele	zolezzi	1990-04-10	Bogliasco	\N	1340	base	giurisprudenza	0	0	0	\N	0	non definito
oliverigabriele	4992	gabriele	oliveri	1992-02-16	Roma	\N	1341	premium	lettere	0	0	0	\N	0	non definito
malattogabriele	2280	gabriele	malatto	1992-04-16	Bogliasco	\N	1342	base	giurisprudenza	0	0	0	\N	0	non definito
polverinigabriele	1070	gabriele	polverini	1992-06-08	Roma	\N	1343	premium	biologia	0	0	0	\N	0	non definito
pianforinigabriele	3788	gabriele	pianforini	1996-01-19	Milano	\N	1344	base	lettere	0	0	0	\N	0	non definito
stefaninigabriele	9882	gabriele	stefanini	1990-02-19	SestriCapitale	\N	1345	premium	fisica	0	0	0	\N	0	non definito
tavellagabriele	6087	gabriele	tavella	1995-01-11	Bogliasco	\N	1346	base	medicina	0	0	0	\N	0	non definito
contegabriele	5689	gabriele	conte	1995-11-17	Roma	\N	1347	premium	fisica	0	0	0	\N	0	non definito
mattarellagabriele	6197	gabriele	mattarella	1996-02-13	Roma	\N	1348	base	matematica	0	0	0	\N	0	non definito
gentilonigabriele	9113	gabriele	gentiloni	1995-12-25	Roma	\N	1349	premium	chimica	0	0	0	\N	0	non definito
napolitanogabriele	5891	gabriele	napolitano	1994-08-25	Milano	\N	1350	base	medicina	0	0	0	\N	0	non definito
straforinialessandro	3367	alessandro	straforini	1993-08-10	SestriCapitale	\N	1351	premium	chimica	0	0	0	\N	0	non definito
zazzeraalessandro	6505	alessandro	zazzera	1991-11-05	SestriCapitale	\N	1352	base	fisica	0	0	0	\N	0	non definito
storacealessandro	900	alessandro	storace	1994-06-19	Bogliasco	\N	1353	premium	giurisprudenza	0	0	0	\N	0	non definito
armaninoalessandro	9580	alessandro	armanino	1993-12-05	SestriCapitale	\N	1354	base	matematica	0	0	0	\N	0	non definito
campisialessandro	7037	alessandro	campisi	1996-07-10	Milano	\N	1355	premium	medicina	0	0	0	\N	0	non definito
scipionialessandro	8235	alessandro	scipioni	1992-06-10	Bogliasco	\N	1356	base	chimica	0	0	0	\N	0	non definito
scottialessandro	989	alessandro	scotti	1995-06-15	Roma	\N	1357	premium	chimica	0	0	0	\N	0	non definito
simonialessandro	7740	alessandro	simoni	1991-08-20	SestriCapitale	\N	1358	base	chimica	0	0	0	\N	0	non definito
basilealessandro	4409	alessandro	basile	1994-07-15	Roma	\N	1359	premium	matematica	0	0	0	\N	0	non definito
saperdialessandro	7115	alessandro	saperdi	1995-10-23	SestriCapitale	\N	1360	base	fisica	0	0	0	\N	0	non definito
sangalettialessandro	7086	alessandro	sangaletti	1992-11-10	Roma	\N	1361	premium	biologia	0	0	0	\N	0	non definito
paganialessandro	8182	alessandro	pagani	1995-06-25	Roma	\N	1362	base	fisica	0	0	0	\N	0	non definito
ferrarialessandro	9266	alessandro	ferrari	1993-01-07	Bogliasco	\N	1363	premium	biologia	0	0	0	\N	0	non definito
pannellaalessandro	1312	alessandro	pannella	1993-01-04	Roma	\N	1364	base	giurisprudenza	0	0	0	\N	0	non definito
tascaalessandro	2045	alessandro	tasca	1994-08-24	Milano	\N	1365	premium	fisica	0	0	0	\N	0	non definito
gardellaalessandro	7656	alessandro	gardella	1992-02-09	Bogliasco	\N	1366	base	lettere	0	0	0	\N	0	non definito
zolezzialessandro	8682	alessandro	zolezzi	1992-04-21	Bogliasco	\N	1367	premium	biologia	0	0	0	\N	0	non definito
oliverialessandro	2957	alessandro	oliveri	1993-11-03	Roma	\N	1368	base	chimica	0	0	0	\N	0	non definito
malattoalessandro	9399	alessandro	malatto	1992-09-23	SestriCapitale	\N	1369	premium	lettere	0	0	0	\N	0	non definito
polverinialessandro	1672	alessandro	polverini	1991-10-01	Milano	\N	1370	base	lettere	0	0	0	\N	0	non definito
pianforinialessandro	6750	alessandro	pianforini	1994-02-10	SestriCapitale	\N	1371	premium	matematica	0	0	0	\N	0	non definito
stefaninialessandro	9502	alessandro	stefanini	1991-08-07	Bogliasco	\N	1372	base	lettere	0	0	0	\N	0	non definito
tavellaalessandro	7	alessandro	tavella	1996-07-15	Milano	\N	1373	premium	matematica	0	0	0	\N	0	non definito
contealessandro	2921	alessandro	conte	1993-03-13	SestriCapitale	\N	1374	base	biologia	0	0	0	\N	0	non definito
mattarellaalessandro	9412	alessandro	mattarella	1992-04-01	Milano	\N	1375	premium	giurisprudenza	0	0	0	\N	0	non definito
gentilonialessandro	7770	alessandro	gentiloni	1995-09-11	Bogliasco	\N	1376	base	matematica	0	0	0	\N	0	non definito
napolitanoalessandro	9007	alessandro	napolitano	1991-04-23	SestriCapitale	\N	1377	premium	fisica	0	0	0	\N	0	non definito
straforinisofia	7318	sofia	straforini	1992-05-09	Roma	\N	1378	base	lettere	0	0	0	\N	0	non definito
zazzerasofia	6858	sofia	zazzera	1993-05-17	Roma	\N	1379	premium	fisica	0	0	0	\N	0	non definito
storacesofia	34	sofia	storace	1996-05-09	Roma	\N	1380	base	giurisprudenza	0	0	0	\N	0	non definito
armaninosofia	2507	sofia	armanino	1992-05-24	Bogliasco	\N	1381	premium	matematica	0	0	0	\N	0	non definito
campisisofia	3828	sofia	campisi	1993-01-02	Roma	\N	1382	base	matematica	0	0	0	\N	0	non definito
scipionisofia	7804	sofia	scipioni	1993-09-14	Milano	\N	1383	premium	giurisprudenza	0	0	0	\N	0	non definito
scottisofia	3823	sofia	scotti	1993-04-14	Bogliasco	\N	1384	base	fisica	0	0	0	\N	0	non definito
simonisofia	676	sofia	simoni	1992-10-14	Roma	\N	1385	premium	fisica	0	0	0	\N	0	non definito
basilesofia	5042	sofia	basile	1991-09-04	SestriCapitale	\N	1386	base	lettere	0	0	0	\N	0	non definito
saperdisofia	4524	sofia	saperdi	1992-10-18	Roma	\N	1387	premium	matematica	0	0	0	\N	0	non definito
sangalettisofia	1078	sofia	sangaletti	1995-09-25	Roma	\N	1388	base	chimica	0	0	0	\N	0	non definito
paganisofia	8057	sofia	pagani	1991-12-23	SestriCapitale	\N	1389	premium	biologia	0	0	0	\N	0	non definito
ferrarisofia	5115	sofia	ferrari	1991-04-18	Milano	\N	1390	base	fisica	0	0	0	\N	0	non definito
pannellasofia	9114	sofia	pannella	1993-05-13	SestriCapitale	\N	1391	premium	chimica	0	0	0	\N	0	non definito
tascasofia	7959	sofia	tasca	1991-02-05	Roma	\N	1392	base	chimica	0	0	0	\N	0	non definito
gardellasofia	742	sofia	gardella	1995-11-04	Bogliasco	\N	1393	premium	biologia	0	0	0	\N	0	non definito
zolezzisofia	1682	sofia	zolezzi	1990-02-21	Milano	\N	1394	base	fisica	0	0	0	\N	0	non definito
oliverisofia	3997	sofia	oliveri	1993-12-15	SestriCapitale	\N	1395	premium	matematica	0	0	0	\N	0	non definito
malattosofia	6456	sofia	malatto	1994-02-03	Milano	\N	1396	base	lettere	0	0	0	\N	0	non definito
polverinisofia	7312	sofia	polverini	1993-01-18	SestriCapitale	\N	1397	premium	matematica	0	0	0	\N	0	non definito
pianforinisofia	4067	sofia	pianforini	1994-05-20	SestriCapitale	\N	1398	base	chimica	0	0	0	\N	0	non definito
stefaninisofia	6886	sofia	stefanini	1994-08-17	Bogliasco	\N	1399	premium	fisica	0	0	0	\N	0	non definito
tavellasofia	6940	sofia	tavella	1995-05-17	SestriCapitale	\N	1400	base	lettere	0	0	0	\N	0	non definito
contesofia	3238	sofia	conte	1996-03-20	Bogliasco	\N	1401	premium	giurisprudenza	0	0	0	\N	0	non definito
mattarellasofia	4391	sofia	mattarella	1990-07-22	Milano	\N	1402	base	giurisprudenza	0	0	0	\N	0	non definito
gentilonisofia	163	sofia	gentiloni	1994-03-23	SestriCapitale	\N	1403	premium	giurisprudenza	0	0	0	\N	0	non definito
napolitanosofia	9089	sofia	napolitano	1996-10-17	Milano	\N	1404	base	chimica	0	0	0	\N	0	non definito
straforinieleonora	8192	eleonora	straforini	1993-10-25	SestriCapitale	\N	1405	premium	fisica	0	0	0	\N	0	non definito
zazzeraeleonora	3167	eleonora	zazzera	1995-09-20	Milano	\N	1406	base	giurisprudenza	0	0	0	\N	0	non definito
storaceeleonora	3864	eleonora	storace	1994-01-18	Milano	\N	1407	premium	biologia	0	0	0	\N	0	non definito
armaninoeleonora	2667	eleonora	armanino	1993-10-11	Bogliasco	\N	1408	base	matematica	0	0	0	\N	0	non definito
campisieleonora	5153	eleonora	campisi	1994-02-20	Milano	\N	1409	premium	lettere	0	0	0	\N	0	non definito
scipionieleonora	150	eleonora	scipioni	1991-09-11	Bogliasco	\N	1410	base	chimica	0	0	0	\N	0	non definito
scottieleonora	4294	eleonora	scotti	1993-10-16	SestriCapitale	\N	1411	premium	lettere	0	0	0	\N	0	non definito
simonieleonora	9309	eleonora	simoni	1993-01-06	SestriCapitale	\N	1412	base	matematica	0	0	0	\N	0	non definito
basileeleonora	6759	eleonora	basile	1994-03-09	SestriCapitale	\N	1413	premium	biologia	0	0	0	\N	0	non definito
saperdieleonora	5441	eleonora	saperdi	1993-05-18	Roma	\N	1414	base	fisica	0	0	0	\N	0	non definito
sangalettieleonora	9367	eleonora	sangaletti	1996-04-11	SestriCapitale	\N	1415	premium	biologia	0	0	0	\N	0	non definito
paganieleonora	4592	eleonora	pagani	1995-06-08	Milano	\N	1416	base	medicina	0	0	0	\N	0	non definito
ferrarieleonora	8137	eleonora	ferrari	1996-10-16	Roma	\N	1417	premium	giurisprudenza	0	0	0	\N	0	non definito
pannellaeleonora	3809	eleonora	pannella	1994-02-21	Milano	\N	1418	base	lettere	0	0	0	\N	0	non definito
tascaeleonora	6687	eleonora	tasca	1995-04-11	Roma	\N	1419	premium	lettere	0	0	0	\N	0	non definito
gardellaeleonora	600	eleonora	gardella	1993-06-16	SestriCapitale	\N	1420	base	matematica	0	0	0	\N	0	non definito
zolezzieleonora	199	eleonora	zolezzi	1992-11-12	Roma	\N	1421	premium	giurisprudenza	0	0	0	\N	0	non definito
oliverieleonora	3039	eleonora	oliveri	1993-09-11	SestriCapitale	\N	1422	base	matematica	0	0	0	\N	0	non definito
malattoeleonora	7099	eleonora	malatto	1991-05-05	Roma	\N	1423	premium	giurisprudenza	0	0	0	\N	0	non definito
polverinieleonora	1477	eleonora	polverini	1995-08-19	Bogliasco	\N	1424	base	lettere	0	0	0	\N	0	non definito
pianforinieleonora	4828	eleonora	pianforini	1996-12-04	Bogliasco	\N	1425	premium	matematica	0	0	0	\N	0	non definito
stefaninieleonora	1950	eleonora	stefanini	1992-01-23	Bogliasco	\N	1426	base	matematica	0	0	0	\N	0	non definito
tavellaeleonora	3923	eleonora	tavella	1992-10-03	Milano	\N	1427	premium	fisica	0	0	0	\N	0	non definito
conteeleonora	574	eleonora	conte	1991-09-17	SestriCapitale	\N	1428	base	giurisprudenza	0	0	0	\N	0	non definito
mattarellaeleonora	1021	eleonora	mattarella	1993-11-03	Bogliasco	\N	1429	premium	matematica	0	0	0	\N	0	non definito
gentilonieleonora	747	eleonora	gentiloni	1993-07-16	Roma	\N	1430	base	chimica	0	0	0	\N	0	non definito
napolitanoeleonora	2170	eleonora	napolitano	1994-07-07	SestriCapitale	\N	1431	premium	chimica	0	0	0	\N	0	non definito
straforiniemanuele	4614	emanuele	straforini	1991-12-11	Bogliasco	\N	1432	base	matematica	0	0	0	\N	0	non definito
zazzeraemanuele	1658	emanuele	zazzera	1990-02-24	Milano	\N	1433	premium	fisica	0	0	0	\N	0	non definito
storaceemanuele	3982	emanuele	storace	1996-12-13	Bogliasco	\N	1434	base	fisica	0	0	0	\N	0	non definito
armaninoemanuele	1163	emanuele	armanino	1995-10-04	Bogliasco	\N	1435	premium	fisica	0	0	0	\N	0	non definito
campisiemanuele	1034	emanuele	campisi	1993-05-23	Milano	\N	1436	base	matematica	0	0	0	\N	0	non definito
scipioniemanuele	7146	emanuele	scipioni	1994-05-22	Bogliasco	\N	1437	premium	biologia	0	0	0	\N	0	non definito
scottiemanuele	4249	emanuele	scotti	1994-07-17	Milano	\N	1438	base	giurisprudenza	0	0	0	\N	0	non definito
simoniemanuele	1245	emanuele	simoni	1994-05-07	SestriCapitale	\N	1439	premium	fisica	0	0	0	\N	0	non definito
basileemanuele	7151	emanuele	basile	1994-05-02	Bogliasco	\N	1440	base	biologia	0	0	0	\N	0	non definito
saperdiemanuele	3682	emanuele	saperdi	1992-09-06	Milano	\N	1441	premium	biologia	0	0	0	\N	0	non definito
sangalettiemanuele	2294	emanuele	sangaletti	1994-12-02	Roma	\N	1442	base	chimica	0	0	0	\N	0	non definito
paganiemanuele	3599	emanuele	pagani	1992-01-06	Bogliasco	\N	1443	premium	biologia	0	0	0	\N	0	non definito
ferrariemanuele	823	emanuele	ferrari	1991-03-12	Bogliasco	\N	1444	base	biologia	0	0	0	\N	0	non definito
pannellaemanuele	5981	emanuele	pannella	1992-05-12	Bogliasco	\N	1445	premium	fisica	0	0	0	\N	0	non definito
tascaemanuele	7468	emanuele	tasca	1995-06-06	Bogliasco	\N	1446	base	medicina	0	0	0	\N	0	non definito
gardellaemanuele	3019	emanuele	gardella	1994-11-18	Bogliasco	\N	1447	premium	matematica	0	0	0	\N	0	non definito
zolezziemanuele	8187	emanuele	zolezzi	1993-03-09	SestriCapitale	\N	1448	base	fisica	0	0	0	\N	0	non definito
oliveriemanuele	4020	emanuele	oliveri	1991-07-08	SestriCapitale	\N	1449	premium	chimica	0	0	0	\N	0	non definito
malattoemanuele	4697	emanuele	malatto	1991-10-25	SestriCapitale	\N	1450	base	lettere	0	0	0	\N	0	non definito
polveriniemanuele	4021	emanuele	polverini	1992-01-10	Bogliasco	\N	1451	premium	medicina	0	0	0	\N	0	non definito
pianforiniemanuele	1985	emanuele	pianforini	1993-12-06	Milano	\N	1452	base	lettere	0	0	0	\N	0	non definito
stefaniniemanuele	6134	emanuele	stefanini	1990-02-02	Roma	\N	1453	premium	medicina	0	0	0	\N	0	non definito
tavellaemanuele	6023	emanuele	tavella	1990-05-01	SestriCapitale	\N	1454	base	giurisprudenza	0	0	0	\N	0	non definito
conteemanuele	8155	emanuele	conte	1990-12-25	Milano	\N	1455	premium	lettere	0	0	0	\N	0	non definito
mattarellaemanuele	3526	emanuele	mattarella	1991-08-02	Roma	\N	1456	base	fisica	0	0	0	\N	0	non definito
gentiloniemanuele	2719	emanuele	gentiloni	1992-01-22	SestriCapitale	\N	1457	premium	chimica	0	0	0	\N	0	non definito
napolitanoemanuele	6314	emanuele	napolitano	1990-05-25	Milano	\N	1458	base	medicina	0	0	0	\N	0	non definito
straforinipaolo	1397	paolo	straforini	1992-06-10	Roma	\N	1459	premium	lettere	0	0	0	\N	0	non definito
zazzerapaolo	9347	paolo	zazzera	1990-06-24	Roma	\N	1460	base	fisica	0	0	0	\N	0	non definito
storacepaolo	7908	paolo	storace	1993-01-09	Milano	\N	1461	premium	lettere	0	0	0	\N	0	non definito
armaninopaolo	8511	paolo	armanino	1990-01-23	SestriCapitale	\N	1462	base	giurisprudenza	0	0	0	\N	0	non definito
campisipaolo	5957	paolo	campisi	1994-04-16	Bogliasco	\N	1463	premium	biologia	0	0	0	\N	0	non definito
scipionipaolo	5195	paolo	scipioni	1992-09-04	Milano	\N	1464	base	giurisprudenza	0	0	0	\N	0	non definito
scottipaolo	8499	paolo	scotti	1996-05-05	SestriCapitale	\N	1465	premium	matematica	0	0	0	\N	0	non definito
simonipaolo	4494	paolo	simoni	1991-12-07	Milano	\N	1466	base	chimica	0	0	0	\N	0	non definito
basilepaolo	5575	paolo	basile	1996-08-05	Milano	\N	1467	premium	matematica	0	0	0	\N	0	non definito
saperdipaolo	7386	paolo	saperdi	1993-10-16	SestriCapitale	\N	1468	base	chimica	0	0	0	\N	0	non definito
sangalettipaolo	9542	paolo	sangaletti	1991-12-05	Bogliasco	\N	1469	premium	lettere	0	0	0	\N	0	non definito
paganipaolo	5271	paolo	pagani	1996-05-12	Bogliasco	\N	1470	base	medicina	0	0	0	\N	0	non definito
ferraripaolo	4257	paolo	ferrari	1991-03-19	Milano	\N	1471	premium	medicina	0	0	0	\N	0	non definito
pannellapaolo	2886	paolo	pannella	1991-02-01	SestriCapitale	\N	1472	base	medicina	0	0	0	\N	0	non definito
tascapaolo	3536	paolo	tasca	1993-04-23	SestriCapitale	\N	1473	premium	fisica	0	0	0	\N	0	non definito
gardellapaolo	6263	paolo	gardella	1990-11-10	Milano	\N	1474	base	lettere	0	0	0	\N	0	non definito
zolezzipaolo	3074	paolo	zolezzi	1994-10-10	SestriCapitale	\N	1475	premium	biologia	0	0	0	\N	0	non definito
oliveripaolo	2911	paolo	oliveri	1992-10-12	Roma	\N	1476	base	medicina	0	0	0	\N	0	non definito
malattopaolo	2301	paolo	malatto	1991-12-14	Bogliasco	\N	1477	premium	biologia	0	0	0	\N	0	non definito
polverinipaolo	6419	paolo	polverini	1991-05-10	Roma	\N	1478	base	chimica	0	0	0	\N	0	non definito
pianforinipaolo	1494	paolo	pianforini	1993-07-03	Bogliasco	\N	1479	premium	chimica	0	0	0	\N	0	non definito
stefaninipaolo	3569	paolo	stefanini	1995-01-12	Roma	\N	1480	base	fisica	0	0	0	\N	0	non definito
tavellapaolo	6692	paolo	tavella	1994-05-11	Milano	\N	1481	premium	lettere	0	0	0	\N	0	non definito
contepaolo	2921	paolo	conte	1996-02-02	Milano	\N	1482	base	chimica	0	0	0	\N	0	non definito
mattarellapaolo	7262	paolo	mattarella	1991-08-24	Bogliasco	\N	1483	premium	lettere	0	0	0	\N	0	non definito
gentilonipaolo	1024	paolo	gentiloni	1992-12-12	Bogliasco	\N	1484	base	fisica	0	0	0	\N	0	non definito
napolitanopaolo	4135	paolo	napolitano	1995-10-09	Milano	\N	1485	premium	fisica	0	0	0	\N	0	non definito
straforinirita	7924	rita	straforini	1994-01-13	Milano	\N	1486	base	matematica	0	0	0	\N	0	non definito
zazzerarita	8475	rita	zazzera	1993-09-19	Roma	\N	1487	premium	lettere	0	0	0	\N	0	non definito
storacerita	1818	rita	storace	1992-06-10	Milano	\N	1488	base	matematica	0	0	0	\N	0	non definito
armaninorita	704	rita	armanino	1991-02-05	Bogliasco	\N	1489	premium	lettere	0	0	0	\N	0	non definito
campisirita	4184	rita	campisi	1992-04-08	Roma	\N	1490	base	matematica	0	0	0	\N	0	non definito
scipionirita	1459	rita	scipioni	1991-05-11	SestriCapitale	\N	1491	premium	lettere	0	0	0	\N	0	non definito
scottirita	1047	rita	scotti	1995-04-11	SestriCapitale	\N	1492	base	giurisprudenza	0	0	0	\N	0	non definito
simonirita	8612	rita	simoni	1993-12-02	Milano	\N	1493	premium	giurisprudenza	0	0	0	\N	0	non definito
basilerita	5569	rita	basile	1992-03-01	Roma	\N	1494	base	giurisprudenza	0	0	0	\N	0	non definito
saperdirita	7784	rita	saperdi	1995-12-21	Roma	\N	1495	premium	lettere	0	0	0	\N	0	non definito
sangalettirita	1610	rita	sangaletti	1992-04-02	Bogliasco	\N	1496	base	medicina	0	0	0	\N	0	non definito
paganirita	2434	rita	pagani	1993-05-20	SestriCapitale	\N	1497	premium	lettere	0	0	0	\N	0	non definito
ferraririta	1686	rita	ferrari	1992-08-09	SestriCapitale	\N	1498	base	matematica	0	0	0	\N	0	non definito
pannellarita	1975	rita	pannella	1994-01-19	Bogliasco	\N	1499	premium	biologia	0	0	0	\N	0	non definito
tascarita	2528	rita	tasca	1990-09-22	Milano	\N	1500	base	fisica	0	0	0	\N	0	non definito
straforiniandrea	3186	andrea	straforini	1994-10-14	Roma	\N	1000	premium	biologia	0	0	0	\N	21	non definito
conteandrea	5174	andrea	conte	1996-05-08	Bogliasco	\N	1023	premium	giurisprudenza	0	0	0	\N	6	non definito
armaninoandrea	826	andrea	armanino	1990-02-10	SestriCapitale	\N	1003	premium	giurisprudenza	0	0	0	\N	6	non definito
campisiandrea	2996	andrea	campisi	1990-01-17	Roma	\N	1004	base	medicina	0	0	0	\N	6	non definito
scottiandrea	55	andrea	scotti	1994-10-25	Bogliasco	\N	1006	base	matematica	0	0	0	\N	6	non definito
simoniandrea	1877	andrea	simoni	1991-04-21	Bogliasco	\N	1007	premium	chimica	0	0	0	\N	6	non definito
basileandrea	2549	andrea	basile	1996-04-10	Milano	\N	1008	base	lettere	0	0	0	\N	6	non definito
saperdiandrea	4378	andrea	saperdi	1995-02-02	Milano	\N	1009	premium	lettere	0	0	0	\N	6	non definito
sangalettiandrea	5777	andrea	sangaletti	1990-09-22	Bogliasco	\N	1010	base	biologia	0	0	0	\N	6	non definito
paganiandrea	6763	andrea	pagani	1992-08-13	Bogliasco	\N	1011	premium	chimica	0	0	0	\N	6	non definito
ferrariandrea	526	andrea	ferrari	1995-08-22	Milano	\N	1012	base	chimica	0	0	0	\N	6	non definito
pannellaandrea	9955	andrea	pannella	1996-12-16	Roma	\N	1013	premium	giurisprudenza	0	0	0	\N	6	non definito
tascaandrea	5277	andrea	tasca	1995-08-20	SestriCapitale	\N	1014	base	matematica	0	0	0	\N	6	non definito
scipioniandrea	4373	andrea	scipioni	1996-01-18	Roma	\N	1005	premium	giurisprudenza	0	0	0	\N	17	non definito
storaceandrea	5472	andrea	storace	1991-07-20	Roma	\N	1002	base	chimica	0	0	0	\N	6	non definito
tascaaurora	5246	aurora	tasca	1994-05-14	SestriCapitale	\N	1122	base	fisica	0	0	0	\N	23	non definito
tavellaaurora	3057	aurora	tavella	1995-06-17	Milano	\N	1130	base	lettere	0	0	0	\N	16	non definito
zazzeraandrea	8429	andrea	zazzera	1992-10-07	Bogliasco	\N	1001	premium	fisica	0	0	0	\N	21	non definito
storacegaetano	7924	gaetano	storace	1996-06-03	SestriCapitale	\N	1137	premium	medicina	0	0	0	\N	15	non definito
contegemma	6780	gemma	conte	1993-04-18	Milano	\N	1185	premium	chimica	0	0	0	\N	15	non definito
malattomonica	1875	monica	malatto	1990-08-25	Milano	\N	1261	premium	lettere	0	0	0	\N	15	non definito
armaninogaetano	1143	gaetano	armanino	1992-03-10	Bogliasco	\N	1138	base	lettere	0	0	0	\N	15	non definito
campisigaetano	2060	gaetano	campisi	1995-01-06	Bogliasco	\N	1139	premium	fisica	0	0	0	\N	15	non definito
contealberto	650	alberto	conte	1996-01-18	Bogliasco	\N	1104	base	biologia	0	0	0	\N	12	non definito
saperdigaetano	7657	gaetano	saperdi	1991-11-20	Roma	\N	1144	base	fisica	0	0	0	\N	12	non definito
\.


--
-- Name: users_photo_seq; Type: SEQUENCE SET; Schema: bdproject; Owner: postgres
--

SELECT pg_catalog.setval('bdproject.users_photo_seq', 1, true);


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
    ADD CONSTRAINT outcomes_pkey PRIMARY KEY (match, team);


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
-- Name: tournamentscandidatures tournamentscandidatures_pk; Type: CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.tournamentscandidatures
    ADD CONSTRAINT tournamentscandidatures_pk PRIMARY KEY (team, tournament);


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
-- Name: tournamentprogram _RETURN; Type: RULE; Schema: bdproject; Owner: postgres
--

CREATE RULE "_RETURN" AS
    ON SELECT TO bdproject.tournamentprogram DO INSTEAD  SELECT m.tournament,
    m.building,
    m.organizedon,
    m.id,
    bdproject.aux_competitors(m.id) AS competitors,
    bdproject.aux_referee(m.id) AS referee,
    m.phase,
    bar.winner
   FROM ((bdproject.matches m
     LEFT JOIN bdproject.outcomes o ON ((m.id = o.match)))
     JOIN ( SELECT foo.match,
            foo.wins,
            o_1.team AS winner
           FROM (( SELECT outcomes.match,
                    max(
                        CASE
                            WHEN (outcomes.score IS NULL) THEN outcomes.win
                            ELSE outcomes.score
                        END) AS wins
                   FROM bdproject.outcomes
                  GROUP BY outcomes.match) foo
             LEFT JOIN bdproject.outcomes o_1 ON (((o_1.match = foo.match) AND (
                CASE
                    WHEN (o_1.score IS NULL) THEN o_1.win
                    ELSE o_1.score
                END = foo.wins))))) bar ON ((bar.match = o.match)))
  WHERE (m.tournament IS NOT NULL)
  GROUP BY m.id, bar.winner
  ORDER BY m.tournament, m.phase;


--
-- Name: evaluations trigger_evaluations_insert; Type: TRIGGER; Schema: bdproject; Owner: postgres
--

CREATE TRIGGER trigger_evaluations_insert AFTER INSERT ON bdproject.evaluations FOR EACH ROW EXECUTE PROCEDURE bdproject.proc_trigger_evaluation_insert();


--
-- Name: TRIGGER trigger_evaluations_insert ON evaluations; Type: COMMENT; Schema: bdproject; Owner: postgres
--

COMMENT ON TRIGGER trigger_evaluations_insert ON bdproject.evaluations IS 'Controlla che l''inserimento della recensione avvnega con almeno un match giocato in comune e che non sia un auto valutazione.';


--
-- Name: matchcandidatures trigger_matchcandidatures_insert; Type: TRIGGER; Schema: bdproject; Owner: postgres
--

CREATE TRIGGER trigger_matchcandidatures_insert AFTER INSERT ON bdproject.matchcandidatures FOR EACH ROW EXECUTE PROCEDURE bdproject.proc_trigger_matchcandidatures_insert();


--
-- Name: TRIGGER trigger_matchcandidatures_insert ON matchcandidatures; Type: COMMENT; Schema: bdproject; Owner: postgres
--

COMMENT ON TRIGGER trigger_matchcandidatures_insert ON bdproject.matchcandidatures IS 'Controlla che la squadra non si confermi autonomamente';


--
-- Name: matches trigger_matches_insert; Type: TRIGGER; Schema: bdproject; Owner: postgres
--

CREATE TRIGGER trigger_matches_insert AFTER INSERT ON bdproject.matches FOR EACH ROW EXECUTE PROCEDURE bdproject.proc_trigger_matches_insert();


--
-- Name: TRIGGER trigger_matches_insert ON matches; Type: COMMENT; Schema: bdproject; Owner: postgres
--

COMMENT ON TRIGGER trigger_matches_insert ON bdproject.matches IS 'Se è un evento singolo lo crea e crea le squadre fittizie e le iscrive alla partita.Se invece l''evento appartiene ad un torneo contorlla che l''admin sia lo stesso';


--
-- Name: matchcandidatures trigger_matchescandidatures_update; Type: TRIGGER; Schema: bdproject; Owner: postgres
--

CREATE TRIGGER trigger_matchescandidatures_update AFTER UPDATE ON bdproject.matchcandidatures FOR EACH ROW EXECUTE PROCEDURE bdproject.proc_trigger_matchcandidatures_update();


--
-- Name: TRIGGER trigger_matchescandidatures_update ON matchcandidatures; Type: COMMENT; Schema: bdproject; Owner: postgres
--

COMMENT ON TRIGGER trigger_matchescandidatures_update ON bdproject.matchcandidatures IS 'La  candidature  della  squadra  viene  confermata  solo  se  il  numero  minimo  di  iscritti  alla  squadra  è  stato  raggiunto  e  non  si  è  superato  il  numero  massimo  di  giocatori  per  quella  categoria.Inoltre la conferma avviene solo se ci sono ancora slot squadre disponibili per la partita. Se si è raggiunto il numero massimo la partita viene chiusaControlla anche che nessuno utente faccia parte di due squadre contemporaneamente per lo stesso evento.';


--
-- Name: outcomes trigger_outcomes_insert_update; Type: TRIGGER; Schema: bdproject; Owner: postgres
--

CREATE TRIGGER trigger_outcomes_insert_update AFTER INSERT OR UPDATE ON bdproject.outcomes FOR EACH ROW EXECUTE PROCEDURE bdproject.proc_trigger_outcomes_insert_update();


--
-- Name: TRIGGER trigger_outcomes_insert_update ON outcomes; Type: COMMENT; Schema: bdproject; Owner: postgres
--

COMMENT ON TRIGGER trigger_outcomes_insert_update ON bdproject.outcomes IS 'Controlla che l''update o l''inserimento di un risultato venga effettuato dall''
 ''admin e che al momento dell''inserimento/update la partita sia chiusa.Vengono infine aggiornati i numeri di partite eseguite dagli utenti.';


--
-- Name: refereecandidatures trigger_refereecandidatures_insert; Type: TRIGGER; Schema: bdproject; Owner: postgres
--

CREATE TRIGGER trigger_refereecandidatures_insert AFTER INSERT ON bdproject.refereecandidatures FOR EACH ROW EXECUTE PROCEDURE bdproject.proc_trigger_refereecandidatures_insert();


--
-- Name: TRIGGER trigger_refereecandidatures_insert ON refereecandidatures; Type: COMMENT; Schema: bdproject; Owner: postgres
--

COMMENT ON TRIGGER trigger_refereecandidatures_insert ON bdproject.refereecandidatures IS 'Controlla che l''inserimento non assegni autonomamente l''arbitro';


--
-- Name: refereecandidatures trigger_refereecandidatures_update; Type: TRIGGER; Schema: bdproject; Owner: postgres
--

CREATE TRIGGER trigger_refereecandidatures_update AFTER UPDATE ON bdproject.refereecandidatures FOR EACH ROW EXECUTE PROCEDURE bdproject.proc_trigger_refereecandidatures_update();


--
-- Name: TRIGGER trigger_refereecandidatures_update ON refereecandidatures; Type: COMMENT; Schema: bdproject; Owner: postgres
--

COMMENT ON TRIGGER trigger_refereecandidatures_update ON bdproject.refereecandidatures IS 'Controlla che non sia assegnato già un arbitro alla partita';


--
-- Name: teamcandidatures trigger_teamcandidatures_insert; Type: TRIGGER; Schema: bdproject; Owner: postgres
--

CREATE TRIGGER trigger_teamcandidatures_insert AFTER INSERT ON bdproject.teamcandidatures FOR EACH ROW EXECUTE PROCEDURE bdproject.proc_trigger_teamcandidatures_insert();


--
-- Name: teamcandidatures trigger_teamcandidatures_update; Type: TRIGGER; Schema: bdproject; Owner: postgres
--

CREATE TRIGGER trigger_teamcandidatures_update AFTER UPDATE ON bdproject.teamcandidatures FOR EACH ROW EXECUTE PROCEDURE bdproject.proc_trigger_teamcandidatures_update();


--
-- Name: tournaments trigger_tournaments_insert; Type: TRIGGER; Schema: bdproject; Owner: postgres
--

CREATE TRIGGER trigger_tournaments_insert AFTER INSERT ON bdproject.tournaments FOR EACH ROW EXECUTE PROCEDURE bdproject.proc_trigger_tournaments_insert();


--
-- Name: tournamentscandidatures trigger_tournamentscandidatures_insert; Type: TRIGGER; Schema: bdproject; Owner: postgres
--

CREATE TRIGGER trigger_tournamentscandidatures_insert AFTER INSERT ON bdproject.tournamentscandidatures FOR EACH ROW EXECUTE PROCEDURE bdproject.proc_trigger_tournamentscandidatures_insert();


--
-- Name: tournamentscandidatures trigger_tournamentscandidatures_update; Type: TRIGGER; Schema: bdproject; Owner: postgres
--

CREATE TRIGGER trigger_tournamentscandidatures_update AFTER UPDATE ON bdproject.tournamentscandidatures FOR EACH ROW EXECUTE PROCEDURE bdproject.proc_trigger_tournamentscandidatures_update();


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
-- Name: fora fora_categories_name_fk; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.fora
    ADD CONSTRAINT fora_categories_name_fk FOREIGN KEY (category) REFERENCES bdproject.categories(name);


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
-- Name: matches matches_categories_name_fk; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.matches
    ADD CONSTRAINT matches_categories_name_fk FOREIGN KEY (category) REFERENCES bdproject.categories(name);


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
-- Name: outcomes outcomes_teams_name_fk; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.outcomes
    ADD CONSTRAINT outcomes_teams_name_fk FOREIGN KEY (team) REFERENCES bdproject.teams(name) ON DELETE CASCADE;


--
-- Name: categories photo; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.categories
    ADD CONSTRAINT photo FOREIGN KEY (photo) REFERENCES bdproject.photos(id);


--
-- Name: posts posts_category_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.posts
    ADD CONSTRAINT posts_category_fkey FOREIGN KEY (category) REFERENCES bdproject.categories(name) ON UPDATE CASCADE ON DELETE SET NULL;


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
-- Name: teams teams_categories_name_fk; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.teams
    ADD CONSTRAINT teams_categories_name_fk FOREIGN KEY (category) REFERENCES bdproject.categories(name);


--
-- Name: tournaments tournaments_buildings_name_fk; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.tournaments
    ADD CONSTRAINT tournaments_buildings_name_fk FOREIGN KEY (building) REFERENCES bdproject.buildings(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: tournaments tournaments_categories_name_fk; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.tournaments
    ADD CONSTRAINT tournaments_categories_name_fk FOREIGN KEY (category) REFERENCES bdproject.categories(name);


--
-- Name: tournaments tournaments_manager_fkey; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.tournaments
    ADD CONSTRAINT tournaments_manager_fkey FOREIGN KEY (manager) REFERENCES bdproject.users(username) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: tournaments tournaments_teams_name_fk; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.tournaments
    ADD CONSTRAINT tournaments_teams_name_fk FOREIGN KEY (winner) REFERENCES bdproject.teams(name) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: tournamentscandidatures tournamentscandidatures_teams_name_fk; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.tournamentscandidatures
    ADD CONSTRAINT tournamentscandidatures_teams_name_fk FOREIGN KEY (team) REFERENCES bdproject.teams(name);


--
-- Name: tournamentscandidatures tournamentscandidatures_tournaments_name_fk; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.tournamentscandidatures
    ADD CONSTRAINT tournamentscandidatures_tournaments_name_fk FOREIGN KEY (tournament) REFERENCES bdproject.tournaments(name);


--
-- Name: tournamentscandidatures tournamentscandidatures_users_username_fk; Type: FK CONSTRAINT; Schema: bdproject; Owner: postgres
--

ALTER TABLE ONLY bdproject.tournamentscandidatures
    ADD CONSTRAINT tournamentscandidatures_users_username_fk FOREIGN KEY (confirmed) REFERENCES bdproject.users(username);


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
-- Name: SCHEMA bdproject; Type: ACL; Schema: -; Owner: andreo
--

GRANT ALL ON SCHEMA bdproject TO strafo;


--
-- PostgreSQL database dump complete
--

