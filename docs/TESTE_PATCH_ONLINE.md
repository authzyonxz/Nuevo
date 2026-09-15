# TESTE PATCH remoto

A função **TESTE PATCH** não depende mais de um arquivo `.3105` embutido no IPA. As duas variantes consultam o manifesto online e baixam o pacote publicado no ID estável `teste_patch`.

## Publicar ou substituir o pacote

Use o painel administrativo ou a API do servidor de atualização. Ao publicar novamente o mesmo `id`, o arquivo anterior é substituído e a próxima ativação baixa a nova versão.

```bash
curl -X POST https://keyauthv2.org/api/v1/admin/payloads \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -F id=teste_patch \
  -F display_name='TESTE PATCH' \
  -F file_type=3105 \
  -F version=1 \
  -F file_name='FixCrashFFTH.3105' \
  -F target_paths='Documents' \
  -F compatible_games='com.dts.freefireth' \
  -F package_password='OG' \
  -F payload=@./FixCrashFFTH.3105
```

O arquivo deve ser um pacote `.3105` válido. O servidor informa o tamanho e o SHA-256 no manifesto; o aplicativo verifica ambos antes de decodificar ou aplicar qualquer conteúdo.

A senha é informada no campo opcional `package_password` do manifesto. Use `package_password='OG'` para pacote protegido ou deixe o campo vazio/ausente para pacote sem senha. O IPA lê esse valor do manifesto e usa `nil` quando ausente, portanto não é necessário recompilar para trocar a senha de uma nova publicação. As duas variantes do workflow usam a mesma implementação.

## Ativar e desativar

Ao ativar, o aplicativo consulta novamente o manifesto, exige que `teste_patch` esteja habilitado e seja compatível com `com.dts.freefireth`, baixa o arquivo, valida o hash, desbloqueia o pacote e aplica suas regras pelo `DevicePatchService` e `PatchTransaction`.

Ao desativar, o aplicativo não precisa acessar o servidor: ele restaura pelo journal local e pelo backup original criado antes do Apply. Isso permite restaurar com segurança mesmo que o administrador tenha desativado ou excluído o item no servidor.

## Desativar no servidor

Use o botão **Desativar** no painel administrativo. O item permanece no histórico, mas novas ativações falham com a mensagem de indisponibilidade. Uma função já ativa continua marcada como ativa até ser desligada localmente; essa política evita apagar ou substituir dados sem uma ação explícita do usuário.

## Excluir e publicar uma nova versão

O botão **Excluir** remove o item do manifesto e o arquivo do armazenamento. O patch atualmente aplicado ainda pode ser restaurado, pois o journal e o backup são locais. Para instalar uma nova versão:

1. Desative a função no IPA para restaurar o patch atual.
2. Publique o novo arquivo usando o mesmo `id=teste_patch` e uma versão maior.
3. Ative novamente a função; o aplicativo baixará e validará a nova versão.

Se o usuário tentar ativar enquanto a versão anterior ainda estiver aplicada, o sistema recusa a operação para evitar dois journals ocupando os mesmos destinos.

## Regras de segurança

Somente o arquivo baixado e validado pelo manifesto entra no motor de patch. O aplicativo não aceita caminhos vindos do servidor para o TESTE PATCH: os destinos são definidos no próprio pacote `.3105` e continuam sujeitos à validação de bundle, path traversal, links simbólicos, duplicidade, fingerprint do container, backup, journal e SHA-256.
