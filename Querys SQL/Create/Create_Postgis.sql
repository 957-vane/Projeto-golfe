
--Base de Dados com extensão do Postgis para visualização de dados geoespaciais---------------------------------------------

CREATE EXTENSION POSTGIS;

--Verificar ativação do PostGis---
SELECT PostGIS_Version();

--Atualizar tabelas existentes-----------------------------------------------------------------------------------------------

-- dim_zone---
ALTER TABLE analytics.dim_zone 
ADD COLUMN geom geometry(MultiPolygon, 4326);

--Inserir dados de geometry----
UPDATE analytics.dim_zone z
SET geom = ST_Transform(ST_SetSRID(v.geometry, 32629), 4326)
FROM raw.raw_vegetation_stats v
WHERE v.zone_id::integer = z.zone_id;


-- dim_station-----
--Normalizar os nomes das estações 
UPDATE analytics.dim_station
SET station_code = 'INIAV_DP',
    station_name = 'INIAV Dois Portos'
WHERE station_code = '1828772';

--Inserir a coluna de geometria
ALTER TABLE analytics.dim_station 
ADD COLUMN geom geometry(Point, 4326);

--Inserir dados de geometria na tabela 
UPDATE analytics.dim_station
SET geom = ST_SetSRID(ST_MakePoint(-9.181999, 39.041417), 4326)
WHERE station_id = 1;


--Criar Indíces espaciais--------------------------------------------------------------------------------------------------
CREATE INDEX idx_dim_parcel_geom ON analytics.dim_zone USING GIST (geom);

CREATE INDEX idx_dim_station_geom ON analytics.dim_station USING GIST (geom);


