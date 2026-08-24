-----------------------------------------------------------------------------------------------------------------------------
--	Importação dos dados em CSV para as tabelas do banco de dados 
-----------------------------------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------------------------------
-- Importação para a tabela raw_soil_fq
-----------------------------------------------------------------------------------------------------------------------------
COPY raw.raw_soil_fq (	raw_id, 
						sample_code, 
						sample_date, 
						parcel_name, 
						parameter_name, 
						method, 
						parameter_value, 
					 	interpretation, 
						parameter_unit,  
						recommendations, 
						loaded_at, 
						source_file )
FROM 'C:\csv\raw_soil_fq.csv'
DELIMITER ';' 
CSV HEADER;


-----------------------------------------------------------------------------------------------------------------------------
-- Importação para a tabela raw_vegetation_stats
-----------------------------------------------------------------------------------------------------------------------------
COPY raw.raw_vegetation_stats (	raw_id, 
								zone_id, 
								count_value, 
								area, 
								min_value, 
								max_value, 
								mean_value, 
								median_value, 
							    std_value, 
								pct90_value, 
								sum_value, 
								range_value, 
								geometry, 
								loaded_at, 
								source_file )
FROM 'C:\csv\raw_vegetation_stats.csv'
DELIMITER ';' 
CSV HEADER;


-----------------------------------------------------------------------------------------------------------------------------
-- Importação para a tabela raw_microbiology
-----------------------------------------------------------------------------------------------------------------------------
COPY raw.raw_microbiology ( raw_id, 
							sample_code, 
							client_info, 
							sample_type, 
							parcel_name, 
							pull_date, 
							received_in_lab,
						    finished_in_lab, 
							report_date, 
							sample_report_version, 
							sample_name, 
							metric_name, 
						    metric_value, 
							metric_group )
FROM 'C:\csv\raw_microbiology.csv'
DELIMITER ';' 
CSV HEADER;

-----------------------------------------------------------------------------------------------------------------------------
-- Importação para a tabela raw_irrigation_event
-----------------------------------------------------------------------------------------------------------------------------
		( raw_irrigation_id, 
		  event_date, 
		  start_time, 
		  end_time, 
		  rest_time, 
		  mcu, 
		  event_number,
		  group_name, 
		  irrigation_number, 
		  mode, 
		  ec_instruction, 
		  ec_measured, 
		  ph_instruction, 
		  ph_measured, 
		  duration_text, 
		  volume_applied, 
		  drainage_volume, 
		  drainage_pct, 
		  drain_ec_measured, 
		  drain_ph_measured,
		  source_file, 
		  loaded_at )
FROM 'C:\csv\raw_irrigation_event.csv'
DELIMITER ';' 
CSV HEADER;



