# main.py
from extract import recolhe_dados_api
from transform import transformar_dados
from load import carregar_dados_no_banco


id_canal = 1828772

def executar_pipeline():
    print("--- Iniciando Extração ---")
    
    try:
        num_results = int(input("Insira a quantidade de registos válidos:  "))
    except ValueError:
        print("Insira o número de registos de 1 dia. ")
        return

    # 2. EXTRACT - Passa o ID fixo automaticamente, sem perguntar no terminal
    dados_brutos = recolhe_dados_api(id_canal, num_results)
    
    if not dados_brutos:
        print("[Load] Aviso: Nenhum dado disponível para carregar.")
        print("--- Carregamento Encerrado ---")
        return

    # 3. TRANSFORM - Descobre o st_code e st_name dinamicamente de dentro do JSON
    st_code, st_name, observacoes = transformar_dados(dados_brutos)
    
    # 4. LOAD - Faz o SELECT no Postgres e cria a estação se ela não existir
    carregar_dados_no_banco(st_code, st_name, observacoes)
    
    print("--- Extração Concluída! ---")

if __name__ == "__main__":
    executar_pipeline()
    input("\nFechar: Enter\n")