# 3105 Pairing Helper

Helper local para gerar um pairing record autorizado e copiá-lo para o app 3105 por USB. O mesmo script funciona no Windows, macOS e Linux. Os dados de pareamento não passam por servidor externo.

## Requisitos

- iPhone desbloqueado e cabo USB;
- confiança autorizada no computador;
- Python 3.10 ou superior;
- `pymobiledevice3` instalado:

```bash
python -m pip install --upgrade pymobiledevice3
```

No Linux, o `usbmuxd` também precisa estar instalado e em execução. No Windows, instale o iTunes/Apple Devices para disponibilizar os drivers USB da Apple.

## Uso

1. Abra o 3105 e vá em **CONFIG**.
2. Toque em **Parear com computador**.
3. Deixe o código de 6 dígitos visível.
4. Conecte o iPhone por USB, desbloqueie-o e aceite **Confiar neste computador**.
5. Execute:

```bash
python tools/3105-pairing-helper/3105_pairing_helper.py --pin 123456
```

Troque `123456` pelo código mostrado na tela. O helper executa `lockdown pair`, valida as chaves do record e usa `core-device write-file` para enviar o arquivo para:

```text
Documents/ALTPairingFile.mobiledevicepairing
```

Depois volte ao 3105, abra **CONFIG** e toque em **Procurar pairing**. Se uma versão do `pymobiledevice3` não informar onde salvou o record, gere-o com `idevice_pair` e execute:

```bash
python tools/3105-pairing-helper/3105_pairing_helper.py \
  --pin 123456 \
  --pairing-file "/caminho/SEU_UDID.mobiledevicepairing"
```

O bundle ID padrão do 3105 é `com.apple.mobile.MobileHouseArrest`. O app precisa estar instalado com esse bundle ID para que o envio ao Documents encontre o container correto.
