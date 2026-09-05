# DK IPA — Guia de build e conexão

Este projeto é a versão modificada do **3105**. A tela existente de Patch foi transformada no painel **DK IPA**, com quatro funções que recebem automaticamente o pacote publicado no 3105 Update Studio.

## O que foi alterado

| Área | Implementação |
|---|---|
| Entrada do app | O onboarding e a seleção inicial de idioma foram removidos |
| Tela principal | `PatchOnlyView.swift` abre diretamente com Função 1, 2, 3 e 4 |
| Download | O app consulta o manifesto HTTPS e baixa o `.3105` publicado para a função |
| Validação | HTTPS, status HTTP, tamanho e SHA-256 são conferidos antes da importação |
| Ativação | O botão **LIGAR** importa o pacote e chama `DevicePatchService.apply` localmente |
| Desativação | O botão **DESLIGAR** usa o recibo nativo e chama `DevicePatchService.restore` |
| Segurança | O token do alvo fica no Keychain e não é gravado no código-fonte |
| Visual | Fundo preto, teias brancas animadas, Dynamic Type e redução de movimento |

## Fazer a build no Xcode

Abra `ThreeOneOSFive.xcodeproj` em um Mac com uma versão do Xcode compatível com o projeto. No target **ThreeOneOSFive**, confira **Signing & Capabilities**, escolha sua equipe de desenvolvimento e use um Bundle Identifier pertencente à sua conta. Em seguida, selecione um dispositivo autorizado e execute **Product → Build**.

> Este ambiente Linux validou a estrutura do projeto, o plist e a sintaxe dos arquivos Swift modificados. A assinatura, a compilação com os SDKs da Apple e a instalação final precisam ser concluídas no Xcode/macOS.

## Conectar ao site

No 3105 Update Studio, abra **Bundle Studio**, cadastre um alvo controlado por você e copie a **URL HTTPS do painel**, o **ID do alvo** e o **token do dispositivo** exibido uma única vez. No DK IPA, toque no botão de ajustes, informe esses três valores e escolha **Salvar e conectar**.

| Campo do DK IPA | Valor do site |
|---|---|
| URL do painel | Origem HTTPS do 3105 Update Studio |
| ID do alvo | Número gerado ao cadastrar o dispositivo |
| Token do dispositivo | Token secreto mostrado após o cadastro ou renovação |

## Criar e usar um pacote

No site, selecione o alvo e a Função 1–4. Envie um ou mais arquivos comuns, informe o Bundle ID do aplicativo de destino e defina o caminho relativo de cada arquivo dentro do container. O backend cria automaticamente o envelope `.3105`, criptografa o payload e calcula o SHA-256. Depois, publique a versão na função desejada.

No DK IPA, atualize a lista e toque em **LIGAR**. O app baixa o pacote daquela função, valida e aplica localmente. Para desfazer, toque em **DESLIGAR**; o recibo gerado na aplicação é usado para restaurar os arquivos originais.

## Observações de segurança

Use apenas Bundle IDs, caminhos e dispositivos que você controla. O host/IP cadastrado é inventário: o site não abre conexões ou executa comandos nesse endereço. A comunicação parte do DK IPA para o painel HTTPS, e pacotes com hash, tamanho ou resposta divergentes são recusados.
