with
  allrtis as (
    select distinct rti
    from ccids
    inner join rtis
    on ccids.ccid = rtis.ccid )
, nostd as (
    select ccid
    from allrtis
    except
    select 'STD' )
, ortherrti as (
    select ccid
    from nostd
    except
    select 'APL' )
, logins as (
    select ccids.ccid, rtis.rti
    from ccids
    inner join rtis
    on ccids.ccid = rtis.ccid )
, apllogins as (
    select distinct ccid
    from logins
    where rti = 'APL' )
, stdlogins as (
    select distinct ccid
    from logins
    where rti = 'STD' )
, noccid as (
    select distinct ccid
    from ccids
    except
    select distinct ccid
    from rtis )
, noapllogins as (
    select distinct ccid
    from logins
    except
    select ccid
    from apllogins )
, nostdlogins as (
    select distinct ccid
    from logins
    except
    select ccid
    from stdlogins )
, otherlogins as (
    select distinct ccid
    from logins
    except
    select distinct ccid
    from logins
    where rti in ( 'STD', 'APL' ) )
, notonlyapllogins as (
    select distinct logins.ccid
    from apllogins
    left outer join logins
    on apllogins.ccid = logins.ccid
    where not rti = 'APL')
, notonlystdlogins as (
    select distinct logins.ccid
    from stdlogins
    left outer join logins
    on stdlogins.ccid = logins.ccid
    where not rti = 'STD' )
, stdonlylogins as (
    select distinct ccid
    from stdlogins
    except
    select distinct ccid
    from notonlystdlogins )
, aplonlylogins as (
    select distinct ccid
    from apllogins
    except
    select distinct ccid
    from notonlyapllogins )
, stdapllogins as (
    select distinct stdlogins.ccid
    from stdlogins
    inner join apllogins
    on stdlogins.ccid = apllogins.ccid )
select count(*) from logins as nr_total_logins
union
select count(*) from noccid nr_noccid
union
select count(*) from apllogins as nr_apl
union
select count(*) from stdlogins as nr_std
union
select count(*) from otherlogins as nr_other
union
select count(*) from aplonlylogins as nr_aplonly
union
select count(*) from stdonlylogins as nr_stdonly
union
select count(*) from noapllogins as nr_noapl
union
select count(*) from nostdlogins as nr_nostd;
