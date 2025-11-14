#!/usr/bin/env python3
"""
Codex Gateway CLI - Cliente interativo para o gateway em produção
Usa WebSocket para comunicação em tempo real com o gateway
"""

import asyncio
import json
import sys
import os
from typing import Optional
import subprocess

try:
    import websockets
    import aiohttp
except ImportError:
    print("❌ Dependências não encontradas. Instalando...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "websockets", "aiohttp"])
    import websockets
    import aiohttp


class GatewayClient:
    def __init__(self, gateway_url: str, api_key: str):
        self.gateway_url = gateway_url.replace("https://", "wss://").replace("http://", "ws://")
        self.http_url = gateway_url.replace("wss://", "https://").replace("ws://", "http://")
        self.api_key = api_key
        self.session_id = f"cli-{os.getpid()}"
        self.message_id = 1

    async def health_check(self) -> bool:
        """Verifica se o gateway está saudável"""
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(f"{self.http_url}/health") as response:
                    data = await response.json()
                    return data.get("status") == "healthy"
        except Exception as e:
            print(f"❌ Erro ao verificar health: {e}")
            return False

    async def send_prompt_http(self, prompt: str) -> dict:
        """Envia prompt via HTTP JSON-RPC"""
        payload = {
            "jsonrpc": "2.0",
            "method": "conversation.prompt",
            "params": {
                "prompt": prompt,
                "session_id": self.session_id
            },
            "id": self.message_id
        }
        self.message_id += 1

        headers = {
            "X-API-Key": self.api_key,
            "Content-Type": "application/json"
        }

        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"{self.http_url}/jsonrpc",
                    json=payload,
                    headers=headers
                ) as response:
                    return await response.json()
        except Exception as e:
            return {"error": str(e)}

    async def interactive_session(self):
        """Sessão interativa com o gateway"""
        print("🚀 Codex Gateway CLI")
        print(f"📡 Conectado a: {self.http_url}")
        print(f"🔑 Session ID: {self.session_id}")
        print("━" * 60)
        print("Digite seus prompts (ou 'exit' para sair, 'clear' para limpar)")
        print("━" * 60)
        print()

        # Verifica saúde do gateway
        if not await self.health_check():
            print("⚠️  Gateway pode estar indisponível, mas tentando continuar...")
            print()

        while True:
            try:
                # Prompt do usuário
                user_input = input("💬 Você: ").strip()

                if not user_input:
                    continue

                if user_input.lower() == "exit":
                    print("\n👋 Encerrando sessão...")
                    break

                if user_input.lower() == "clear":
                    os.system('clear' if os.name != 'nt' else 'cls')
                    continue

                # Envia prompt
                print("⏳ Processando...")
                response = await self.send_prompt_http(user_input)

                # Exibe resposta
                if "error" in response:
                    print(f"❌ Erro: {response['error']}")
                elif "result" in response:
                    result = response["result"]
                    if isinstance(result, dict):
                        if "content" in result:
                            print(f"\n🤖 Resposta:\n{result['content']}\n")
                        elif "type" in result:
                            print(f"\n🤖 {result.get('type', 'response')}:")
                            print(json.dumps(result, indent=2))
                        else:
                            print(f"\n🤖 Resposta:")
                            print(json.dumps(result, indent=2))
                    else:
                        print(f"\n🤖 Resposta: {result}\n")
                else:
                    print(f"\n📦 Resposta completa:")
                    print(json.dumps(response, indent=2))

                print()

            except KeyboardInterrupt:
                print("\n\n👋 Interrompido pelo usuário. Encerrando...")
                break
            except EOFError:
                print("\n\n👋 EOF detectado. Encerrando...")
                break
            except Exception as e:
                print(f"\n❌ Erro inesperado: {e}")
                print()


async def main():
    # Obter configurações
    gateway_url = os.getenv(
        "GATEWAY_URL",
        "https://wrapper-uamdjcvg7q-uc.a.run.app"
    )

    # Tentar obter API key de múltiplas fontes (ordem de prioridade)
    api_key = os.getenv("GATEWAY_KEY")

    if not api_key:
        # Tentativa 1: Secret Manager
        try:
            result = subprocess.run(
                ["gcloud", "secrets", "versions", "access", "latest", "--secret=gateway-api-key"],
                capture_output=True,
                text=True,
                check=True
            )
            api_key = result.stdout.strip()
            print("✅ API Key obtida do Secret Manager")
        except Exception:
            # Tentativa 2: Usar chave hardcoded como fallback
            api_key = "a44c72cf24f7dcd1012bf8e7a2693b9c7385981cede7b95699fc4249285fb2ff"
            print("✅ Usando API Key padrão")

    # Iniciar cliente
    client = GatewayClient(gateway_url, api_key)
    await client.interactive_session()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n👋 Até logo!")
        sys.exit(0)
