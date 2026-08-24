--VIEWS

-- Vista rega com nome da zona (Cenário B)
CREATE OR REPLACE VIEW analytics.v_irrigation_dashboard AS
SELECT
    fie.fact_id,
    fie.org_id,
    o.org_name,
    diz.irrigation_zone_name_normalized AS zone_name,
    dz.zone_type,
    fie.event_date,
    fie.start_timestamp,
    fie.end_timestamp,
    fie.duration_seconds,
    fie.volume_applied,
    fie.drainage_pct,
    fie.ec_measured,
    fie.ph_measured,
    fie.mode,
	fie.ec_setpoint,
	fie.ph_setpoint,
	fie.drainage_volume
FROM analytics.fact_irrigation_event    fie
JOIN analytics.dim_irrigation_zone      diz 	ON diz.irrigation_zone_id = fie.irrigation_zone_id
LEFT JOIN analytics.dim_zone            dz  	ON dz.zone_id             = diz.zone_id
left JOIN platform.organizations         o   	ON o.org_id               = fie.org_id;


-- Vista NDVI com geometria para o mapa (Cenário B)
CREATE OR REPLACE VIEW analytics.v_ndvi_map AS
SELECT
    fvs.fact_id,
    fvs.org_id,
    o.org_name,
    dz.zone_id,
    dz.zone_name,
    dz.zone_type,
    dz.geom,
    dvs.stat_name,
    fvs.stat_value,
    fvs.stat_date,
    CASE
        WHEN fvs.stat_value < 0.2  THEN 'critical'
        WHEN fvs.stat_value < 0.4  THEN 'warning'
        WHEN fvs.stat_value < 0.6  THEN 'good'
        ELSE                            'excellent'
    END AS ndvi_status
FROM analytics.fact_vegetation_stat 	fvs
JOIN analytics.dim_zone                 dz  	ON dz.zone_id  = fvs.zone_id
JOIN analytics.dim_vegetation_stat  	dvs 	ON dvs.stat_id = fvs.stat_id
left JOIN platform.organizations        o   	ON o.org_id    = fvs.org_id;

COMMENT ON VIEW analytics.v_ndvi_map IS
    'Vista NDVI com geometria para Leaflet e colorização por threshold. Cenário B.';

-- Vista meteorologia com contexto de org (Cenário B)
CREATE OR REPLACE VIEW analytics.v_weather_dashboard AS
SELECT
    fwo.fact_id,
    fwo.org_id,
    o.org_name,
    ds.station_name,
    fwo.observed_at,
    wp.parameter_name,
    fwo.parameter_value,
    fwo.parameter_unit,
	ds.geom
FROM analytics.fact_weather_observation 	fwo
JOIN analytics.dim_station              	ds  	ON ds.station_id   = fwo.station_id
JOIN analytics.dim_weather_parameter    	wp  	ON wp.parameter_id = fwo.parameter_id
left JOIN platform.organizations            o   	ON o.org_id        = fwo.org_id;


--Vista Solo FQ com contexto de org (Cenário B)
CREATE OR REPLACE VIEW analytics.v_soil_fq_dashboard AS
SELECT 
	s.fact_id,
	sp.parameter_name,
	s.parameter_value,
	s.parameter_unit,
	p.zone_id,
	sa.sample_id,
	p.parcel_name_normalized,
	sa.sample_date,
	s.interpretation,
	o.org_name,
	o.org_id
FROM analytics.fact_soil_parameter 		 	S
INNER JOIN analytics.dim_soil_parameter  	SP 		ON S.parameter_id=sp.parameter_id
INNER JOIN analytics.dim_sample 		  	SA 		ON S.sample_id=SA.sample_id
INNER JOIN analytics.dim_parcel 		 	P 		ON SA.parcel_id=P.parcel_id
LEFT  JOIN platform.organizations 			o    	ON o.org_id=s.org_id;



--Vista Microbiologia com contexto de org (Cenário B)
CREATE OR REPLACE VIEW analytics.v_microbiology_dashboard AS
SELECT
	m.fact_id,
	z.zone_id,
	m.sample_id,
	p.parcel_name_normalized,
	mg.metric_group_name,
	m.metric_name,
	m.metric_value,
	s.sample_date,
	o.org_id
FROM analytics.fact_microbiology_metric  		m
INNER JOIN analytics.dim_microbiology_group  	mg 		ON m.metric_group_id=mg.metric_group_id
INNER JOIN analytics.dim_sample  				s 		ON m.sample_id=s.sample_id
INNER JOIN analytics.dim_parcel  				p 		ON s.parcel_id=p.parcel_id
LEFT  JOIN platform.organizations 				o    	ON o.org_id=m.org_id;




