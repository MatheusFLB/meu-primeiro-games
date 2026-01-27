# CURURU SOVADO (Godot 4.x)

Esse jogo foi todo gerado por IA
"Is this much better than I could do by hand? Sure is." torvalds

Mini-jogo 2D estilo **Frogger** (vis�o top-down) feito com n�s simples do Godot e imagens na pasta `assets`.

Estrutura exigida:
- `res://scenes/`
- `res://scripts/`
- `res://project.godot`

## Como abrir no Godot
1. Abra o **Godot 4.x**.
2. Clique em **Import**.
3. Selecione a pasta deste projeto (onde est� o arquivo `project.godot`).
4. Confirme a importa��o e abra o projeto.

## Como rodar no desktop
1. Abra a cena principal (opcional): `res://scenes/Main.tscn`.
2. Clique em **Play** (F5).
3. Controles:
- Teclado: setas ou WASD.
- Toque (somente mobile): D-pad na parte inferior.

## Como testar/exportar para Android (vis�o geral)
Voc� vai precisar:
- Export templates instalados.
- Android SDK configurado no Godot.
- Uma keystore (mesmo que seja debug, para testes locais).

### 1) Instalar export templates
1. No Godot: **Editor > Manage Export Templates**.
2. Baixe/instale os templates para sua vers�o do Godot 4.x.

### 2) Configurar Android SDK e keystore
1. V� em **Editor > Editor Settings**.
2. Procure por **Export > Android**.
3. Configure os caminhos do Android SDK/JDK e ferramentas (ADB, jarsigner, etc.).
4. Em **Export > Android**, configure a keystore (debug ou release).

Observa��o: os nomes exatos dos campos podem variar um pouco entre vers�es 4.x, mas ficam sempre dentro de *Editor Settings > Export > Android*.

### 3) Criar preset de export Android
1. V� em **Project > Export**.
2. Clique em **Add...** e escolha **Android**.
3. Ajuste:
- Package / Unique Name (ex.: `com.seunome.cururusovado`).
- Version Code / Version Name.
- Permiss�es m�nimas (se necess�rio).

## Como gerar AAB (.aab)
1. Em **Project > Export**, selecione o preset **Android**.
2. Marque a op��o de **Android App Bundle / Export AAB** (o nome pode variar conforme a vers�o).
3. Clique em **Export Project**.
4. Escolha a pasta e o nome do arquivo `.aab`.

O arquivo final ser� salvo exatamente no caminho que voc� escolher no di�logo de exporta��o.

## Notas
- Ads / Play Store / servi�os online ficam para uma etapa futura.
