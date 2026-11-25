# Swan Race (codinome): contexto do projeto

Contexto para o Claude Code. Leia antes de qualquer tarefa.

## Visão geral
Jogo de **corrida 3D leve para Android, iOS e PC (Steam)**, feito pela **Schlupfwerk**, um estúdio
indie brasileiro (mantenedor: Manuel Bravo, GitHub @Bravodin). Público: **toda a família**,
incluindo crianças. "Swan Race" é um nome provisório.

**Tom do jogo:** o nosso cisne **não sabe voar nem nadar** e **corre todo desengonçado**, quase um
pato. Isso é a graça: animações, sons e textos devem abraçar esse jeito atrapalhado.

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
  - **Slots (um item por vez, depois a cor):**
    - **Cabeça:** boné, chapéu de palha, cartola, chapéu de cowboy, gorro, peruca cacheada,
      peruca lisa.
    - **Roupa** (com volume, não colada no corpo): jaqueta de couro, jaqueta de inverno,
      regata, moletom. Jaquetas e moletom viram mangas nas asas.
    - **Costas** (balançam com a passada): mochila, bolsa, capa de super-herói (esvoaça
      com a velocidade), bolsa com cachorrinho (late), bolsa com gatinho (mia), ovo de
      avestruz.
    - **Calçado:** descalço (pé de 2 dedos, como avestruz), tênis, botas, sapatos, chinelo
      japonês (geta).
  - **Óculos:** formato (redondo, quadrado, aviador, viseira), cor da armação e lente
    sólida ou em gradiente.
  - **Colar** (slot): círculo, em V ou pérolas, com cor.
  - **Extras:** batom (só na ponta do bico, com cor), cílios (sim/não, longos para cima), meias
    (até a metade da perna, com cor).
  - **Óculos** ficam no meio do bico. **Jaquetas abertas na frente**, sem barra embaixo.
  - **Até 10 personagens** salvos no aparelho (`Profile.characters`, `Profile.selected`), cada um
    personalizado à parte; "+ Novo" cria um com visual sorteado, "Apagar" remove (sempre fica 1).
    Tudo salva na hora.
  - Editor (`CharacterEditor`): todas as opções visíveis sem rolar (duas colunas).
  - No vestiário a **câmera vai até a parte editada** (rosto, pescoço, corpo, costas, pés)
    e vira o cisne para mostrá-la.
  - No vestiário o cisne gira sozinho até o jogador girar (Q/E, LB/RB, analógico direito
    ou arrastando com o mouse). Cada opção é **‹ | valor | ›**: A/Cruz avança, X/Quadrado
    ou Backspace volta.
  - cores escolhidas de uma **paleta** (esquerda/direita), para funcionar no controle.
- **Apelido** de até 16 caracteres, com botão de sortear (para quem está sem teclado).
  Aparece acima do cisne e no HUD.
- **Todos os cisnes têm exatamente a mesma habilidade.** Não existem cisnes mais
  rápidos, mais leves ou com atributos diferentes; os números do movimento são os
  mesmos para todos (`SwanMotor`).
- **É um cisne, não um carro:** no chão, no máximo **50 km/h**, chegando lá em uns
  **4,5 s**. Passadas longas, pernas afastadas.
- **Jeito desengonçado:** pernas com joelho que dobra; o corpo balança e torce a cada passada; quanto
  mais rápido, **mais baixa a cabeça** e **mais as asas apontam para trás**.
- **Roupas são camadas de tecido** separadas do corpo (`shaders/cloth.gdshader`): jaquetas e
  moletom são soltos, a barra balança e vai para trás com a velocidade; a regata é justa.
- **Rosto:** cabeça e olhos maiores, sobrancelhas e **expressões** automáticas (feliz, bravo no
  turbo/subida, surpreso no ar, tonto ao bater, chorando ao se afogar ou em último, rindo ao
  vencer); pisca de vez em quando. Pernas com **escamas** (tracinhos de pata de galinha).
- **Pulo:** sobe rápido e **desce planando de asas abertas**.
- **Contorno fino e suave** em todo o cisne (casca invertida, segunda passada dos
  materiais) e **penas visíveis** (escamas de penas no shader, penas longas nas asas e
  leque na cauda).
- **Rastro de pegadas** de até 3 s, que muda com o calçado: patinha de cisne descalço,
  e marcas diferentes para tênis, bota, sapato e chinelo. Nada de pegada na água.
- **Efeitos:** ao **acelerar**, solta um rastro de fumaça/poeira; ao **frear**, abre as
  asas e solta um vento; ao **cair de um pulo**, o corpo achata e solta um anel de poeira.
- **Sons:** passos na areia (grãos + baque, 4 variações sorteadas), pulo, aterrissagem
  e batida no mato. Por enquanto são sintetizados no código (`scripts/audio/sfx.gd`).
- **Música provisória da Ilha Deserta:** composta e sintetizada no código
  (`scripts/audio/island_music.gd`: ukulele, steel guitar, baixo e chocalho, clima
  havaiano), gerada numa thread e guardada em `user://`. Será trocada pela definitiva.
- **HUD com cara de selva, nunca de carro:** o velocímetro é um disco de madeira com
  grafismo na borda, um cipó de folhas que cresce com a velocidade e uma pena como
  ponteiro.

## Menu (home, `scenes/home.tscn`)
- **Abas no topo:** **Meus personagens | Correr | Configurações** (Tab/PgUp no teclado, LT/RT no
  controle, ou clique). Abre na aba Correr. Música suave.
- **Fundo:** uma **corrida simulada** (`DemoRace`) com cisnes sorteados (bots), vista de cima por uma
  **câmera de drone**, sem sons de passos. A cada **15 s** muda de mapa; enquanto só existe a Ilha
  Deserta, ela só reinicia (`DemoRace.MAP_TIME`, TODO: trocar de mapa quando houver outros).
- **Correr:** voltas, corredores (1 a 12) e dificuldade, e o botão **CORRER** (A/Cruz, Enter ou
  Start). Ele abre o **seletor de personagem**: "Correr assim" começa a corrida; "Personalizar" vai
  para Meus personagens com aquele personagem.
- **Configurações:** só configurações (Geral, Vídeo, Áudio); B/Esc volta para Correr.

## Idiomas
- **Português** se o aparelho estiver em português; **inglês** em qualquer outro caso.
  O jogador pode escolher em Configurações → Geral → Idioma (Automático, Português,
  English); a escolha fica salva em `user://settings.cfg`.
- **Confirmar e voltar** estão declarados no projeto: `ui_accept` = Enter, Espaço, A/Cruz;
  `ui_cancel` = Esc, B/Círculo (não dependa dos padrões da Godot).
- **Nenhum texto de interface fixo no código:** use chaves em
  `translations/strings.csv` (colunas `en` e `pt`) com `tr("CHAVE")`. Ao criar texto
  novo, adicione a chave nas duas línguas. Apelidos sorteados têm listas por idioma.

## Configurações (autoload `Settings`, `user://settings.cfg`)
Salvas só no aparelho, **nunca sincronizadas** (dependem do hardware). Tela em
`scripts/ui/settings_menu.gd`, toda navegável por controle (LB/RB ou Q/E trocam de aba).
- **Geral:** idioma.
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
**Primeiro circuito (feito): Ilha Deserta** (`IslandTrack`, `IslandScenery`, id
`desert_island`). Voltas na praia de uma ilha deserta, **880 m**, com curvas fechadas para a
**esquerda (~19 m de raio) e grampos para a direita (~10 m) nas baías** e **largura da areia variável** (~20 a 40 m).
- **Mata Atlântica à esquerda:** morros, árvores de copa redonda, emergentes, embaúbas,
  palmitos-juçara, ipês amarelos e rosas, quaresmeiras, coqueiros, bananeiras,
  samambaias, bromélias, helicônias, hibiscos e pedras com musgo. Tudo com tamanho,
  proporção e inclinação variados (nada repetido).
- **Mar à direita:** ondas, manchas de cor, espuma rolando na praia, rochas com espuma,
  ilhéu com farol, veleiros ao longe e peixes pulando.
- Sol visível no céu e sombras longas. Música provisória com cara de Havaí.
- Largada com faixa e pórtico quadriculados, contagem regressiva, voltas cronometradas
  e melhor volta salva.

**Obstáculos e atrações da pista** (`IslandTrack`, posições fixas na volta):
- **Troncos grandes** atravessados (4 por volta, 9 m de largura, bandeiras vermelhas nas
  pontas): dá para pular ou contornar pelas bordas; batendo, fica tonto.
- **Lago raso** no meio da volta (42 m), que só desacelera, com **2 pontes** (faixas: água,
  ponte, água, ponte, água). Cada ponte tem um **buraco**, a 30% e a 70% do comprimento:
  pule ou caia na água. Postes vermelhos e brancos marcam pontas e buracos.
- **Aceleradores** no chão (4 por volta): empurrão forte e +30% de velocidade por ~1,4 s.
- **Alerta de obstáculo** (Configurações → Geral, liga/desliga): "Pule!!" antes de troncos e
  buracos.
- A altura do chão é **interpolada** entre as amostras da pista (sem degraus nas subidas).

**Regras do terreno** (`TrackRules`, iguais para todos os cisnes):
- **Água:** molhado e **55% mais lento**; o fundo desce rápido e o cisne vai afundando.
  Passou da metade do corpo (~9 m além da linha da água): **se afoga**, volta ao centro
  da pista a 0 km/h piscando por 5 s (de transparente a visível) e aparece
  **"Cuidado com a água!!!!"**.
- **Pedras e troncos têm colisão** (círculos registrados pelo cenário em
  `IslandTrack.add_obstacle`); troncos são baixos e dá para pular por cima.
- **Mato:** **bate**, a velocidade vai a **0**, balança a cabeça com estrelinhas e se
  vira de volta para a direção da corrida. Leva **2,5 s** para se recuperar.
- **Nunca na contramão:** o cisne não consegue virar mais de 80° da direção da pista.
- **Pedais analógicos:** no controle, **R2/RT acelera** e **L2/LT freia** com a força do gatilho.
  Ao lado do velocímetro há um **indicador de pressão** (acelerador e freio). O **freio é
  progressivo**: gatilho todo abre a asa inteira e para em ~1,2 s; meio gatilho abre meia asa
  e freia pela metade.
- **Na curva** o cisne inclina o corpo e vira a cabeça para o lado da curva.
- **Relevo:** a pista tem subidas e descidas (até ~15 m, rampas de até ~16%; na subida a
  câmera abaixa e o cisne sua) e é
  **inclinada nas curvas** (até ~12°, o lado de dentro mais baixo). Subida: perde velocidade e
  o máximo cai até 75%; descida: ganha velocidade e passa dos 50 km/h (até 130%). O cisne
  inclina com o chão; praias altas descem em barranco até o mar.
- **Voltas:** número de voltas na aba Correr do menu (padrão 3). HUD mostra
  "Volta 2/3" e o tempo total. **Última volta:** aviso e a música troca (com fade) para uma
  versão mais rápida e animada (`scripts/audio/final_lap_music.gd`). **Chegada:** apito de 2 s,
  a câmera se afasta girando e, depois, o **pódio**: **um lugar por corredor** (12 corredores, 12 lugares), 1º, 2º e 3º com
  medalhas e o **último colocado comemorando como se tivesse vencido** (medalha de "1", garrafa
  espirrando espuma, piscando e rindo de bico aberto; referência do dono do projeto: pato do meme). Todos **dançam de leve**; um **drone** vai e volta em 60° na frente do pódio, com o
  placar (posição, tempo total e melhor volta de cada um, e a melhor volta da corrida) e uma
  **troféu dourado flutuando** sobre a cabeça do 1º, **musiquinha de corrida finalizada** (`scripts/audio/victory_music.gd`), até o jogador sair
  (correr de novo ou voltar ao menu).
- **Buzina:** H no teclado, Y/Triângulo no controle. O cisne dá um "honk" e joga a cabeça;
  com cachorro ou gato na bolsa, o bicho late ou mia no lugar.
- **A cada volta:** "Faltam X voltas!" (e "Última volta!" na penúltima).
- **Desenho dos controles** no canto inferior esquerdo da corrida, aceso conforme o que está
  apertado: WASD ou setas (troca sozinho), Xbox (A B X Y, LT/RT) ou PlayStation (✕ ○ □ △, L2/R2).
- **Largada com semáforo:** 3 luzes vermelhas com "tu", verde com "tuuuu" e "Corra!".
- **Afogamento:** som de derrota e 5 bolhas subindo em zigue-zague e estourando com som.
- **Turbo com stamina:** X/Quadrado (Shift no teclado) dá mais aceleração e **+20%** de
  velocidade máxima; a stamina (barra acima do velocímetro) **acaba em 3 s** e leva **10 s**
  para encher de novo. O jogador precisa escolher onde usar (subidas).
- **Curva custa:** segurando a curva, o limite de velocidade cai 1% a cada 0,1 s (até
  −30%) e volta ao soltar. **Pouso** de pulo tira 5% da velocidade.
- **Minimapa** no canto superior esquerdo com o ponto de GPS de cada cisne.
- **Dificuldade** (Fácil, Médio, Difícil) em Configurações → Geral; os bots vão usar.
  **Dicas** (seta no alto da tela apontando para onde a pista vai e avisos como "Use o
  turbo!!" numa subida forte): automático (ligado no fácil e no médio), ligado ou desligado.

**Fundo do pódio por mapa:** cada mapa tem uma **imagem pintada de fundo para o pódio**
(`assets/tracks/<mapa>/podium_background.png`, fornecida pelo dono do projeto). O pódio fica parado
num
palco à parte (no alto, longe do mapa 3D), com o fundo num painel grande atrás dele, na própria cena
(só a câmera se mexe; o painel acompanha 60% do giro para a borda nunca aparecer) e um chão
invisível que só mostra as sombras. **Ao criar um mapa novo, peça ao dono do projeto o fundo do
pódio.**

**Regra de tempo de volta:** o tamanho da pista sai da física do `SwanMotor`. Na pista
plana de 1.000 m, um bom jogador fazia **~1:15** e um ruim **~2:00**. Alvo atual: **volta perfeita
~1:10** → 880 m com relevo (1:11,6 saindo parado, 1:09 lançada, ~1:07 com turbo nas subidas). Se mudar velocidade ou aceleração, recalcule (ver
`IslandTrack`).

Pistas com os 4 terrenos, inspiradas em lugares reais. Cada país pode trocar o tipo de
descida:
- **Suíça**: neve nos Alpes → vilarejo → lago alpino → voo pelos vales
- **Alemanha**: Floresta Negra/Baviera → cidade medieval → rio Reno → voo sobre castelos
- **Rio de Janeiro**: sandboard ou descida na grama de um morro → vielas e escadarias
  coloridas da favela → mar de Copacabana → voo contornando o Pão de Açúcar.
  Retrate o lado vibrante e colorido (casas, pipas, música); **nunca** violência.

## Bots (`BotBrain`, IA local)
- De 0 a 11 bots (Corredores no menu), largando em grid de 2 em 2, com **nomes sorteados** e
  **visual sempre bem diferente do jogador** (`BotLooks`: outra cor de penas, outros itens).
- **Habilidade sorteada** dentro da faixa da dificuldade (fácil 0,3–0,55, médio 0,5–0,8, difícil
  0,75–0,98): define o quanto acelera, acerta pulos (troncos, buracos das pontes), usa turbo nas
  subidas, procura aceleradores e pega a ponte no lago. Batendo num tronco, contorna pela ponta.
- **Fácil:** bot muito à frente do jogador tira o pé (*rubber banding*).
- **Os cisnes se empurram** de leve quando encostam (`TrackRules.push_apart`).
- HUD mostra a **posição** ("3º / 8"); no minimapa o jogador é amarelo e os bots, **cinza**.
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

**Depois (anotado):** controle de hora do dia e clima; neve escorregadia; o voo (o dono
do projeto vai explicar antes); novos mapas (e trocar o mapa da corrida demo da home).

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

## Versionamento
- **Formato:** `0.0.1-build00142` = versão base + número do build. Na tela: `Alpha 0.0.1-build00142`.
- **Versão base** em `project.godot` (`application/config/version`). Estamos na **alpha 0.0.1**;
  só o dono do projeto decide quando ela sobe.
- **Número do build automático** = quantidade de commits do git (`git rev-list --count HEAD`).
  Nunca edite à mão. O plugin `addons/build_info` grava `build_info.cfg` dentro de cada
  exportação (com o hash do commit) e preenche o versionCode/versionName do Android e a
  versão do executável do Windows. Pelo editor, `GameVersion` lê direto do git.

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
