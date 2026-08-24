-- Criar utilizador
CREATE USER superset_reader WITH PASSWORD 'MKLdww9Tbm5bsgfsnsdkjdjgghdv';

-- Permissões de leitura
GRANT USAGE ON SCHEMA analytics 						TO superset_reader;

GRANT SELECT ON analytics.v_weather_dashboard 			TO superset_reader;
GRANT SELECT ON analytics.v_irrigation_dashboard 		TO superset_reader;
GRANT SELECT ON analytics.v_ndvi_map 					TO superset_reader;
GRANT SELECT ON analytics.dim_zone 						TO superset_reader;
GRANT SELECT ON analytics.v_microbiology_dashboard 		TO superset_reader;
GRANT SELECT ON analytics.v_soil_fq_dashboard 			TO superset_reader;


GRANT USAGE ON SCHEMA platform 							TO superset_reader;

GRANT SELECT ON platform.organizations 					TO superset_reader;



