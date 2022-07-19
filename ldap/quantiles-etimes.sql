with x as ( 
 select etime
      , ntile(10)
  over ( order by etime ) qtile 
  from stat 
  where etime > 1.0 )
select distinct qtile
         , min(etime) over ( partition by qtile ) mi
         , max(etime) over (partition by qtile) ma
         , count(*) over (partition by qtile) ct
from x;
