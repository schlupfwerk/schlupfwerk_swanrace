# Swan Race (codinome): contexto do projeto

Contexto para o Claude Code. Leia antes de qualquer tarefa.

## Visão geral
Jogo de **corrida 3D leve para Android, iOS e PC (Steam)**, feito pela **Schlupfwerk**, um estúdio
indie brasileiro (mantenedor: Manuel Bravo, GitHub @Bravodin). Público: **toda a família**,
incluindo crianças. "Swan Race" é um nome provisório.

O jogador é um **cisne** numa corrida com **quatro terrenos em sequência**:
1. **Descida**: desce uma montanha deslizando em velocidade livre, sem precisar correr
2. **Corrida**: corre por ruas e trilhas
3. **Água**: nada; correndo sobre a água (como cisnes de verdade), ganha velocidade e decola
4. **Voo**: voa até a linha de chegada

Inspiração de formato: corridas no estilo Chocobo Racing, mas com identidade própria.
**Nunca** use nomes, personagens ou arte de outras franquias.

## Decisões já tomadas
- **Engine: Godot 4 (versão estável mais recente), GDScript.** Um único projeto, um
  único repositório. **Não há código em Kotlin nem em Swift.** Código nativo só entra,
  se um dia for preciso, por plugins (Game Center, Play Games, compras).
- **Renderer: Mobile.** O jogo precisa rodar bem em celulares comuns (e roda bem no PC).
- **Plataformas:** Android, iOS e, no Steam, Windows, Linux/SteamOS (Steam Deck,
  build nativo, mirando "Steam Deck Verified") e macOS. Todas saem do mesmo projeto,
  só muda o preset de exportação. Não há versão para navegador. O foco continua sendo
  o celular. **Foco atual: Android, Windows e Linux.** iOS e macOS ficam para
  quando houver um Mac; não gaste esforço neles por enquanto.
- **Offline primeiro:** o jogo inteiro funciona sem internet, contra bots.
- **Sem anúncios e sem coleta de dados.** Placares e conquistas (Game Center,
  Google Play Games e Steam) e o multiplayer são **opcionais** e vêm depois.
- **Sem itens pagos.** Skins e cosméticos são **ganhos jogando**. A única compra é
  uma **gorjeta** opcional, que não libera nada.
- **Save na nuvem pela conta da própria plataforma** (sem servidor nosso): Google
  Play Games no Android, iCloud/Game Center no iOS/macOS, Steam Cloud no Steam.
  Trocar de aparelho dentro do mesmo ecossistema mantém o progresso; entre
  ecossistemas (ex.: Android → iPhone) não. Conta unificada: adiada (ADR 0014).
- **Público infantil:** sem chat aberto e sem links externos sem uma verificação para os pais.

## Controles
**Prioridade agora (protótipo no Windows): teclado, controle de Xbox e de PS5.** O jogo
e os menus têm que ser **100% usáveis sem mouse**. O mouse (e o toque, no celular) é só
uma opção extra nos menus; na corrida ele não faz nada.

No celular: esquerda/direita (botões no lado esquerdo da tela, ou **inclinação do celular**,
opcional e com calibração) e três botões no lado direito. Os botões mudam de função
conforme o terreno:

| Terreno | Acelerar | Frear | Pular |
|---|---|---|---|
| Descida | encolher (+velocidade, curva pior) | abrir as asas (freio) | saltar rampas e obstáculos |
| Corrida | correr | frear | pular obstáculos |
| Água | nadar mais forte | frear | correr sobre a água; com velocidade suficiente, decolar |
| Ar | mergulhar (+velocidade, perde altura) | planar (–velocidade, mantém altura) | bater asas (ganha altura) |

No teclado (PC): A/D ou setas para virar, W/↑ para acelerar,
S/↓ para frear e Espaço para pular.

**Controle (gamepad)**, em todas as plataformas: Xbox, PS4/PS5 e controles genéricos
Bluetooth no celular (Android e iOS). Analógico esquerdo ou direcional para virar,
**RT/R2** acelera, **LT/L2** freia e **A/Cruz** (botão de baixo) pula. Os gatilhos são
analógicos: `accel` e `brake` devem usar a força (`Input.get_action_strength`).
- Os menus inteiros precisam ser navegáveis por controle (foco de UI), não só por toque/mouse.
- Mostrar os ícones de botão do controle conectado (Xbox ou PlayStation, detectado
  por `Input.get_joy_name`); genéricos usam os ícones do Xbox.
- **O jogador escolhe livremente entre toque e controle, a qualquer momento.** Todos
  os métodos de input ficam sempre ativos ao mesmo tempo; o jogo só adapta a tela ao
  **último input usado**:
  - apertou botão/analógico do controle → esconde os botões de toque e mostra os
    ícones do controle;
  - tocou na tela → os botões de toque voltam na hora.
  - Controle conectado/desconectado no meio da corrida (`Input.joy_connection_changed`)
    não pausa nem quebra nada; se desconectar, os botões de toque reaparecem.
  - Uma opção nas configurações para fixar os botões de toque sempre visíveis.

As **transições entre terrenos** são o coração do jogo, principalmente a decolagem a
partir da água. Depois da base (o cisne correndo bem num terreno plano), elas são a
prioridade.

## O cisne
- **Visual:** cisne cartoon misturado com avestruz (pescoço longo em S, corpo redondo,
  pernas compridas). Forma **simples e lisa**, poucos detalhes e poucos triângulos,
  montada com primitivas suaves e shading toon.
- **Personalização** (tudo só visual):
  - penas em **cor sólida ou gradiente** (cor de baixo → cor de cima);
  - cor das **patas**;
  - acessórios: **boné, peruca, óculos, cílios, maquiagem, colar e jaqueta**, cada um
    com cor. Com a jaqueta, as asas viram as mangas.
  - **calçado** (um por vez): **descalço, tênis, botas, sapatos ou chinelo**, com cor.
    Calçado fechado esconde os pés; o chinelo deixa os pés à mostra.
  - cores escolhidas de uma **paleta** (esquerda/direita), para funcionar no controle.
- **Apelido** de até 16 caracteres, com botão de sortear (para quem está sem teclado).
  Aparece acima do cisne e no HUD.
- **Todos os cisnes têm exatamente a mesma habilidade.** Não existem cisnes mais
  rápidos, mais leves ou com atributos diferentes; os números do movimento são os
  mesmos para todos (`SwanMotor`).
- **É um cisne, não um carro:** no chão, no máximo **50 km/h**, chegando lá em uns
  **3 s**. Passadas longas, pernas afastadas.
- **Efeitos:** ao **acelerar**, solta um rastro de fumaça/poeira; ao **frear**, abre as
  asas e solta um vento; ao **cair de um pulo**, o corpo achata e solta um anel de poeira.
- **Sons:** passos (um por passada, mais fortes com a velocidade), pulo e aterrissagem.
  Por enquanto são sintetizados no código (`scripts/audio/sfx.gd`), sem arquivos.
- **HUD com cara de selva, nunca de carro:** o velocímetro é um disco de madeira com
  grafismo na borda, um cipó de folhas que cresce com a velocidade e uma pena como
  ponteiro.

## Configurações (autoload `Settings`, `user://settings.cfg`)
Salvas só no aparelho, **nunca sincronizadas** (dependem do hardware). Tela em
`scripts/ui/settings_menu.gd`, toda navegável por controle (LB/RB ou Q/E trocam de aba).
- **Vídeo:** modo de tela (janela, tela cheia, tela cheia exclusiva), resolução (em
  janela), monitor, qualidade **Baixa/Média/Alta** (ou Personalizada), campo de visão.
- **Vídeo, avançado:** mostrar FPS e frequência da tela, VSync, limite de FPS, escala de
  renderização, antisserrilhamento (MSAA), sombras, detalhes do cenário (quantas árvores e
  enfeites aparecem: grupo `scenery_detail`), placa de vídeo.
- **Placa de vídeo:** por padrão a Godot escolhe a **dedicada** (Vulkan prefere GPU
  dedicada). O jogador pode escolher outra; aplica reiniciando com `--gpu-index`. Se a
  placa escolhida não abrir, o jogo volta sozinho para a automática.
- **Áudio:** volume geral, música e efeitos (padrão de mercado) e som em segundo plano.
- Cenário novo deve respeitar as configurações: sol no grupo `sun`
  (`Settings.configure_sun`), enfeites em MultiMesh no grupo `scenery_detail`
  (`Settings.configure_detail`).

## Áudio
- Barramentos: `Master`, `Music` e `SFX` (`default_bus_layout.tres`).
- **Música:** cada país/pista terá a sua, **sem direitos autorais** (licença compatível,
  com entrada em `assets/CREDITS.md`). A primeira pista, na praia, pede algo que lembre
  praia. O dono do projeto escolhe as músicas; não adicione música por conta própria.

## Pistas
**Primeiro circuito (feito): Praia da Ilha** (`IslandTrack`, `IslandScenery`). Voltas
na praia de uma ilha: **Mata Atlântica à esquerda** (morros, árvores, ipês amarelos,
quaresmeiras roxas, coqueiros) e **mar à direita** (ondas, espuma, peixes pulando).
Linha de largada com faixa e pórtico quadriculados, contagem regressiva, voltas
cronometradas e melhor volta salva. Fora da areia (mata ou água) o cisne fica mais lento.

**Regra de tempo de volta:** o tamanho da pista sai da física do `SwanMotor`. Um bom
jogador, sem bater em obstáculos, fecha a volta em **~1:15**; um jogador ruim, em
**~2:00**. Hoje: 1.000 m de volta; o piloto automático perfeito fez 1:13,7 saindo
parado. Se mudar velocidade ou aceleração, recalcule (ver comentário em `IslandTrack`).

Pistas com os 4 terrenos, inspiradas em lugares reais. Cada país pode trocar o tipo de
descida:
- **Suíça**: neve nos Alpes → vilarejo → lago alpino → voo pelos vales
- **Alemanha**: Floresta Negra/Baviera → cidade medieval → rio Reno → voo sobre castelos
- **Rio de Janeiro**: sandboard ou descida na grama de um morro → vielas e escadarias
  coloridas da favela → mar de Copacabana → voo contornando o Pão de Açúcar.
  Retrate o lado vibrante e colorido (casas, pipas, música); **nunca** violência.

## Bots
- Cada bot tem **apelido, visual e personalidade**. A personalidade muda só o **jeito
  de pilotar** (ex.: arrisca mais na descida, voa com cuidado), nunca os atributos:
  todos os cisnes têm a mesma habilidade.
- Cometem **erros humanos** de vez em quando.
- Dificuldade fácil, normal e difícil. No fácil, um *rubber banding* leve.
- **Bots usam exatamente a mesma interface de controle do jogador** (ver Arquitetura).

## Arquitetura
- **A lógica fica separada do input e do visual.** Cada cisne recebe a cada frame uma
  "intenção" (`steer`, `accel`, `brake`, `jump`) vinda de um **cérebro**:
  - `PlayerInput`: teclado, controle, botões de toque e inclinação (tudo pelas
    mesmas ações do Input Map: `steer_left`, `steer_right`, `accel`, `brake`, `jump`)
  - `BotBrain`: IA
  - no futuro, `NetworkInput`: jogador online, que substitui um bot
- **Física arcade e determinística**, escrita à mão (posição, velocidade, altura).
  Evite depender do motor de física para o movimento do cisne.
- **Serviços das plataformas por trás de uma camada intermediária**, com
  implementações para iOS, Android, Steam e uma falsa para testes no PC:
  - `Services`: placar, conquistas e save na nuvem (Game Center / Play Games / Steamworks)
  - `Store`: só a gorjeta (StoreKit / Google Play Billing / Steam)
  - Steam via plugin **GodotSteam** (GDExtension). Sem DRM obrigatório do Steam.
- **Personalização por dados (ADR 0015):** `SwanLook` guarda apelido, estilo e cores
  das penas, cor das patas e acessórios usados (`id → cor`). As penas usam um shader
  (`shaders/feather.gdshader`) com cor sólida ou gradiente vertical; os acessórios são
  peças simples já presentes no modelo, ligadas/desligadas e recoloridas. Sem textura
  nem modelo novo por item. Todo item tem um **id fixo que nunca muda**.
- **Simulação em passo fixo** (60 ticks/s) dentro do `Swan`, com interpolação na hora
  de desenhar: determinística e lisa em qualquer taxa de quadros.
- **Save:** guarda itens ganhos, personalização, recordes e configurações. O **save
  local é a fonte da verdade** (funciona offline); a nuvem sincroniza quando há
  internet. Conflitos se resolvem **mesclando** (união dos itens, melhor recorde por
  pista, configurações mais recentes). O formato tem número de versão. Nada vai para
  servidor nosso.

## Estrutura de pastas (sugerida)
```
project.godot
scenes/          cenas (.tscn)
scripts/         GDScript
  race/          lógica da corrida, cisne, pista
  input/         PlayerInput, BotBrain
  services/      camada de Services e Store
  save/          save local (autoload Profile)
  ui/            HUD, menus, vestiário
shaders/         shaders (.gdshader)
assets/          modelos, texturas, sons e músicas (licença CC BY-NC-SA 4.0)
  CREDITS.md     autores e licenças de assets de terceiros
docs/
```

## Primeiro marco: protótipo jogável (siga esta ordem)
O protótipo é feito e testado **no Windows**, com teclado e controles de Xbox e PS5.

1. **Praia plana (feito):** terreno 100% reto, sem obstáculos; areia com matinhos e
   pedrinhas só de enfeite (nada afeta o cisne). Cisne andando com esquerda/direita,
   acelerar, frear e pular; velocímetro; rastro ao acelerar e vento ao frear;
   vestiário com personalização e apelido, salvo localmente.
2. **Praia da Ilha (feito):** circuito em volta da ilha, com largada, voltas e tempos.
   **Sensação de corrida:** ajustar velocidade, curva, pulo e câmera até ficar gostoso.
   Obstáculos na praia vêm depois. O **voo** será explicado pelo dono do projeto antes
   de ser feito.
3. **Os 4 terrenos** numa pista reta e curta (cerca de 1 minuto), com as transições,
   principalmente a decolagem da água.
4. **2 bots** com personalidades diferentes (mesma habilidade, ver Bots).
5. **HUD completo:** terreno atual, velocidade, posição, tempo, contagem regressiva e
   resultado.
6. **Android (Samsung S23):** botões de toque com o texto mudando conforme o terreno e
   inclinação opcional com calibração.

iOS fica para quando houver um Mac; o Steam, para depois do protótipo.

Critério de sucesso: **é divertido nos primeiros 30 segundos?**

## Ambiente de desenvolvimento (Windows)
1. **Godot 4**, a versão estável padrão (**não** a .NET), de godotengine.org.
2. **JDK 17** (por exemplo, OpenJDK da Adoptium/Temurin).
3. **Android SDK**: o jeito mais fácil é instalar o **Android Studio** e, no SDK Manager,
   baixar a plataforma, o *build-tools*, o *platform-tools* e o *command-line tools*.
   O Android Studio só serve para baixar o SDK; o código é escrito na Godot.
4. Na Godot: **Editor → Editor Settings → Export → Android**, informe o caminho do
   SDK e do JDK.
5. Na Godot: **Project → Export → Add → Android** para criar o preset de exportação.
6. No S23: ative as **Opções do desenvolvedor** e a **Depuração USB**, e ligue o
   celular no PC por cabo.
7. Na Godot, use o botão de **Remote Deploy** (ícone do Android no canto superior
   direito) para instalar e rodar no celular com um clique.

Siga sempre a página "Exporting for Android" da documentação da versão instalada da
Godot: as versões exatas do SDK e do JDK podem mudar.

**iOS (depois):** num Mac com Xcode, a Godot exporta um projeto do Xcode, que é
compilado e enviado ao TestFlight. No futuro, isso pode rodar no GitHub Actions
(runners macOS são gratuitos para repositórios públicos).

**Steam (depois):** conta no Steamworks e pagamento da taxa do Steam Direct (confira o
valor atual). A Godot exporta para Windows/Linux; o upload é feito com o SteamPipe.
O `LICENSE-EXCEPTION.md` cobre o Steam ("similar distribution platforms").

## Regras do repositório
- Decisões de arquitetura ficam em `docs/adr/` (ADRs, em inglês). Mudou uma decisão?
  Escreva uma ADR nova que substitui a antiga e atualize este arquivo.
- Código: **GPLv3** com permissão extra para lojas de apps (`LICENSE`,
  `LICENSE-EXCEPTION.md`). Assets: **CC BY-NC-SA 4.0** (`ASSETS_LICENSE.md`).
  Nome e logo: `TRADEMARKS.md`.
- Commits **assinados** com `git commit -s` (DCO).
- **Nunca** faça commit de chaves de assinatura (`*.keystore`, `*.jks`, `*.p12`,
  `export_credentials.cfg`). O `.gitignore` já bloqueia.
- Todo asset de terceiros precisa de entrada em `assets/CREDITS.md` com uma licença compatível.
- GDScript no estilo oficial da Godot (snake_case, tabs). Comentários e commits em inglês.
- Mantenha o jogo leve: modelos low poly e texturas comprimidas.
- **Git LFS** para binários grandes e fontes de arte (`.blend`, `.glb`, `.psd`, `.wav`,
  vídeos etc.; a lista está no `.gitattributes`). Antes de commitar um arquivo de um
  tipo novo com mais de ~5 MB, adicione a extensão ao LFS. Nenhum arquivo acima de 100 MB.
- **Builds exportados** (APK, AAB, executáveis) vão para a pasta `builds/` (ignorada)
  e são publicados no GitHub Releases, nunca commitados.
- Não invente datas, números ou parcerias em textos do jogo ou da loja.
