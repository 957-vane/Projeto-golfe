--UPDATE a tabela analytics.dim_zone
UPDATE analytics.dim_zone
SET zone_type = 'Tee'
WHERE zone_id = 1;

UPDATE analytics.dim_zone
SET zone_type = 'Fairway'
WHERE zone_id = 2;

UPDATE analytics.dim_zone
SET zone_type = 'Rough'
WHERE zone_id = 3;

UPDATE analytics.dim_zone
SET zone_type = 'Bunker'
WHERE zone_id = 4;

UPDATE analytics.dim_zone
SET zone_type = 'Hazards'
WHERE zone_id = 5;

UPDATE analytics.dim_zone
SET zone_type = 'Green'
WHERE zone_id = 6;

--Coluna location_name
UPDATE analytics.dim_zone
SET location_name = 'Área de Partida'
WHERE zone_id = 1;

UPDATE analytics.dim_zone
SET location_name = 'Área Geral'
WHERE zone_id = 2;

UPDATE analytics.dim_zone
SET location_name = 'Zona De Relva'
WHERE zone_id = 3;

UPDATE analytics.dim_zone
SET location_name = 'Bancas'
WHERE zone_id = 4;

UPDATE analytics.dim_zone
SET location_name = 'Área de Perigo'
WHERE zone_id = 5;

UPDATE analytics.dim_zone
SET location_name = 'Área da bandeira'
WHERE zone_id = 6;


--Insert de Tenants 
INSERT INTO platform.tenants(tenant_name,tenant_slug, plan_type)
VALUES 
		( 'GreenMaster', 	'agroconsult', 	'enterprise' ),
		( 'Vértice Golfe', 	'verticegolfe', 'enterprise' ),
		( 'Fairway Club', 	'fairwayclub', 	'enterprise' ),
		( 'Albatroz Golf', 	'albatrozgolf', 'enterprise' ),
		( 'Aura Golfe', 	'auragolf', 	'enterprise' );


--Insert platform.domain_types
INSERT INTO platform.domain_types(domain_name,domain_slug)
VALUES 
		( 'Golf Course Management', 'agriculture' ),
		( 'Golf Course Management', 'biology' ),
		( 'Golf Course Management', 'soil' ),
		( 'Golf Course Management', 'weather' ),
		( 'Golf Course Management', 'watering' );


--Inserir platform.organizations
INSERT INTO platform.organizations(tenant_id,domain_type_id, org_name, org_slug)
VALUES
       (4, 2, 'GreenMaster', 'Agricultura'),
	   (5, 3, 'Vértice Golfe', 'Biologia'),
	   (6, 4, 'Fairway Club', 'Solo'),
	   (7, 5, 'Albatroz Golf', 'Clima'),
	   (8, 6, 'Aura Golfe', 'Rega');

--Insert tabela analytics.dim_zone(updates da coluna org_id)
UPDATE analytics.dim_zone
SET org_id = 3
WHERE zone_id = 2;

UPDATE analytics.dim_zone
SET org_id = 4
WHERE zone_id = 3;

UPDATE analytics.dim_zone
SET org_id = 5
WHERE zone_id = 4;

UPDATE analytics.dim_zone
SET org_id = 6
WHERE zone_id = 5;

UPDATE analytics.dim_zone
SET org_id = 7
WHERE zone_id = 6;

--UPDATE a tabela dim_parcel
UPDATE analytics.dim_parcel p
SET org_id = z.org_id
FROM analytics.dim_zone z
WHERE p.zone_id = z.zone_id;

-- update tabela analytics.dim_sample
UPDATE analytics.dim_sample s
SET org_id = p.org_id
FROM analytics.dim_parcel p
WHERE s.parcel_id = p.parcel_id;

-- update tabela analytics.fact_soil_parameter
UPDATE analytics.fact_soil_parameter s
SET org_id = sa.org_id
FROM analytics.dim_sample sa
WHERE sa.sample_id = s.sample_id;


--update tabela analytics.fact_microbiology_metric
UPDATE analytics.fact_microbiology_metric m
SET org_id = sa.org_id
FROM analytics.dim_sample sa
WHERE sa.sample_id = m.sample_id;


--update tabela analytics.fact_vegetation_stat
UPDATE analytics.fact_vegetation_stat v
SET org_id = z.org_id
FROM analytics.dim_zone z
WHERE z.zone_id = v.zone_id;



--update analytics.dim_irrigation_zone
UPDATE analytics.dim_irrigation_zone i
SET zone_id = z.zone_id
FROM analytics.dim_zone z
WHERE z.org_id = i.org_id;


--update analytics.fact_irrigation_event
UPDATE analytics.fact_irrigation_event e
SET org_id = i.org_id
FROM analytics.dim_irrigation_zone i
WHERE i.irrigation_zone_id = e.irrigation_zone_id;


--Insert a tabela analytics.dim_irrigation_zone
INSERT INTO analytics.dim_irrigation_zone(zone_name_original, irrigation_zone_name_normalized,zone_type, zone_id, org_id)
VALUES
       ('SET', 		'Setor', 	'setor', 2, 3 ),
	   ('BLOCO', 	'Bloco', 	'bloco', 3, 4 );





