# load.py
import psycopg2
import sys

db_configure = {
    "dbname"    : "smartsoil",
    "user"      : "postgres",
    "password"  : "nova_password",
    "host"      : "localhost",
    "port"      : "5434"
}

#Mapear o nome original pçara o nome normalizado do banco de dados
STATION_ALIASES = {

    '1828772': 'INIAV_DP',
}
STATION_NAMES = {

    'INIAV_DP': 'INIAV Dois Portos',

}

def db_conexao():
    try:
        return psycopg2.connect(**db_configure)
    except Exception as e:
        print(f"ERRO: Não foi possível ligar à base de dados: {e}")
        sys.exit(1)

def carregar_dados_no_banco(st_code, st_name, observacoes):
    if not observacoes:
        print("[Load] Aviso: Nenhum dado disponível para carregar.")
        return

     # Traduz o código da API para o código oficial do banco (se existir mapeamento)
    st_code = STATION_ALIASES.get(st_code, st_code)
    # Traduz para o nome normalizado (se existir mapeamento); senão mantém o da API
    st_name = STATION_NAMES.get(st_code, st_name)
    conn = db_conexao()
    cur = conn.cursor()

    try:
        source_name = "ThingSpeak"
        source_type = "IoT Platform"
        source_endpoint = f"https://api.thingspeak.com/channels/{st_code}/feeds.json"

        # 1. Garante o Data Source
        cur.execute("""
            INSERT INTO analytics.dim_data_source (source_name, source_type, source_endpoint)
            VALUES (%s, %s, %s)
            ON CONFLICT (source_name)
            DO UPDATE SET source_endpoint = EXCLUDED.source_endpoint
            RETURNING data_source_id;
        """, (source_name, source_type, source_endpoint))
        ds_id = cur.fetchone()[0]

        # 2. VERIFICAÇÃO DA ESTAÇÃO
        
        cur.execute("""
            SELECT station_id
             FROM analytics.dim_station WHERE station_code = %s;
        """, (st_code,))
        resultado_estacao = cur.fetchone()

        if resultado_estacao:
            # Se encontrou, reutiliza o ID existente
            st_id = resultado_estacao[0]
            print(f"[Load] Estação existente identificada: {st_name} (ID Banco: {st_id})")
        else:
            # Se NÃO encontrou, insere a nova estação dinamicamente
            print(f"[Load] Nova estação detetada! A criar registo para: {st_name} (Código: {st_code})")
            cur.execute("""
                INSERT INTO analytics.dim_station (station_code, station_name, data_source_id)
                VALUES (%s, %s, %s)
                RETURNING station_id;
            """, (st_code, st_name, ds_id))
            st_id = cur.fetchone()[0]

        raw_inserted = 0
        raw_skipped = 0
        fact_inserted = 0

        # 3. Processamento dos registos
        for obs in observacoes:
            
            # analytics.dim_weather_parameter
            cur.execute("""
                INSERT INTO analytics.dim_weather_parameter (parameter_name)
                VALUES (%s)
                ON CONFLICT (parameter_name)
                DO UPDATE SET parameter_name = EXCLUDED.parameter_name
                RETURNING parameter_id, parameter_unit;
            """, (obs["param_name"],))
            p_id, p_unit = cur.fetchone()

            # raw.raw_weather_observation
            cur.execute("""
                INSERT INTO raw.raw_weather_observation
                    (source_name, source_type, station_code,
                     observed_at, field_name, field_value, source_endpoint)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT ON CONSTRAINT unique_raw_entry DO NOTHING;
            """, (source_name, source_type, st_code,        
                  obs["observed_at"], obs["param_name"], obs["raw_val"], source_endpoint))

            if cur.rowcount > 0:
                raw_inserted += 1
            else:
                raw_skipped += 1
                continue  # Ignora duplicados e avança para o próximo field

            # analytics.fact_weather_observation
            cur.execute("""
                INSERT INTO analytics.fact_weather_observation
                    (station_id, data_source_id, observed_at,
                     parameter_id, parameter_value, parameter_unit)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT ON CONSTRAINT unique_observation DO NOTHING;
            """, (st_id, ds_id, obs["observed_at"], p_id, obs["val_numeric"], p_unit))

            if cur.rowcount > 0:
                fact_inserted += 1

        conn.commit()
        print(f"[Load] Sucesso para a estação {st_name}.\n"
              f"-> RAW:  +{raw_inserted} novos | {raw_skipped} duplicados\n"
              f"-> FACT: +{fact_inserted} novas observações.\n")

    except Exception as e:
        conn.rollback()
        print(f"ERRO no carregamento: {e}")
        raise
    finally:
        cur.close()
        conn.close()