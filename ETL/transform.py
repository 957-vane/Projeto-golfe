# Transformar os dados da API normalizando os fields 


field_mapping = {
    "field1": "PAR",
    "field2": "Temperatura",
    "field3": "Humidade",
    "field4": "VPD",
    "field5": "Folha molhada",
    "field6": "Vento (velocidade)",
    "field7": "Direção do vento",
    "field8": "Precipitação"
    }
    
def transformar_dados(data_bruta):
    if not data_bruta or "feeds" not in data_bruta:                     #Verificação se os dados vão válido ou vazio
        return None, None, []                                           #Se não for retorna none 

    canal = data_bruta.get("channel", {})
    st_code = str(canal.get("id", ""))                                  #identifica o canal e o id
    st_name = canal.get("name", "")                                     #identifica o nome do canal

    feeds = data_bruta["feeds"]                                         #guarda os dados brutos 
    observacoes_limpas = []

    for feed in feeds:                                                  #Mapeia linha a linha 
        observed_at = feed["created_at"]

        for field_id, param_name in field_mapping.items():              #mapeia e nomeia cada field
            raw_val = feed.get(field_id)                                #transformando cada field em 1 liha

            # Suas validações originais
            if raw_val is None or str(raw_val).strip() == "":           #Se a linha vier vazia 
                continue                                                #continua sem parar

            try:                                                        #faz replace para números decimais
                val_numeric = float(str(raw_val).replace(",", "."))
            except (ValueError, TypeError):                             #Se o valor vinher com erro
                continue                                                #continua

            
            observacoes_limpas.append({
                "observed_at": observed_at,
                "param_name": param_name,
                "raw_val": str(raw_val),
                "val_numeric": val_numeric
            })

    return st_code, st_name, observacoes_limpas
