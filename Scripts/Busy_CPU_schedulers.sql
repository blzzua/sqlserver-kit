/* determine busiest cpu, and SOS_SCHEDULER_YIELD problem https://sqlundercover.com/2020/02/26/sos_scheduler_yield-what-is-it-really-telling-us/ */ 
-- select * from sys.dm_os_schedulers
if object_id('tempdb..#t1') is not null 
BEGIN
	print 'drop table #t1'
	drop table #t1
END
go 

if object_id('tempdb..#t2') is not null 
    begin
        select * into #t1 from #t2
		print 'drop table #t1'
        drop table #t2
    end 
go 

if ( object_id('tempdb..#t1') is null ) 
begin 
select getdate() as dt, cpu_id, scheduler_id,  
	sum(total_cpu_usage_ms) usage_ms,
	sum(preemptive_switches_count) as preemptive_switches_count,
	sum(context_switches_count) as context_switches_count,
	sum(idle_switches_count) as idle_switches_count,
	max(current_tasks_count) as current_tasks_count,
	max(runnable_tasks_count) as runnable_tasks_count
	into #t1
from sys.dm_os_schedulers
where scheduler_id< 500 
group by cpu_id,scheduler_id

waitfor delay '00:00:10'	
end
go 


select getdate() as dt, cpu_id, scheduler_id,  
	sum(total_cpu_usage_ms) usage_ms,
	sum(preemptive_switches_count) as preemptive_switches_count,
	sum(context_switches_count) as context_switches_count,
	sum(idle_switches_count) as idle_switches_count,
	max(current_tasks_count) as current_tasks_count,
	max(runnable_tasks_count) as runnable_tasks_count
	into #t2
from sys.dm_os_schedulers
where scheduler_id< 500 
group by cpu_id,scheduler_id
go 

with cpu_usage as (
select 
		 f.cpu_id, 
		 f.scheduler_id,
		 max(datediff (s, s.DT, f.DT )) as datediff_sec,
         convert(numeric(18,2),sum(( f.usage_ms- s.usage_ms) * 1000.0 / datediff (ms, s.DT, f.DT ) )) as usage_ms /*average per sec*/ 
from 
         #t1 as s,  -- start
         #t2 as f   -- finish
where  s.cpu_id = f.cpu_id 
    group by f.cpu_id, f.scheduler_id
	)
select min(usage_ms) as min_, max(usage_ms) as max_, max(datediff_sec) as datediff_sec
from cpu_usage
where usage_ms > 1



select  
	top 100
		 f.cpu_id, f.scheduler_id,
         convert(numeric(18,2),sum(( f.usage_ms- s.usage_ms) * 1000.0 / datediff (ms, s.DT, f.DT ) )) as usage_ms /*average per sec*/, 
		 convert(numeric(18,2),sum(( f.preemptive_switches_count- s.preemptive_switches_count) * 1000.0 / datediff (ms, s.DT, f.DT ) )) as preemptive_switches_count ,
		 convert(numeric(18,2),sum(( f.context_switches_count- s.context_switches_count) * 1000.0 / datediff (ms, s.DT, f.DT ) )) as context_switches_count ,
		 convert(numeric(18,2),sum(( f.idle_switches_count- s.idle_switches_count) * 1000.0 / datediff (ms, s.DT, f.DT ) )) as idle_switches_count ,
		 max(f.current_tasks_count) as current_tasks_count,
		 max(f.runnable_tasks_count) as runnable_tasks_count
from 
         #t1 as s,  -- start
         #t2 as f   -- finish
where  s.cpu_id = f.cpu_id 
    group by f.cpu_id,  f.scheduler_id
	order by usage_ms  desc 

	 
select scheduler_id as cpu, last_wait_type as  _last_wait_type,  *  from sys.dm_exec_requests where 
	scheduler_id in (select  f.scheduler_id from #t1 as s, #t2 as f where  s.cpu_id = f.cpu_id group by f.cpu_id,  f.scheduler_id having convert(numeric(18,2),sum(( f.usage_ms- s.usage_ms) * 1000.0 / datediff (ms, s.DT, f.DT ) ))  > 990)
	and  (command <> 'XTP_THREAD_POOL' or database_id > 0)
order by cpu

