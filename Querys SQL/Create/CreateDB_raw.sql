-----------------------------------------------------------------------------------------------------------------------------
-- Criação da base de dados 
-----------------------------------------------------------------------------------------------------------------------------
CREATE DATABASE Smartsoil;

-----------------------------------------------------------------------------------------------------------------------------
-- Criar Schema camada RAW 
-----------------------------------------------------------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS raw;

-----------------------------------------------------------------------------------------------------------------------------
-- Criação das tabelas da Base de Dados camada Raw

-- Tabela raw_microbiology
-- 	 Notas:
-- 	 » raw_id com números e letras conforme ficheiro 
-- 	 » loaded_at Default retornar data e hora do sistema 
-----------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.raw_microbiology(
	raw_id 					TEXT,  
	sample_code 			TEXT,
	client_info 			TEXT,
	sample_type 			TEXT,
	parcel_name 			TEXT,
	pull_date 				TEXT, 
	received_in_lab 		TEXT, 
	finished_in_lab 		TEXT,
	report_date 			TEXT,
	sample_report_version 	TEXT,
	sample_name 			TEXT ,
	metric_name 			TEXT ,
	metric_value 			TEXT,
	metric_group 			TEXT,
	loaded_at 				TIMESTAMP 	DEFAULT CURRENT_TIMESTAMP,
	source_file 			TEXT 		DEFAULT 'raw_microbiology.csv'
);

-----------------------------------------------------------------------------------------------------------------------------
-- Criação da tabela raw_soil_fq
-- 	 Notas:
-- 	 »loaded_at Default retornar data e hora do sistema
-----------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.raw_soil_fq (
	raw_id 			INTEGER, 
	sample_code 	TEXT,
	sample_date 	TEXT,
	parcel_name 	TEXT,
	parameter_name 	TEXT,
	method 			TEXT, 
	parameter_value TEXT,
	interpretation 	TEXT,
	parameter_unit 	TEXT,
	recommendations TEXT,
	loaded_at 		TIMESTAMP 		DEFAULT CURRENT_TIMESTAMP,
	source_file 	TEXT 			DEFAULT 'raw_soil_fq.csv'
);

-----------------------------------------------------------------------------------------------------------------------------
-- Criação da tabela raw_vegetation_stats
-----------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.raw_vegetation_stats (
	raw_id 			INTEGER, 
	zone_id 		TEXT,
	count_value 	TEXT,
	area 			TEXT,
	min_value 		TEXT,
	max_value 		TEXT,
	mean_value 		TEXT,
	median_value 	TEXT,
	std_value 		TEXT,
	pct90_value 	TEXT,
	sum_value 		TEXT,
	range_value 	TEXT,
	geometry 		TEXT,
	loaded_at 		TIMESTAMP 		DEFAULT CURRENT_TIMESTAMP,
	source_file 	TEXT 			DEFAULT 'raw_vegetation_stats.csv'
);

-----------------------------------------------------------------------------------------------------------------------------
-- Criação da tabela raw_irrigation_event
-----------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.raw_irrigation_event (
    raw_irrigation_id 	BIGSERIAL 		PRIMARY KEY,
    event_date 			DATE,
    start_time 			TIME,
    end_time 			TIME,
    rest_time 			TEXT,
    mcu 				TEXT,
    event_number 		NUMERIC,
    group_name 			TEXT,
    irrigation_number 	NUMERIC,
    mode 				TEXT,
    ec_instruction 		NUMERIC,
    ec_measured 		NUMERIC,
    ph_instruction 		NUMERIC,
    ph_measured 		NUMERIC,
    duration_text 		TEXT,
    volume_applied 		NUMERIC,
    drainage_volume 	NUMERIC,
    drainage_pct 		NUMERIC,
    drain_ec_measured 	NUMERIC,
    drain_ph_measured 	NUMERIC,
	source_file 		TEXT 			NOT NULL DEFAULT 'raw_irrigation_event.csv',
    loaded_at 			TIMESTAMP 		DEFAULT now()
);

-----------------------------------------------------------------------------------------------------------------------------
--	Criação da tabela raw_weather_observation
-----------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.raw_weather_observation (
	raw_id 			BIGSERIAL, 
	source_name 	TEXT,
	source_type 	TEXT,
	source_endpoint TEXT,
	station_code 	TEXT, 
	observed_at 	TIMESTAMP,
    field_name 		TEXT,
    field_value 	TEXT,
    source_payload 	JSONB,
    loaded_at 		TIMESTAMP 			DEFAULT NOW(),
	
);


-----------------------------------------------------------------------------------------------------------------------------
--	Criação da tabela raw_zonas_campo
-----------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.raw_zonas_campo (
	zona_id 		SERIAL 			PRIMARY KEY,
	campo_id 		INTEGER 		NOT NULL,
	nome 			VARCHAR(100),
	tipo 			VARCHAR(50),
	geom GEOMETRY	(Polygon, 4326),
	criado_em 		TIMESTAMP 		DEFAULT NOW()
);

--Índice Espacial obrigatório para a performance 
CREATE INDEX idx_zonas_geom ON raw.raw_zonas_campo USING GIST (geom);



-----------------------------------------------------------------------------------------------------------------------------
--	Criação da tabela raw_ndvi_leituras
-----------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.raw_ndvi_leituras (
	id 				SERIAL 			PRIMARY KEY,
	zona_id 		INTEGER 		REFERENCES raw.raw_zonas_campo(zona_id),
	data_leitura 	DATE 			NOT NULL,
	ndvi_valor 		NUMERIC(5,4),
	fonte 			VARCHAR(50),
	criado_em 		TIMESTAMP 		DEFAULT NOW()
);

--Criar INDEX 
CREATE INDEX idx_ndvi_zona ON raw.raw_ndvi_leituras(zona_id);
CREATE INDEX idx_ndvi_data ON raw.raw_ndvi_leituras(data_leitura);














