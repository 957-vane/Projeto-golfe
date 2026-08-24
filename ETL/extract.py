# Com o objeto de extrair dados de meteorologia de uma API 

import requests                 #Para fazer requisições a API


def recolhe_dados_api(channel_id, results=100):
    url = f"https://api.thingspeak.com/channels/{channel_id}/feeds.json"
    try:
        response = requests.get(url, params={"results": results, "timezone" : "UTC"}, timeout=20)
        response.raise_for_status()
        data = response.json()
        feeds = data.get("feeds", [])
        if feeds:
            print(f"\n [EXTRACT] ThingSpeak: {len(feeds)} feeds recebidos.")
            return data
    except requests.exceptions.RequestException as e:
        print(f"Erro: Falha na API: {e}")
        return None






