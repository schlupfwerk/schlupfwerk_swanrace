# Swan Race (codinome): contexto do projeto

Contexto para o Claude Code. Leia antes de qualquer tarefa.

## Visão geral
Jogo de **corrida 3D leve para Android e iOS**, feito pela **Schlupfwerk**, um estúdio
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
- **Renderer: Mobile.** O jogo precisa rodar bem em celulares comuns.
- **Plataformas:** Android e iOS. Não há versão para navegador.
- **Offline primeiro:** o jogo inteiro funciona sem internet, contra bots.
- **Sem anúncios e sem coleta de dados.** Placares e conquistas (Game Center e
  Google Play Games) e o multiplayer são **opcionais** e vêm depois.
- **Monetização:** só **skins cosméticas** e uma **gorjeta** opcional, ambas por
  compra no app. Nada que dê vantagem na corrida.
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

No teclado (para testar no PC): A/D ou setas para virar, W/↑ para acelerar,
S/↓ para frear e Espaço para pular.

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
  - `PlayerInput`: teclado, botões de toque e inclinação
  - `BotBrain`: IA
  - no futuro, `NetworkInput`: jogador online, que substitui um bot
- **Física arcade e determinística**, escrita à mão (posição, velocidade, altura).
  Evite depender do motor de física para o movimento do cisne.
- **Serviços das plataformas por trás de uma camada intermediária**, com
  implementações para iOS, Android e uma falsa para o PC:
  - `Services`: placar, conquistas e save na nuvem (Game Center / Play Games)
  - `Store`: compras de skins e gorjeta (StoreKit / Google Play Billing)
- **Skins por recolor:** um shader com uma textura-máscara (corpo, asas, bico, detalhes)
  e uma paleta de 3 ou 4 cores por skin. Cada skin é um recurso de dados (id, nome,
  cores), sem modelo nem textura nova. Acessórios (chapéu, cachecol) podem vir depois.
- O save local guarda skins, recordes e configurações. Nada é enviado para fora.

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
- Rodando no Samsung S23 (Android). O iOS fica para quando houver um Mac.

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

## Regras do repositório
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
