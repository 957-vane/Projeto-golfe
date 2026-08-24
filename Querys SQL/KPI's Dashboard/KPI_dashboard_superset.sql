-- =============================================================================
-- GRUPO 1 — VEGETAÇÃO / NDVI
-- View base: analytics.v_ndvi_map
-- =============================================================================

-- -----------------------------------------------------------------------------
-- KPI-V02 · Zonas em alerta (cartão)
-- Tipo no Superset: Big Number ou Table
-- -----------------------------------------------------------------------------
-- Conta zonas com NDVI abaixo dos thresholds na última leitura.

SELECT COUNT(DISTINCT zone_id) AS zonas_criticas
FROM (
    SELECT DISTINCT ON (zone_id)
        	zone_id,
        	ndvi_status,
			org_id
    FROM analytics.v_ndvi_map
    WHERE stat_name = 'mean_values'
    ORDER BY zone_id, stat_date DESC
) latest
WHERE ndvi_status = 'critical';


--Warning 
SELECT COUNT(DISTINCT zone_id) AS zonas_warning
FROM (
    SELECT DISTINCT ON (zone_id)
        zone_id,
        ndvi_status,
		org_id
    FROM analytics.v_ndvi_map
    WHERE stat_name = 'ndvi_mean'
    ORDER BY zone_id, stat_date DESC
) latest
WHERE ndvi_status IN ('warning', 'critical');


-- -----------------------------------------------------------------------------
-- KPI-V03 · Média NDVI por zona últimos 90 dias [Barras]
-- Tipo no Superset: ECharts Bar Chart 
-- -----------------------------------------------------------------------------
SELECT
    stat_date::date         AS data,
	org_id,
    zone_name,
    zone_type,
    ROUND(stat_value::numeric, 3)   AS ndvi_mean,
    CASE 
        WHEN stat_value < 0.4 THEN '1. Critico'                 -- Vermelho
        WHEN stat_value BETWEEN 0.4 AND 0.6 THEN '2. Atencao'   -- Amarelo
        WHEN stat_value BETWEEN 0.6 AND 0.8 THEN '3. Bom'       -- Verde Claro
        ELSE '4. Excelente'                                     -- Verde Escuro
    END AS status_cor
FROM analytics.v_ndvi_map
WHERE stat_name = 'mean_value'
	  AND stat_date >= CURRENT_DATE - INTERVAL '90 DAYS'
ORDER BY stat_date, zone_name;


-- -----------------------------------------------------------------------------
-- KPI-V04 · Estado do campo  (Barras)
-- Tipo no Superset: ECharts Bar Chart 
-- -----------------------------------------------------------------------------
WITH latest AS (
    SELECT DISTINCT ON (zone_id)
        zone_id,
        zone_name,
	  	  org_id,
        ndvi_status,
        stat_date
    FROM analytics.v_ndvi_map
    WHERE stat_name = 'mean_value'
    ORDER BY zone_id, stat_date DESC
),
area_por_estado AS (
    SELECT
        l.ndvi_status,
		l.org_id,
        COUNT(*)                        AS num_zonas,
        SUM(public.ST_Area(
            public.ST_Transform(v.geom, 3763)))                             AS area_m2
    FROM latest l
    JOIN analytics.v_ndvi_map  v ON v.zone_id = l.zone_id
    GROUP BY l.ndvi_status, l.org_id
),
total AS (
    SELECT SUM(area_m2) AS area_total FROM area_por_estado
)
SELECT
    CASE a.ndvi_status
    WHEN 'critical'       THEN 'Crítico'
        WHEN 'warning'    THEN 'Atenção'
        WHEN 'good'       THEN 'Bom'
        WHEN 'excellent'  THEN 'Excelente'
        ELSE a.ndvi_status 
    END AS ndvi_status,
    a.num_zonas,
	a.org_id,
    ROUND(a.area_m2::numeric, 0)                            AS area_m2,
    ROUND((a.area_m2 / t.area_total * 100)::numeric, 1)    AS pct_area
FROM area_por_estado a, total t
ORDER BY
    CASE a.ndvi_status
        WHEN 'critical'  THEN 1
        WHEN 'warning'   THEN 2
        WHEN 'good'      THEN 3
        WHEN 'excellent' THEN 4
    END;

-- -----------------------------------------------------------------------------
-- KPI-V05 · Mapa das zonas [MAPA — Mapbox + Superset GeoJSON]
-- Tipo no Superset: deck.gl Polygon
-- -----------------------------------------------------------------------------
-- O Superset usa geom (GeoJSON) para desenhar os polígonos no mapa.

SELECT DISTINCT ON (zone_id)
    zone_id,
	org_id,
    zone_name,
    zone_type,
    stat_date,
    stat_value                                          AS ndvi_mean,
    ndvi_status,
    ST_AsGeoJSON(geom)::json                            AS geom_geojson,
    CASE ndvi_status
        WHEN 'critical'   THEN '#E24B4A'
        WHEN 'warning'    THEN '#EF9F27'
        WHEN 'good'       THEN '#639922'
        WHEN 'excellent'  THEN '#1D9E75'
    END                                                 AS fill_color
FROM analytics.v_ndvi_map
WHERE stat_name = 'mean_value'
ORDER BY zone_id, stat_date DESC;


-- =============================================================================
-- GRUPO 2 — REGA
-- View base: analytics.v_irrigation_dashboard
-- =============================================================================

-- -----------------------------------------------------------------------------
-- KPI-I02 · Volume de rega por zona  [BARRA]
-- Tipo no Superset: ECharts Bar Chart
-- -----------------------------------------------------------------------------
SELECT
    zone_name,
    zone_type,
    org_id,
    COUNT(*)                                AS num_eventos,
    ROUND(SUM(volume_applied)::numeric, 0)  AS volume_total_l,
    ROUND(SUM(volume_applied) / 1000.0, 2)  AS volume_total_m3,
    ROUND(
        CAST(
            AVG(EXTRACT(EPOCH FROM duration_seconds)) / 60.0 AS DECIMAL
        ), 1)  AS duracao_media_min
FROM analytics.v_irrigation_dashboard
WHERE event_date >= CURRENT_DATE - INTERVAL '30 days'
  AND event_date <= CURRENT_DATE
GROUP BY zone_name, zone_type, org_id
ORDER BY volume_total_l DESC;



-- -----------------------------------------------------------------------------
-- KPI-I06 · Modo de irrigação  [Pie]
-- Tipo no Superset: ECharts Pie Chart
-- Prioridade: Complementar
-- -----------------------------------------------------------------------------
SELECT 
		mode, 
		volume_applied, 
		org_id,
		event_date
FROM analytics.v_irrigation_dashboard 

-- -----------------------------------------------------------------------------
-- KPI-I03 · Consumo diário de água — últimos 30 dias  [ÁREA / LINHA]
-- Tipo no Superset: ECharts Area Chart
-- Prioridade: ALTA
-- Nota: inclui precipitação do mesmo dia para correlação visual (ver KPI-M03)
-- -----------------------------------------------------------------------------
WITH rega_diaria AS (
    SELECT
		
        event_date                              AS data,
        ROUND(SUM(volume_applied)::numeric, 0)  AS volume_rega_l,
        COUNT(*)                                AS num_eventos
    FROM analytics.v_irrigation_dashboard
    GROUP BY event_date, org_id
),
precipitacao_diaria AS (
    SELECT
        observed_at::date                           AS data,
        ROUND(SUM(parameter_value)::numeric, 1)     AS precipitacao_mm
    FROM analytics.v_weather_dashboard
    WHERE parameter_name  = 'Precipitação'
    GROUP BY observed_at::date
)
SELECT
    r.data,
	
    COALESCE(r.volume_rega_l, 0)    AS volume_rega_l,
    COALESCE(r.num_eventos, 0)      AS num_eventos,
    COALESCE(p.precipitacao_mm, 0)  AS precipitacao_mm
FROM rega_diaria r
LEFT JOIN precipitacao_diaria p ON p.data = r.data
ORDER BY r.data


-- -----------------------------------------------------------------------------
-- KPI-I04 · Qualidade da água de rega — desvios EC e pH  [TABELA]
-- Tipo no Superset: Table com conditional formatting
-- Filtros Superset: date range
-- -----------------------------------------------------------------------------
SELECT
    event_date,
    zone_name,
	org_id,
    mode,
    ROUND(ec_setpoint::numeric, 2)       AS ec_setpoint,
    ROUND(ec_measured::numeric, 2)  AS ec_medido,
    ROUND(ABS(ec_measured - ec_setpoint)::numeric, 2)
                                    AS ec_desvio,
    ROUND(ph_setpoint::numeric, 2)       AS ph_setpoint,
    ROUND(ph_measured::numeric, 2)  AS ph_medido,
    ROUND(ABS(ph_measured - ph_setpoint)::numeric, 2)
                                    AS ph_desvio,
    CASE
        WHEN ABS(ec_measured - ec_setpoint) > 0.5
          OR ABS(ph_measured - ph_setpoint) > 0.5
        THEN 'warning'
        ELSE 'ok'
    END                             AS qualidade_flag
FROM analytics.v_irrigation_dashboard
WHERE  ec_setpoint        IS NOT NULL
  AND ec_measured   IS NOT NULL
  AND event_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY event_date DESC, ec_desvio DESC;
 

-- =============================================================================
-- GRUPO 3 — METEOROLOGIA
-- View base: analytics.v_weather_dashboard
-- =============================================================================


-- -----------------------------------------------------------------------------
-- KPI-M01 · Condições actuais — temperatura, humidade, precipitação, 
--velocidade do vento  (Cartão)
-- Tipo no Superset: 3× Big Number (um por métrica)
-- -----------------------------------------------------------------------------
-- Última leitura disponível para cada parâmetro.

SELECT parameter_name,
	org_id,
    parameter_value  AS valor,
    parameter_unit                      AS unidade,
    observed_at                         AS ultima_leitura
FROM analytics.v_weather_dashboard
WHERE parameter_name = 'Temperatura'
      AND observed_at >= NOW() - INTERVAL '7 days'
ORDER BY parameter_name, observed_at DESC
LIMIT 1;


--Precipitação
SELECT parameter_name,
	org_id,
    parameter_value  AS valor,
    parameter_unit                      AS unidade,
    observed_at                         AS ultima_leitura
FROM analytics.v_weather_dashboard
WHERE parameter_name = 'Precipitação'
  	  AND observed_at >= NOW() - INTERVAL '7 days'
ORDER BY parameter_name, observed_at DESC
LIMIT 1;

--Velocidade do Vento 
SELECT parameter_name,
	org_id,
    parameter_value  AS valor,
    parameter_unit                      AS unidade,
    observed_at                         AS ultima_leitura
FROM analytics.v_weather_dashboard
WHERE parameter_name = 'Vento (velocidade)'
  	  AND observed_at >= NOW() - INTERVAL '7 days'
ORDER BY parameter_name, observed_at DESC
LIMIT 1;

--Humidade
SELECT parameter_name,
	org_id,
    parameter_value  AS valor,
    parameter_unit                      AS unidade,
    observed_at                         AS ultima_leitura
FROM analytics.v_weather_dashboard
WHERE parameter_name = 'Humidade'
  	  AND observed_at >= NOW() - INTERVAL '7 days'
ORDER BY parameter_name, observed_at DESC
LIMIT 1;



-- -----------------------------------------------------------------------------
-- KPI-M02 · Temperatura e humidade — últimas 48h  [LINHA DUPLO EIXO]
-- Tipo no Superset: ECharts Line Chart (dual axis)
-- -----------------------------------------------------------------------------

SELECT
    DATE_TRUNC('hour', observed_at)     AS hora,
	org_id,
    parameter_name,
    ROUND(AVG(parameter_value)::numeric, 1) AS valor_medio
FROM analytics.v_weather_dashboard
WHERE 
   parameter_name    IN ('Temperatura', 'Humidade')
  AND observed_at       >= NOW() - INTERVAL '48 hours'
GROUP BY DATE_TRUNC('hour', observed_at), parameter_name, org_id
ORDER BY hora, parameter_name;


-- -----------------------------------------------------------------------------
-- KPI-M03 · Precipitação acumulada — últimos 30 dias  [BARRA]
-- Tipo no Superset: ECharts Bar Chart com linha de acumulado
-- -----------------------------------------------------------------------------
WITH precipitacao_diaria AS (
    SELECT
        observed_at::date                           AS data,
        ROUND(SUM(parameter_value)::numeric, 1)     AS precipitacao_mm,
        org_id
    FROM analytics.v_weather_dashboard
    WHERE 
    parameter_name    = 'Precipitação'
    AND observed_at       >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY observed_at::date, org_id
)
SELECT
    data,
    precipitacao_mm,
    org_id,
    ROUND(SUM(precipitacao_mm) OVER (
        ORDER BY data
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )::numeric, 1)                                  AS acumulado_mm
FROM precipitacao_diaria
ORDER BY data;

-- -----------------------------------------------------------------------------
-- KPI-M05 · Temperatura — últimos 10 dias  [Line]
-- Tipo no Superset: ECharts Line Chart 
-- -----------------------------------------------------------------------------
SELECT 
	observed_at as data_hora,
	org_id,
	parameter_value as temperatura
FROM analytics.v_weather_dashboard 
WHERE parameter_name = 'Temperatura'
	  AND observed_at >= NOW() - INTERVAL '10 days'

-- -----------------------------------------------------------------------------
-- KPI-M06 · Média da Temperatura — últimos Mês  [Bar]
-- Tipo no Superset: ECharts Bar Chart 
-- -----------------------------------------------------------------------------
SELECT 
    observed_at::date AS dia,
	org_id,
    ROUND(AVG(parameter_value), 2) AS temperatura_media
FROM analytics.v_weather_dashboard
WHERE parameter_name = 'Temperatura'
      AND observed_at >= NOW() - INTERVAL '1 month'
GROUP BY observed_at::date, parameter_unit, org_id
ORDER BY dia ASC;


-- -----------------------------------------------------------------------------
-- KPI-M07 · Velocidade do Vento — últimos 10 dias  [Mixed]
-- Tipo no Superset: ECharts Mixed Chart (line and Bar)
-- Prioridade: Complementar
-- -----------------------------------------------------------------------------
SELECT 
    observed_at::date AS dia,
    MAX(parameter_value) AS vento_maximo,
    MIN(parameter_value) AS vento_minimo,
    parameter_unit AS unidade,
	org_id
FROM analytics.v_weather_dashboard
WHERE parameter_name = 'Vento (velocidade)'
      AND observed_at >= NOW() - INTERVAL '1 month'
GROUP BY observed_at::date, parameter_unit, org_id
ORDER BY dia DESC;



-- -----------------------------------------------------------------------------
-- KPI-M08 · VPD do Ar — últimos 10 dias [Line]
-- Tipo no Superset: ECharts Line Chart
-- -----------------------------------------------------------------------------
SELECT 
	observed_at 		AS data_hora,
	parameter_value 	AS VPD,
	org_id
FROM analytics.v_weather_dashboard
WHERE parameter_name='VPD'
      AND observed_at >= NOW() - INTERVAL '10 days'

-- -----------------------------------------------------------------------------
-- KPI-M09 · Estação Meteorológica
-- Tipo no Superset: Mapa
-- Prioridade: Complementar
-- -----------------------------------------------------------------------------
SELECT 
    station_name,
    public.ST_X(geom) AS longitude,
    public.ST_Y(geom) AS latitude,
    org_id
FROM (
    SELECT DISTINCT ON (geom)
        geom,
        station_name,
        org_id
    FROM analytics.v_weather_dashboard 
    ORDER BY geom
) subquery

-- =============================================================================
-- GRUPO 4 — Solo
-- View base: analytics.v_soil_fq_dashboard
-- =============================================================================

-- -----------------------------------------------------------------------------
-- KPI-S01 · Número de Amostras [NÚMERO — scorecard]
-- Tipo no Superset: Big Number 
-- -----------------------------------------------------------------------------
SELECT 
		COUNT(DISTINCT(sample_id)),
		org_id
FROM analytics.v_soil_fq_dashboard
GROUP BY org_id


-- -----------------------------------------------------------------------------
-- KPI-S02 · Total de Zonas [NÚMERO — scorecard]
-- Tipo no Superset: Big Number 
-- -----------------------------------------------------------------------------
SELECT 
		COUNT(DISTINCT(zone_id)),
		org_id
FROM analytics.v_soil_fq_dashboard 
GROUP BY org_id


-- -----------------------------------------------------------------------------
-- KPI-S03 · Matéria orgânica por Parcela 
-- Tipo no Superset: Sankey Chart 
-- -----------------------------------------------------------------------------
SELECT
	parcel_name_normalized,
	parameter_value,
	interpretation,
	org_id
FROM analytics.v_soil_fq_dashboard 
where parameter_name = 'Matéria Orgânica'

-- -----------------------------------------------------------------------------
-- KPI-S04 · Sódio(%) por Parcela [Bar]
-- Tipo no Superset: Echart Bar Chart
-- -----------------------------------------------------------------------------
SELECT
	parcel_name_normalized 	AS Parcela,
	parameter_value 		AS Valor,
	org_id
FROM analytics.v_soil_fq_dashboard 
where parameter_name = 'Sódio (%)'


-- -----------------------------------------------------------------------------
-- KPI-S05 · Têxtura do Campo [Table]
-- Tipo no Superset: Echart table 
-- -----------------------------------------------------------------------------
SELECT
	zone_id 				AS ID,
	org_id,
	parcel_name_normalized 	AS Nome,
	parameter_value 		AS Total,
	interpretation 			AS Interpretação
FROM analytics.v_soil_fq_dashboard 
where parameter_name = 'Textura do Campo'


-- -----------------------------------------------------------------------------
-- KPI-S06 · Média de PH por Parcela [Table]
-- Tipo no Superset: Echart table
-- -----------------------------------------------------------------------------
SELECT 
    zone_id as Zona,
	org_id,
    parcel_name_normalized as Parcela,
    AVG(parameter_value)::NUMERIC(10,2) as Media_ph_parcela,
    -- Esta parte calcula a média de todas as parcelas daquela zona
    AVG(AVG(parameter_value)) OVER (PARTITION BY zone_id)::NUMERIC(10,2) as Media_ph_zona
FROM analytics.v_soil_fq_dashboard 
WHERE parameter_name ILIKE 'pH%'
GROUP BY zone_id, parcel_name_normalized, org_id
ORDER BY zone_id, media_ph_parcela DESC;



-- =============================================================================
-- GRUPO 5 — Microbiologia
-- View base: analytics.v_microbiology_dashboard
-- =============================================================================
-- -----------------------------------------------------------------------------
-- KPI-M01 · Saúde Global [scorecard]
-- Tipo no Superset: Big Number 
-- -----------------------------------------------------------------------------
SELECT 
	metric_value, 
	org_id
FROM analytics.v_microbiology_dashboard
WHERE metric_name = 'Global healthiness' AND sample_id = 1


-- -----------------------------------------------------------------------------
-- KPI-M02 · Resiliência [scorecard]
-- Tipo no Superset: Big Number
-- -----------------------------------------------------------------------------
SELECT metric_value, org_id 
FROM analytics.v_microbiology_dashboard
WHERE metric_name = 'Resilience' AND sample_id = 1


-- -----------------------------------------------------------------------------
-- KPI-M03 · Funcionalidade [scorecard]
-- Tipo no Superset: Big Number
-- -----------------------------------------------------------------------------
SELECT metric_value, org_id
FROM analytics.v_microbiology_dashboard
WHERE metric_name = 'Functionality' AND sample_id = 1


-- -----------------------------------------------------------------------------
-- KPI-M04 · Boicontrole Global [scorecard]
-- Tipo no Superset: Big Number
-- -----------------------------------------------------------------------------
SELECT metric_name,
	   org_id,
       metric_value
FROM analytics.v_microbiology_dashboard 
WHERE metric_name = 'Global biocontrol'


-- -----------------------------------------------------------------------------
-- KPI-M05 · Biosustentabilidade do Solo [scorecard]
-- Tipo no Superset: Big Number
-- -----------------------------------------------------------------------------
SELECT metric_name,
       metric_value
FROM analytics.v_microbiology_dashboard 
WHERE metric_name = 'Soil biosustainability'


-- -----------------------------------------------------------------------------
-- KPI-M06 · Nutrientes [Bar/ Horizontal]
-- Tipo no Superset: ECHART BAR  
-- -----------------------------------------------------------------------------
SELECT metric_name, metric_value, org_id
FROM  analytics.v_microbiology_dashboard 
WHERE metric_name IN (
	'Sulfur cycle equilibrium',
	'Calcium transport',
	'Magnesium transport',
	'Zinc transport equilibrium',
	'Iron assimilation',
	'Manganese transport equilibrium' )
	AND metric_value > 0


-- -----------------------------------------------------------------------------
-- KPI-M07 · Ratios Microbianos [Table]
-- Tipo no Superset: Table
-- -----------------------------------------------------------------------------
SELECT metric_name AS Nome,
       metric_value as Total,
	   org_id
FROM analytics.v_microbiology_dashboard 
WHERE metric_group_name IN ('counts', 'ratios', 'units')
      AND metric_value > 0


-- -----------------------------------------------------------------------------
-- KPI-M08 · Doenças [Tabela]
-- Tipo no Superset: Table
-- -----------------------------------------------------------------------------
SELECT metric_name,
       metric_value,
	   org_id
FROM analytics.v_microbiology_dashboard 
WHERE metric_group_name= 'disease' 
      AND metric_value > 0

-- -----------------------------------------------------------------------------
-- KPI-M08 · Fungicidas [Pie]
-- Tipo no Superset: Echart Pie Chart 
-- -----------------------------------------------------------------------------
SELECT metric_name,
       metric_value,
	   org_id
FROM analytics.v_microbiology_dashboard 
WHERE metric_group_name = 'biocontrol' AND metric_value > 0







