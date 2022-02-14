-- #region
SELECT 
getdate() as DT , 
	datediff(ss,last_request_end_time, getdate()) as last_request_end,
	datediff(ss,last_request_start_time, getdate()) as last_request_start,
	'kill' as cmdkill,
	des.session_id, 
	datediff(ss, tat.transaction_begin_time, getdate() ) as tran_duration,
	right('0' + convert(varchar(2),datediff(ss, transaction_begin_time, getdate()) / 3600 ),2) + ':' +
	right('0' + convert(varchar(2),datediff(ss, transaction_begin_time, getdate()) / 60 % 60 ),2) + ':' +
	right('0' + convert(varchar(2),datediff(ss, transaction_begin_time, getdate()) %60 ),2)  as tran_duration_hms,
	des.host_name, 
	des.login_name, 
	convert(varchar(128), des.context_info) as context_info, 
	der_sql.text,
	der_plan.query_plan, 
	des.status as des_status,
	der.status as der_status, 
	des.cpu_time as des_cpu_time,
	der.cpu_time as der_cpu_time,
	des.memory_usage ,
	des.total_scheduled_time,	
	des.total_elapsed_time as des_total_elapsed_time,
	der.total_elapsed_time as der_total_elapsed_time,
	des.reads as des_reads,
	der.reads as der_reads,	des.writes	as des_writes,
	der.writes	as der_writes,
	des.logical_reads as des_logical_reads,
	der.logical_reads as der_logical_reads,
	des.last_request_start_time	,
	des.last_request_end_time	,
	des.open_transaction_count,
	der.blocking_session_id,
	der.scheduler_id,
	der.task_address,
 	der.command

FROM 
	sys.dm_exec_sessions des 
LEFT JOIN sys.dm_tran_session_transactions as tst on tst.session_id = des.session_id 
LEFT  JOIN sys.dm_tran_active_transactions  as tat on	tat.transaction_id=tst.transaction_id
LEFT  JOIN  sys.dm_exec_requests der on der.session_id = des.session_id
OUTER APPLY  sys.dm_exec_sql_text( der.sql_handle)    AS der_sql
OUTER APPLY sys.dm_exec_query_plan(der.plan_handle) AS der_plan
WHERE 1=1
		and  ( des.is_user_process = 1 and login_name != 'NT AUTHORITY\SYSTEM' )
    -- filter examples
	-- and des.session_id in ( select spid from sysprocesses where lastwaittype  = 'SOS_SCHEDULER_YIELD' and program_name = 'Microsoft Dynamics AX')
	-- IOWAIT:
	-- and des.session_id in (select spid  from sysprocesses  where lastwaittype like 'PAGEIOLATCH%' and waittime > 10000 )
	-- latchWAIT:
	-- and des.session_id in (select spid  from sysprocesses  where lastwaittype like '%LATCH%' and not lastwaittype like 'PAGEIO%' )
	-- and des.session_id in ( 123, 456 )
	-- and tat.transaction_begin_time < dateadd(ss, -3, getdate() )   --- only long tran
	-- and der_sql.text like '%SELECT SOMEFIELDS%'
    -- and host_name like 'SOME_HOST_NAME%'
    -- and login_name = 'DOMAIN\LOGIN' 
	-- and der.status ='suspended'
	-- and convert(varchar(128), des.context_info) like '%742%'
	 and 
	(
		not ( des.status = 'sleeping'  and der.status is NULL ) 
		or ( des.open_transaction_count > 0 )
	)
	and des.session_id != @@spid
		-- and der.blocking_session_id =0
order by transaction_begin_time
-- order by des.session_id 
-- order by last_request_start_time
-- order by text desc 
-- #endregion 
