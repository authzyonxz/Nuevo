# FreeFire External Injector (iOS 17-27)

Aplicativo desenvolvido **do zero** para atuar como um **Injetor Externo de Memória** para o Free Fire Max (`com.dts.freefireth`).

## Como Funciona o Fluxo Desejado:
1. Você abre o **Free Fire Max** e deixa o jogo rodando.
2. Abre este aplicativo (External Injector).
3. Clica em **ATIVAR EXPLOIT DE KERNEL** para obter acesso ao container do jogo em segundo plano.
4. Ativa as funções desejadas (HS Pescoço, HS Alto, Holograma, etc.). O app aplica as patches de memória usando as offsets do `GameOffsets.h` diretamente no processo do jogo.
5. Retorna ao jogo com as modificações aplicadas em tempo de execução.

## Estrutura do Projeto:
- `Include/GameOffsets.h`: Contém todas as offsets do Free Fire Max.
- `Kernel/ExternalPatcher.mm`: Módulo de comunicação com o kernel e escrita remota em processos.
- `App/Views/ContentView.swift`: Interface gráfica moderna em SwiftUI para controle das funções.
