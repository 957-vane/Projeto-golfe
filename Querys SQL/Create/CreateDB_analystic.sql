-----------------------------------------------------------------------------------------------------------------------------
-- Criar Schema camada analystic 
-----------------------------------------------------------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS analytics;

-----------------------------------------------------------------------------------------------------------------------------
-- Criação da tabela dim_zone
-----------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS analytics.dim_zone (
	zone_id 		INTEGER 	PRIMARY KEY,
	zone_name 		TEXT,
	created_at 		TIMESTAMP 	DEFAULT CURRENT_TIMESTAMP
);

--Inserir dados a tabela zona 
INSERT INTO analytics.dim_zone(zone_id, zone_name)
VALUES 
    (1,'Zona 1'),
    (2,'Zona 2'),
    (3,'Zona 3'),
    (4,'Zona 4'),
    (5,'Zona 5'),
    (6,'Zona 6');


-----------------------------------------------------------------------------------------------------------------------------
-- Criação da tabela dim_parcel
-----------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS analytics.dim_parcel (
	parcel_id 				INTEGER 	PRIMARY KEY,
	zone_id 				INTEGER 	REFERENCES analytics.dim_zone(zone_id),
	parcel_name_original 	TEXT,
	parcel_name_normalized 	TEXT,
	parcel_type 			TEXT,
	notes 					TEXT
);

--Inserir dados a dim_parcel
INSERT INTO analytics.dim_parcel (
    parcel_id, 
    zone_id, 
    parcel_name_original, 
    parcel_name_normalized, 
    parcel_type, 
    notes
)
WITH raw_combined AS (
    SELECT parcel_name AS original FROM raw.raw_microbiology
    UNION ALL
    SELECT parcel_name AS original FROM raw.raw_soil_fq
),
mapping AS (
    SELECT 
        original,
        COALESCE(substring(original FROM '\d+')::INTEGER, 0) as extracted_id,
        CASE 
            WHEN UPPER(original) LIKE '%ADJACENTE%' THEN 'Adjacente'
            ELSE 'Green' 
        END as extracted_type,
        CASE 
            WHEN UPPER(original) LIKE '%FALDO%' THEN 'Faldo'
            WHEN UPPER(original) LIKE '%O''CONNER%' OR UPPER(original) LIKE '%CONNER%' THEN 'O''Conner'
            ELSE 'Outro'
        END as extracted_course
    FROM raw_combined
    WHERE original IS NOT NULL
),
normalized_logic AS (
    SELECT 
        original,
        extracted_id as zone_id,
        extracted_type as parcel_type,
        extracted_course || ' - ' || extracted_id || ' ' || extracted_type as normalized_name
    FROM mapping
)
SELECT 
    DENSE_RANK() OVER (ORDER BY zone_id, normalized_name)::INTEGER as parcel_id,
    zone_id,
    STRING_AGG(DISTINCT original, ' | ' ORDER BY original) as parcel_name_original,
    normalized_name as parcel_name_normalized,
    parcel_type,
    ''::TEXT as notes
FROM normalized_logic
GROUP BY zone_id, normalized_name, parcel_type
ORDER BY zone_id, normalized_name;

/*===========================================================================================================================
Criação da tabela dim_sample
===========================================================================================================================*/
CREATE TABLE IF NOT EXISTS analytics.dim_sample (
	sample_id 			SERIAL 		PRIMARY KEY,
	sample_code 		TEXT 		UNIQUE, 
	parcel_id 			INTEGER 	REFERENCES analytics.dim_parcel(parcel_id),
	sample_type 		TEXT,
	sample_date 		DATE ,
	client_name 		TEXT,
	source_system 		TEXT
);

--Inserir dados 
INSERT INTO analytics.dim_sample (
    sample_code, 
    parcel_id, 
    sample_type, 
    sample_date, 
    client_name, 
    source_system
)
WITH raw_combined AS (
    --microbiologia
    SELECT 
        TRIM(m.sample_code) as s_code,
        m.parcel_name as raw_p_name,
        m.sample_type as s_type,
        CASE 
            WHEN m.pull_date ~ '^\d{4}-\d{2}-\d{2}$' THEN m.pull_date::DATE 
            ELSE NULL 
        END as s_date,
        m.client_info as s_client,
        'microbiology' as s_source
    FROM raw.raw_microbiology m

    UNION ALL

    --solo_fq
    SELECT 
        TRIM(s.sample_code) as s_code,
        s.parcel_name as raw_p_name,
        'Soil' as s_type, 
        CASE 
            WHEN s.sample_date ~ '^\d{2}/\d{2}/\d{4}$' THEN TO_DATE(s.sample_date, 'DD/MM/YYYY')
            ELSE NULL 
        END as s_date,
        NULL as s_client,
        'soil_fq' as s_source
    FROM raw.raw_soil_fq s
),
deduplicated AS (
    SELECT 
        r.s_code as sample_code,
        MAX(p.parcel_id) as parcel_id,
        MAX(r.s_type) as sample_type,
        MAX(r.s_date) as sample_date,
        MAX(r.s_client) as client_name,
        CASE 
            WHEN COUNT(DISTINCT r.s_source) > 1 THEN 'both' 
            ELSE MAX(r.s_source) 
        END as source_system
    FROM raw_combined r
    LEFT JOIN analytics.dim_parcel p 
      ON r.raw_p_name = ANY(string_to_array(p.parcel_name_original, ' | '))
    GROUP BY r.s_code
)
SELECT 
    sample_code,
    parcel_id,
    sample_type,
    sample_date,
    client_name,
    source_system
FROM deduplicated
ORDER BY sample_date ASC;

-----------------------------------------------------------------------------------------------------------------------------
-- Criação da tabela dim_microbiology_group
-----------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS analytics.dim_microbiology_group (
    metric_group_id 		SERIAL 		PRIMARY KEY,
    metric_group_name 		TEXT	 	UNIQUE NOT NULL,
    created_at 				TIMESTAMP 	DEFAULT CURRENT_TIMESTAMP
);

--inserir dados em dim_microbiology_group
INSERT INTO analytics.dim_microbiology_group (metric_group_name)
SELECT DISTINCT TRIM(metric_group) 
FROM raw.raw_microbiology
WHERE metric_group IS NOT NULL AND metric_group != '';


-----------------------------------------------------------------------------------------------------------------------------
-- Criação da tabela dim_soil_parameter
-----------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS analytics.dim_soil_parameter (
	parameter_id 		SERIAL 		PRIMARY KEY,
	parameter_name 		TEXT
);

--Inserir dados na tabela dim_soil_parameter
INSERT INTO analytics.dim_soil_parameter(parameter_name)
SELECT DISTINCT(parameter_name)
FROM raw.raw_soil_fq

-----------------------------------------------------------------------------------------------------------------------------
-- Criação da tabela fact_soil_parameter 
-----------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS analytics.fact_soil_parameter(
	fact_id 			SERIAL 			PRIMARY KEY, 
	sample_id 			INTEGER 		REFERENCES analytics.dim_sample(sample_id),
	parameter_id 		INTEGER 		REFERENCES analytics.dim_soil_parameter(parameter_id),
	parameter_value 	NUMERIC(15,2),
	parameter_unit 		TEXT,
	interpretation 		TEXT
);

--inserir dados 
INSERT INTO analytics.fact_soil_parameter (
    sample_id, 
    parameter_id, 
    parameter_value, 
    parameter_unit, 
    interpretation
)
SELECT 
    s.sample_id,
    soi.parameter_id,
    CASE 
        --converte se o valor for numerico
        --ignora qualquer valor que contenha ":" que são dados invalidos
        WHEN TRIM(REPLACE(r.parameter_value, ',', '.')) ~ '^[0-9]+(\.[0-9]+)?$' 
             AND TRIM(r.parameter_value) NOT LIKE '%:%'
        THEN CAST(TRIM(REPLACE(r.parameter_value, ',', '.')) AS NUMERIC(15,2))
        ELSE NULL 
    END AS parameter_value,
    r.parameter_unit,
    r.interpretation
FROM raw.raw_soil_fq r
INNER JOIN analytics.dim_sample s ON TRIM(r.sample_code) = s.sample_code
INNER JOIN analytics.dim_soil_parameter soi ON r.parameter_name = soi.parameter_name
WHERE r.parameter_value IS NOT NULL AND r.parameter_value != '';


-----------------------------------------------------------------------------------------------------------------------------
-- Criação da tabela dim_vegetation_stat 
-----------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS analytics.dim_vegetation_stat (
	stat_id 		SERIAL 		PRIMARY KEY,
	stat_name 		TEXT 		UNIQUE
);

--Inserir dados a tabela 
INSERT INTO analytics.dim_vegetation_stat (stat_name)
VALUE 
		('area'),
		('min_val'),
		('max_value'),
		('mean_value'),
		('median_value'),
		('std_value'),
		('pct90_value'),
		('sum_value'),
		('range_value')
;
		

-----------------------------------------------------------------------------------------------------------------------------
-- Criação da tabela fact_microbiology_metric 
-----------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS analytics.fact_microbiology_metric(
	fact_id 			SERIAL 			PRIMARY KEY,
	sample_id 			INTEGER 		REFERENCES analytics.dim_sample(sample_id), 
	metric_group_id 	INTEGER 		REFERENCES analystic.dim_microbiology_group(metric_group_id),
	metric_name 		TEXT,
	metric_value 		NUMERIC(15,2)
);

--inserir dados 
INSERT INTO analytics.fact_microbiology_metric (
    sample_id, 
    metric_group_id, 
    metric_name, 
    metric_value
)
SELECT 
    s.sample_id,
    dg.metric_group_id, -- Apenas o ID!
    m.metric_name,
    CASE 
        WHEN TRIM(REPLACE(m.metric_value, ',', '.')) ~ '^[0-9]+(\.[0-9]+)?$' 
        THEN CAST(TRIM(REPLACE(m.metric_value, ',', '.')) AS NUMERIC(15,2))
        ELSE NULL 
    END AS metric_value
FROM raw.raw_microbiology m
INNER JOIN analytics.dim_sample s 				ON TRIM(m.sample_code) = s.sample_code
INNER JOIN analytics.dim_microbiology_group dg 	ON TRIM(m.metric_group) = dg.metric_group_name
WHERE m.metric_value IS NOT NULL AND m.metric_value != '';

-----------------------------------------------------------------------------------------------------------------------------
-- Criação da tabela fact_vegetation_stat 
-----------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS analytics.fact_vegetation_stat (
	fact_id 			SERIAL		 	PRIMARY KEY,
	zone_id 			INTEGER 		REFERENCES analytics.dim_zone(zone_id),
	stat_id 			INT 			REFERENCES analytics.dim_vegetation_stat(stat_id),
	stat_value 			NUMERIC(20,10),
	stat_date 			TIMESTAMP,
	source_system 		TEXT
);



--Inserir dados 
INSERT INTO analytics.fact_vegetation_stat (
    zone_id, 
    stat_id, 
    stat_value, 
    stat_date, 
    source_system
)
SELECT 
    dz.zone_id,
    dv.stat_id,
    CAST(NULLIF(REPLACE(u.stat_value, ',', '.'), '') AS NUMERIC(20,10)),
    r.loaded_at::TIMESTAMP,
    'satellite_system'
FROM raw.raw_vegetation_stats r
CROSS JOIN LATERAL unnest(
    -- Mapeamento dos nomes das metricas
    array[
        'area', 'max_value', 'mean_value', 'median_value', 
        'min_value', 'pct90_value', 'range_value', 'std_value', 'sum_value'
    ],
    -- Mapeamento das colunas da tabela RAW
    array[
        r.area::text, r.max_value::text, r.mean_value::text, r.median_value::text, 
        r.min_value::text, r.pct90_value::text, r.range_value::text, r.std_value::text, r.sum_value::text
    ]
) AS u(stat_name, stat_value)
-- Garante integridade referencial com a dimensão de zonas
INNER JOIN analytics.dim_zone dz 				ON CAST(r.zone_id AS INTEGER) = dz.zone_id
INNER JOIN analytics.dim_vegetation_stat dv 	ON dv.stat_name = u.stat_name
WHERE u.stat_value IS NOT NULL;


-----------------------------------------------------------------------------------------------------------------------------
-- Criação da tabela dim_irrigation_zone
-----------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS analytics.dim_irrigation_zone (
    irrigation_zone_id 					SERIAL 			PRIMARY KEY,
    zone_name_original 					TEXT 			NOT NULL,
    irrigation_zone_name_normalized 	TEXT,
    zone_type 							TEXT,              
    zone_id 							INT 			REFERENCES analytics.dim_zone(zone_id),
    notes 								TEXT
);

-- Inserir dados 
INSERT INTO analytics.dim_irrigation_zone (zone_name_original, zone_name_normalized, zone_type
)
WITH zone_normalized AS (
SELECT DISTINCT(group_name) AS zone_name_original, 
	CASE 
		WHEN UPPER(group_name) LIKE '%ESTUFA GRA%' THEN 'Estufa Gra'
		WHEN UPPER(group_name) LIKE '%SET%' THEN 'Setor'
		WHEN UPPER(group_name) LIKE '%BLOCO%' THEN 'Bloco'
		ELSE 'Outro'
	END AS zone_name_normalized, 
	CASE 
		WHEN (group_name) ILIKE '%ESTUFA%' THEN 'Estufa'
		WHEN (group_name) ILIKE '%SET%' THEN 'Setor'
		WHEN (group_name) ILIKE '%BLOCO%' THEN 'Bloco'
		ELSE 'Outro'
	END AS zone_type
FROM raw.raw_irrigation_event 
WHERE group_name IS NOT NULL )
SELECT * FROM zone_normalized;

-----------------------------------------------------------------------------------------------------------------------------
-- Criação da tabela fact_irrigation_event
-----------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS analytics.fact_irrigation_event (
    fact_id 				BIGSERIAL 			PRIMARY KEY,
    irrigation_zone_id 		INT 				REFERENCES analytics.dim_irrigation_zone(irrigation_zone_id),
    event_date 				DATE,
    start_timestamp 		TIMESTAMP,
    end_timestamp 			TIMESTAMP,
    duration_seconds 		TIME,
    mcu 					TEXT,
    event_number 			INT,
    irrigation_number 		INT,
    mode 					TEXT,
    ec_setpoint 			NUMERIC,
    ec_measured			 	NUMERIC,
    ph_setpoint 			NUMERIC,
    ph_measured 			NUMERIC,
    volume_applied 			NUMERIC,
    drainage_volume 		NUMERIC,
    drainage_pct 			NUMERIC,
    drain_ec_measured 		NUMERIC,
    drain_ph_measured 		NUMERIC,
    source_system 			TEXT,
    loaded_at 				TIMESTAMP 			DEFAULT NOW()
);

--Inserir dados 
INSERT INTO analytics.fact_irrigation_event (
    fact_id, irrigation_zone_id, event_date, start_timestamp, end_timestamp, 
    duration_seconds, mcu, event_number, irrigation_number, mode,
    ec_setpoint, ec_measured, ph_setpoint, ph_measured, volume_applied, 
    drainage_volume, drainage_pct, drain_ec_measured, drain_ph_measured, 
    source_system, loaded_at
)
WITH irrigation_event_cte AS (
    SELECT
        r.raw_irrigation_id,
        z.irrigation_zone_id,
        r.event_date,
        -- Convertendo data + texto para TIMESTAMP
        (r.event_date + r.start_time::time) AS start_ts,
        (r.event_date + r.end_time::time) AS end_ts,
        -- Convertendo rest_time (texto) para INTERVAL e depois pegando os segundos
        EXTRACT(EPOCH FROM r.rest_time::interval)::integer AS duration_seconds,
        r.mcu,
        r.event_number::integer AS event_number,
        r.irrigation_number,
        r.mode,
        r.ec_instruction,
        r.ec_measured,
        r.ph_instruction,
        r.ph_measured,
        r.volume_applied,
        r.drainage_volume,
        r.drainage_pct,
        r.drain_ec_measured,
        r.drain_ph_measured,
        r.source_file,
        r.loaded_at
    FROM raw.raw_irrigation_event r
    LEFT JOIN analytics.dim_irrigation_zone z ON z.zone_name_original = r.group_name
)
SELECT 
    raw_irrigation_id, 
    irrigation_zone_id, 
    event_date, 
    start_ts, 
    end_ts, 
    (duration_seconds || ' seconds')::interval AS duration_formatted,
    mcu, 
    event_number, 
    irrigation_number,
    mode, 
    ec_instruction, 
    ec_measured, 
    ph_instruction, 
    ph_measured, 
    volume_applied, 
    drainage_volume, 
    drainage_pct,
    drain_ec_measured, 
    drain_ph_measured, 
    source_file, 
    loaded_at
FROM irrigation_event_cte


-----------------------------------------------------------------------------------------------------------------------------
-- Criação da tabela dim_data_source
-----------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS analytics.dim_data_source(
	data_source_id 			SERIAL 			PRIMARY KEY,
	source_name 			TEXT 			UNIQUE, 
	source_type 			TEXT, 
	source_endpoint 		TEXT 
);


-----------------------------------------------------------------------------------------------------------------------------
-- Criação da tabela dim_station
-----------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS analytics.dim_station(
	station_id 				SERIAL 			PRIMARY KEY,
	station_code 			TEXT 			UNIQUE, 
	station_name 			TEXT, 
	data_source_id 			INT 			REFERENCES analytics.dim_data_source(data_source_id)
);

-----------------------------------------------------------------------------------------------------------------------------
-- Criação da tabela dim_weather_parameter
-----------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS analytics.dim_weather_parameter(
	parameter_id 		    SERIAL 			PRIMARY KEY,
	field_code 				TEXT,
	parameter_name 			TEXT 			UNIQUE,
	parameter_unit 			TEXT
);

--Inserir dados a tabela 
INSERT INTO analytics.dim_weather_parameter (field_code, parameter_name, parameter_unit) 
VALUES
	('field1', 'PAR',              'µmol/m²/s'),
	('field2', 'Temperatura',      '°C'),
	('field3', 'Humidade',         '%'),
	('field4', 'VPD',              'kPa'),
	('field5', 'Folha molhada',    ''),
	('field6', 'Vento (velocidade)', 'm/s'),
	('field7', 'Direção do vento',    '°'),
	('field8', 'Precipitação',     'mm');
	
-----------------------------------------------------------------------------------------------------------------------------
-- Criação da tabela fact_weather_observation
-----------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS analytics.fact_weather_observation(
	fact_id 			BIGSERIAL 			PRIMARY KEY, 
	station_id 			INT 				REFERENCES analytics.dim_station(station_id),
	data_source_id 		INT 				REFERENCES analytics.dim_data_source(data_source_id),
    observed_at 		TIMESTAMP,
    parameter_id 		INT 				REFERENCES analytics.dim_weather_parameter(parameter_id),
    parameter_value 	NUMERIC,
    parameter_unit 		TEXT,
    loaded_at 			TIMESTAMP 			DEFAULT NOW(),

	 CONSTRAINT unique_observation UNIQUE (station_id, observed_at, parameter_id)
);


