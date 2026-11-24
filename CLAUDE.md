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
  o celular. Ordem: Android → Windows + Linux → macOS junto com iOS (quando houver Mac).
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
Esquerda/direita (botões no lado esquerdo da tela, ou **inclinação do celular**,
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
partir da água. Prototipe e ajuste isso antes de qualquer outra coisa.

## Pistas
Inspiradas em lugares reais. Cada país pode trocar o tipo de descida:
- **Suíça**: neve nos Alpes → vilarejo → lago alpino → voo pelos vales
- **Alemanha**: Floresta Negra/Baviera → cidade medieval → rio Reno → voo sobre castelos
- **Rio de Janeiro**: sandboard ou descida na grama de um morro → vielas e escadarias
  coloridas da favela → mar de Copacabana → voo contornando o Pão de Açúcar.
  Retrate o lado vibrante e colorido (casas, pipas, música); **nunca** violência.

## Bots
- Cada bot tem **nome, skin e personalidade** (ex.: ótimo na descida e ruim no voo).
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
- **Skins por recolor:** um shader com uma textura-máscara (corpo, asas, bico, detalhes)
  e uma paleta de 3 ou 4 cores por skin. Cada skin é um recurso de dados (id, nome,
  cores), sem modelo nem textura nova. Acessórios (chapéu, cachecol) podem vir depois.
  Todo item tem um **id fixo que nunca muda**.
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
  ui/            HUD, menus
assets/          modelos, texturas, sons e músicas (licença CC BY-NC-SA 4.0)
  CREDITS.md     autores e licenças de assets de terceiros
docs/
```

## Primeiro marco: protótipo jogável
- Uma pista reta e curta com os 4 terrenos em sequência (cerca de 1 minuto de corrida)
- O cisne low poly montado com formas simples (sem arte final ainda)
- 2 bots com personalidades diferentes
- HUD: terreno atual, velocidade, posição, tempo, contagem regressiva e resultado
- Botões de toque com o texto mudando conforme o terreno
- Inclinação opcional com calibração
- Jogável com controle de Xbox e de PS5 no PC
- Rodando no Samsung S23 (Android). O iOS fica para quando houver um Mac; o Steam,
  para depois do protótipo.

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
- Não invente datas, números ou parcerias em textos do jogo ou da loja.
