# Correção do fluxo UDID

A versão anterior iniciava a sessão, mas não possuía uma ação visual explícita para obter o UDID. Além disso, o campo de Key ficava disponível antes de uma confirmação de captura do dispositivo.

A UI original foi preservada. O overlay agora segue estes estados:

| Estado | UI |
|---|---|
| Checking package / Preparando ativação | Mostra carregamento; campo de Key e botão de UDID ficam bloqueados. |
| Aguardando dispositivo | Mostra o botão **Obter UDID**; o portal só é aberto quando o usuário toca no botão. |
| UDID capturado | Esconde o botão de UDID e libera o campo original de Key e os botões Enviar/Paste. |
| Falha antes do UDID | Mantém o campo de Key oculto e permite tentar **Obter UDID** novamente. |
| Falha depois do UDID | Mantém o campo de Key disponível para correção da Key. |

O app considera o dispositivo capturado somente quando `/api/v2/device/session/status` retorna `captured == true` ou `deviceRegistered == true`. Durante a espera, o servidor pode responder HTTP 400 com `DEVICE_NOT_CAPTURED`; esse código é convertido pelo cliente Swift em um status pendente (`captured == false`) e não apaga a sessão nem mostra erro de UDID. A Key não é enviada antes da confirmação.

Ao voltar do portal, o app consulta o mesmo token salvo. O retorno ao foreground chama `refreshDeviceCapture()` e a UI também oferece o botão **Verificar** para repetir a consulta manualmente. Quando a captura é confirmada, `deviceCaptured` muda para `true`, o overlay esconde os botões de UDID e libera a tela original da Key.

O botão chama `LicenseManager.obtainUDID()`, que abre `/device/external/{token}` usando a sessão salva. Depois da instalação do perfil e do retorno ao app, o ciclo de vida consulta novamente o status da sessão e libera a etapa da Key apenas quando a captura foi confirmada.

A versão enviada pelo usuário também revelou o erro anterior de autorização: o cliente esperava `grantPayload`, `package` e `expiresAt`, enquanto o servidor retorna `grant`, `claims` e `kid`. Esse modelo já foi corrigido nesta versão.

A compilação final deve ser executada no Xcode em macOS, pois o ambiente de análise não possui o SDK iOS.
