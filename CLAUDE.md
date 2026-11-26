# Swan Race: contexto do projeto

Contexto para o Claude Code. Leia antes de qualquer tarefa.

## Visão geral
Jogo de **corrida 3D leve para Android, iOS e PC (Steam)**, feito pela **Schlupfwerk**, um estúdio
indie brasileiro (mantenedor: Manuel Bravo, GitHub @Bravodin). Público: **toda a família**,
incluindo crianças. "Swan Race" é o nome oficial do jogo.

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
- **Renderer: Forward+ no PC, Mobile nos celulares** (ADR 0016). Mudança visual se confere nos dois: `--rendering-method mobile` roda o Mobile no PC.
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

No celular (ADR 0017): ◀ ▶ na mão esquerda; PULAR (maior), TURBO, FREAR e BUZINA na
direita; menu (II, dois toques) ao lado do minimapa (`scripts/ui/touch_controls.gd`).
**Sem botão de acelerar:** no toque o cisne acelera sozinho e FREAR só segura enquanto
apertado. Os botões só aparecem quando o toque é a última entrada usada. Menus ficam
1,5× maiores no celular e o botão Voltar do Android volta no jogo. Inclinação do celular
fica para depois. As funções por terreno (plano antigo):

| Terreno | Acelerar | Frear | Pular |
|---|---|---|---|
| Descida | encolher (+velocidade, curva pior) | abrir as asas (freio) | saltar rampas e obstáculos |
| Corrida | correr | frear | pular obstáculos |
| Água | nadar mais forte | frear | correr sobre a água; com velocidade suficiente, decolar |
| Ar | mergulhar (+velocidade, perde altura) | planar (–velocidade, mantém altura) | bater asas (ganha altura) |

No teclado (PC): A/D ou setas para virar, W/↑ para acelerar,
S/↓ para frear e Espaço para pular. **M** liga/desliga o som em qualquer tela (no
controle: **Back/View/Share**), com aviso na tela; a escolha fica salva (`Settings.sound_on`).

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
  - cores escolhidas de uma **paleta** de 25 cores (esquerda/direita), para funcionar no
    controle. Nomes longos de opções diminuem a letra para caber inteiros (nunca "...").
  - **Óculos:** redondo, quadrado, aviador, viseira e redondo pequeno.
  - **Costas:** mochila, bolsas e ovo ficam perto do pescoço (`PACK_SHIFT`); a bolsa vai
    deitada. Colares ficam no alto do pescoço, acima de golas e capuz.
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
- **Rosto:** cabeça comprida e bicuda, olhos grandes e baixos (cílios ficam livres dos
  chapéus), sem sobrancelhas, e **expressões** automáticas (feliz, bravo no
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

## Abertura (`scenes/intro.tscn`, cena inicial)
- Depois do splash da Godot (fundo azul-marinho da marca), o cartão do estúdio: logo
  **Schlupfwerk** (`assets/brand/schlupfwerk_logo.svg`, cópia do site, importado em 14×) e
  "INDIE GAMES"; qualquer botão pula.
- Depois, o título: um ovo grande balança três vezes e **choca o cisne**, que buzina;
  aparecem "SCHLUPFWERK" e "SWAN RACE" e o "Pressione Start/Enter/Options" piscando. Start,
  Enter, A, clique ou toque vão para o menu (antes do ovo chocar, adianta tudo).

## Menu (home, `scenes/home.tscn`)
- **No PC**, a aba Correr tem **Sair do jogo** (pede confirmação: aperta de novo).
- **Aba Schlupfwerk** (a 4ª): logo, textos do site sobre o estúdio e o botão **Site da Schlupfwerk**
  (abre https://schlupfwerk.com/pt ou /en). **Sem botão de café/doação dentro do jogo**: as lojas
  (principalmente a Apple) rejeitam links de gorjeta; o site tem a página do café.
- **Abas no topo:** **Meus personagens | Correr | Configurações**. Troca pelas **setas**: ↑ no topo
  do conteúdo leva às abas, ←/→ troca (uma vez por toque), ↓ entra. Também Tab/PgUp ou clique.
  **Gatilhos não trocam de aba** (disparavam várias vezes). Abre na aba Correr. Música suave.
- **Fundo:** uma **corrida simulada** (`DemoRace`) com cisnes sorteados (bots), vista de cima por uma
  **câmera de drone**, sem sons de passos. A cada **15 s** muda de mapa; enquanto só existe a Ilha
  Deserta, ela só reinicia (`DemoRace.MAP_TIME`, TODO: trocar de mapa quando houver outros).
- **Correr:** voltas, corredores (1 a 12) e dificuldade, e o botão **CORRER** (A/Cruz, Enter ou
  Start). Ele abre o **seletor de personagem**: "Correr assim" começa a corrida; "Personalizar" vai
  para Meus personagens com aquele personagem.
- **Configurações:** só configurações (Geral, Vídeo, Áudio). As mudanças aparecem na hora, mas só
  são gravadas com **Aplicar** ou **Confirmar**. Botões: **Restaurar padrão** e **Aplicar**; embaixo,
  **Confirmar** (ou Start) salva e volta para Correr; **B/Esc cancela**: volta ao que estava salvo e
  volta para Correr.

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
- **Áudio:** som ligado/desligado (também pelo atalho M / Back), volume geral, música e
  efeitos (padrão de mercado) e som em segundo plano.
- Cenário novo deve respeitar as configurações: sol no grupo `sun`
  (`Settings.configure_sun`), enfeites em MultiMesh no grupo `scenery_detail`
  (`Settings.configure_detail`).

## Áudio
- Barramentos: `Master`, `Music` e `SFX` (`default_bus_layout.tres`).
- **Sons em loop gerados por código** usam `Sfx.pad_loop` (margem depois do fim do loop) e
  o cache usa `Sfx.load_loop`. Sem a margem o mixer lê além do buffer no ponto de loop e o
  jogo fecha no Android (achado no emulador).
- **Música:** cada país/pista terá a sua, **sem direitos autorais** (licença compatível,
  com entrada em `assets/CREDITS.md`, ou composta e sintetizada no código). A primeira pista, na
  praia, pede algo que lembre praia. O dono do projeto escolhe o estilo de cada uma; não adicione
  música por conta própria.
- **Toda música do jogo é alegre e animada** (jogo infantil, para a família): tom maior, andamento
  rápido, ritmo saltitante, nada triste, lento ou sombrio. Vale para pistas, menus, pódio e
  qualquer música nova.
- Músicas por mapa (originais, no código, `scripts/audio/`; `course_race.gd` escolhe pelo mapa e
  as pistas novas não trocam de música na última volta): Rio = samba (`samba_music.gd`), Alpes =
  ländler suíço animado (`alpine_music.gd`), Sideral = house eletrônico estilo francês
  (`space_music.gd`), São Paulo = rock brasileiro (`rock_music.gd`), Floresta Alemã = polka de banda
  de metais estilo Oktoberfest (`brass_music.gd`), Tóquio = estilo abertura de anime
  (`anime_music.gd`), Muralha da China = música chinesa festiva, pentatônica (`chinese_music.gd`),
  Cordilheira dos Andes = cueca chilena em 6/8 (`cueca_music.gd`), Egito = aventura das "Mil e Uma
  Noites", escala hijaz (`arabian_music.gd`; original, sem copiar nenhum filme), Coliseu = marcha
  triunfal romana (`roman_music.gd`), Paris = valsa musette de acordeão (`musette_music.gd`).

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
- **Troncos grandes** atravessados (4 por volta; o último bem depois da 3ª rampa, 9 m de largura, bandeiras vermelhas nas
  pontas): dá para pular ou contornar pelas bordas. **Batendo de frente** num tronco ou numa pedra,
  o cisne para e **reaparece logo depois do obstáculo**, a 0 km/h e piscando por 2 s (nunca fica
  preso). Raspando de lado, só desliza.
- **Lago raso** no meio da volta (42 m), que só desacelera, com **2 pontes** (faixas: água,
  ponte, água, ponte, água). Cada ponte tem um **buraco**, a 30% e a 70% do comprimento:
  pule ou caia na água. A ponte não tem divisórias: só **postes vermelhos e brancos em volta do buraco**.
- **Aceleradores** no chão (4 por volta): empurrão forte e +30% de velocidade por ~1,4 s.
  As setas apontam para a frente.
- **Rampas** de madeira (3 por volta, `IslandTrack.RAMP_SPOTS`, borda amarela e preta): o
  cisne sobe e, no topo, dá um **pulão** (mais alto quanto mais rápido; ~2 m e ~30 m de voo
  a toda), com um empurrão curto, e **plana perdendo velocidade** até pousar perto da
  velocidade normal. Ficam nas retas mais planas e largas: a 1ª passa **por cima do tronco**,
  a 3ª vem logo depois de um acelerador (combo). Os bots bons miram nelas.
- **Alerta de obstáculo** (Configurações → Geral, liga/desliga): "Pule!!" antes de troncos e
  buracos.
- A altura do chão é **interpolada** entre as amostras da pista (sem degraus nas subidas).

**Regras do terreno** (`TrackRules`, iguais para todos os cisnes):
- **Água:** molhado e **55% mais lento**; o fundo desce rápido e o cisne vai afundando.
  Passou da metade do corpo (~9 m além da linha da água): **se afoga**, volta ao centro
  da pista a 0 km/h piscando por 5 s (de transparente a visível) e aparece
  **"Cuidado com a água!!!!"**.
- **Pedras e troncos têm colisão** (círculos registrados pelo cenário em
  `IslandTrack.add_obstacle`); troncos são baixos e dá para pular por cima. **Atenção:** a altura do
  cisne no `SwanMotor` é **acima do chão** (0 = pisando); nunca grave nela a altura do mundo.
- **Mato:** **bate**, a velocidade vai a **0**, balança a cabeça com estrelinhas e se
  vira de volta para a direção da corrida. Leva **2,5 s** para se recuperar.
- **Nunca na contramão:** o cisne não consegue virar mais de 80° da direção da pista.
- **Pedais analógicos:** no controle, **R2/RT acelera** e **L2/LT freia** com a força do gatilho.
  Ao lado do velocímetro há um **indicador de pressão** (acelerador e freio). O **freio é
  progressivo**: gatilho todo abre a asa inteira e para em ~1,2 s; meio gatilho abre meia asa
  e freia pela metade.
- **Na curva** o cisne inclina o corpo e vira a cabeça para o lado da curva.
- **Relevo:** a pista tem subidas e descidas (até ~13 m, inclinação de até ~11% fora do lago,
  medida pela distância percorrida, não por amostra; a borda da água e do mato estreita aos
  poucos, sem "dentes" que jogam o cisne num barranco; na subida a
  câmera abaixa e o cisne sua) e é
  **inclinada nas curvas** (até ~12°, o lado de dentro mais baixo). Subida: perde velocidade e
  o máximo cai até 75%; descida: ganha velocidade e passa dos 50 km/h (até 130%). O cisne
  inclina com o chão; praias altas descem em barranco até o mar.
- **Voltas:** número de voltas na aba Correr do menu (padrão 3). HUD mostra
  "Volta 2/3" e o tempo total. **Última volta:** aviso e a música troca (com fade) para uma
  versão mais rápida e animada (`scripts/audio/final_lap_music.gd`). **Chegada:** apito de 2 s,
  a câmera se afasta girando e, depois, o **pódio**: **um lugar por corredor** (12 corredores, 12 lugares, na ordem 12 10 8 6 4 2 1 3 5 7 9 11), 1º, 2º e 3º com
  medalhas e o **último colocado comemorando como se tivesse vencido** (medalha de "1", asa erguida
  acenando, piscando e rindo de bico aberto; referência do dono do projeto: pato do meme). Todos **dançam de leve**; um **drone** vai e volta em 60° na frente do pódio, com o
  placar (posição, tempo total e melhor volta de cada um, e a melhor volta da corrida) e uma
  **troféu dourado flutuando** sobre a cabeça do 1º, **musiquinha de corrida finalizada** O pódio fica num **trecho reto e plano da própria pista** (`IslandTrack.podium_spot`), de
  costas para a floresta, com os blocos apoiados na areia. (`scripts/audio/victory_music.gd`), até o jogador sair
  (correr de novo ou voltar ao menu).
- **Buzina:** H no teclado, Y/Triângulo no controle. O cisne dá um "honk" e joga a cabeça;
  com cachorro ou gato na bolsa, o bicho late ou mia no lugar.
- **A cada volta:** "Faltam X voltas!" (e "Última volta!" na penúltima).
- **Desenho dos controles** no canto inferior esquerdo da corrida, aceso conforme o que está
  apertado: WASD ou setas (troca sozinho), Xbox (A B X Y, LT/RT) ou PlayStation (✕ ○ □ △, L2/R2).
- **Largada com semáforo:** 3 luzes vermelhas com "tu", verde com "tuuuu" e "Corra!".
- **Afogamento:** som de derrota e 5 bolhas subindo em zigue-zague e estourando com som.
- **Turbo = acelerador a 100%** (acessibilidade): apertar o turbo já acelera tudo, sem precisar de
  dois botões no teclado ou no celular.
- **Turbo com stamina:** X/Quadrado (Shift no teclado) dá mais aceleração e **+20%** de
  velocidade máxima; a stamina (barra acima do velocímetro) **acaba em 3 s** e leva **10 s**
  para encher de novo. O jogador precisa escolher onde usar (subidas).
- **Curva custa:** segurando a curva, o limite de velocidade cai 1% a cada 0,1 s (até
  −30%) e volta ao soltar. **Pouso** de pulo tira 5% da velocidade.
- **Minimapa** no canto superior esquerdo com o ponto de GPS de cada cisne.
- **Dificuldade** (Fácil, Médio, Difícil) em Configurações → Geral; os bots vão usar.
  **No fácil o cisne corre sozinho** (pensando em criança no celular): acelera e tira o pé em
  curva forte a toda. Os botões de acelerar e frear continuam valendo: usou, vira **manual**;
  4 s sem tocar em nenhum dos dois, volta o **automático** (aviso na tela nas duas trocas).
  **Dicas** (seta no alto da tela apontando para onde a pista vai e avisos como "Use o
  turbo!!" numa subida forte): automático (ligado no fácil e no médio), ligado ou desligado.

**Regra de tempo de volta:** o tamanho da pista sai da física do `SwanMotor`. Na pista
plana de 1.000 m, um bom jogador fazia **~1:15** e um ruim **~2:00**. Medido na Ilha Deserta
(880 m pelo meio da areia, com relevo, aceleradores, lago e troncos):
- **Volta boa pelo meio da areia: ~1:10** (1:11 só acelerando, 1:09,5 com turbo nas subidas,
  1:08,3 passando também nos aceleradores).
- **Volta perfeita: ~58 s**, fechando as curvas pela linha de corrida (a mais curta tem ~793 m, 10%
  menos que o meio), com turbo nas subidas e aceleradores. Recorde do dono do projeto: 57,78 s.
  Decisão do dono: **manter assim**, a linha de corrida é uma habilidade que vale a pena.
Se mudar velocidade, aceleração, largura da areia ou o traçado, recalcule (ver `IslandTrack`).

**Segundo mapa: Alpes Suíços** (`AlpsCourse`, `AlpsScenery`, id `swiss_alps`, ADR 0022). **Ponta a
ponta, sem voltas** (`CourseTrack`, `course_race.tscn`): largada no alto da montanha, chegada numa
vilinha de chalés. ~2:00 para um bom piloto:
- **Pista de esqui (~40 s):** 760 m descendo 120 m, 44 m de largura, poucas curvas. O cisne **esquia**
  (`SwanMotor.skiing`): acelerar = agachar (até 72 km/h, curva mais aberta), frear = abrir as asas.
  Pinheiros (não dá para pular), pedras (dá) e **cabras andando** pela pista (`CourseMover`). Redes
  laranja nas laterais.
- **Estrada alpina (~1:20):** 1 km de estrada de duas faixas (sem carros), muitas curvas para os dois
  lados, guard-rail (o cisne desliza nele, sem atordoar), faixa tracejada e pinheiros dos dois lados.
  Troncos atravessados e **vacas e veados cruzando**.
- Escolha do mapa na aba Correr (`Settings.map`, `Maps`); voltas ficam desativadas nos mapas ponta a
  ponta. O recorde é o **tempo total** por mapa. Cada mapa tem a sua música (ver Música, acima).

**Terceiro mapa: Orla do Rio** (`RioCourse`, `RioScenery`, id `rio_beach`, ADR 0023). Ponta a ponta,
**fácil**, ~2:30, **toda plana**: 1,9 km pela curva da baía. Mar à direita (praia com guarda-sóis,
quiosques e redes de vôlei), à esquerda o **calçadão de ondas preto e branco**, coqueiros, a avenida
e uma fileira de prédios, com morros verdes atrás e um pico de granito no fim da baía. Corre-se no
calçadão e na areia. Obstáculos: troncos, **poças pequenas** (pule; sem pular, metade da velocidade
enquanto passa) e **pessoas** passeando no calçadão ou atravessando com prancha de surfe.

**Quarto mapa: Circuito Sideral** (`SiderealCircuit`, `SiderealScenery`, id `sidereal_circuit`,
ADR 0024). **Circuito em 8 com voltas** no espaço (1.355 m, ~1:50 por volta), passando por cima dele
mesmo: um cruzamento é um viaduto de 9 m. **Sem muretas**: saiu da borda ou pisou num dos **buracos**
do piso, o cisne **grita e cai por 3 s** (`Swan.fall`) e volta piscando, como no afogamento
("Cuidado para não cair no espaço!!"). **Asteroides** baixos na pista: pule ou contorne. Céu de
estrelas e nebulosas, piso com bordas que brilham, planetas (um com anéis). Voltas valem aqui (é um
`CourseTrack` em loop: `build_loop`, `looped`).

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

**Teste no Android (já configurado nesta máquina):**
- Presets: **Android** (arm64, Vulkan, para celulares) e **Android (emulador)** (x86_64,
  feature `emulator`, renderizador OpenGL: o Vulkan não desenha no emulador).
  `godot --headless --path . --export-debug "Android" builds/android/SwanRace.apk`.
- Celular (S23 do dono) por USB ou Wi-Fi: `adb install -r`, abrir com
  `adb shell am start -n com.schlupfwerk.swanrace/com.godot.game.GodotAppLauncher`
  (não use `monkey`: ele injeta um evento aleatório). Não mexa no celular enquanto o dono
  joga.
- Emulador: AVD `swanrace` (Android 15 x86_64), `emulator -avd swanrace -gpu host`. É
  mais lento: espere a abertura antes de tocar. Se `adb screencap` travar, use
  `adb emu screenrecord screenshot <arquivo>` (sai em retrato).
- O APK não pede nenhuma permissão (nem internet); confira com `aapt2 dump xmltree`.

**iOS (depois):** num Mac com Xcode, a Godot exporta um projeto do Xcode, que é
compilado e enviado ao TestFlight. No futuro, isso pode rodar no GitHub Actions
(runners macOS são gratuitos para repositórios públicos).

**Steam (depois):** conta no Steamworks e pagamento da taxa do Steam Direct (confira o
valor atual). A Godot exporta para Windows/Linux; o upload é feito com o SteamPipe.
O `LICENSE-EXCEPTION.md` cobre o Steam ("similar distribution platforms").

## Logs
- O jogo guarda até **1000** arquivos de log (`debug/file_logging/max_log_files`), em
  `%APPDATA%Godotpp_userdataSwan Raceogs`, para análise futura (ex.: Firebase).
  Cópia dos antigos em `logs_archive`.

## Ícone e identificador do app
- **Ícone:** variação do logo da Schlupfwerk (o ovo em pixel art com a rachadura dourada): o ovo
  chocou e um cisne sai dele, com a parte de cima da casca na cabeça, sobre fundo azul-céu.
  Gerado por código: `scripts/tools/make_app_icon.gd` (rodar com
  `godot --headless --path . --script res://scripts/tools/make_app_icon.gd`), que grava os PNGs em
  `assets/icon/`. Mudou o desenho? Edite o script e rode de novo; não edite os PNGs à mão.
  - `icon_1024.png`: ícone do projeto (`application/config/icon`) e o da App Store no iOS.
  - Android: `android_main_192.png` (ícone antigo) e o ícone adaptativo em camadas
    (`android_foreground_432.png`, `android_background_432.png`, `android_monochrome_432.png`),
    nos dois presets de Android (`launcher_icons/*`). O desenho da frente fica dentro da zona
    segura de 66%, para nenhuma máscara cortar o cisne.
  - iOS: ainda não há preset; ao criar, use `icon_1024.png` (a Godot gera os outros tamanhos).
- **Identificador:** `com.schlupfwerk.swanrace` no Android (`package/unique_name`), no Firebase e
  como Bundle ID no iOS. Formato de domínio invertido; **nunca muda** depois de publicado na loja
  (o nome exibido, "Swan Race", pode mudar).

## Versionamento
- **Formato:** `1.0.0-build00142` = versão base + número do build. Na tela: `v1.0.0-build00142`
  (até a 0.0.9 era `Alpha 0.0.9-build…`).
- **Versão base** em `project.godot` (`application/config/version`). Estamos na **1.0.0** (primeira
  versão sem "alpha", 2026-11-26; ainda testando as primeiras versões);
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
- **Build para Windows** (enquanto o jogo não está na Steam): preset "Windows Desktop" em
  `export_presets.cfg` (x86_64, pck embutido, nome/empresa no .exe). Templates de exportação do
  Godot da mesma versão em `%APPDATA%\Godot\export_templates\<versão>.stable`. Exportar com
  `godot --headless --path . --export-release "Windows Desktop" builds/windows/SwanRace.exe`,
  testar o .exe e zipar com `LEIA-ME.txt` (PT/EN: como passar pelo SmartScreen) e os arquivos de
  licença (a GPL pede a licença e o link do código junto do binário). Publicar com a tag
  `v<versão>` (desde a 1.0.0; builds de teste usam `-alpha`/`-beta` e saem como pré-lançamento) no
  commit de onde saiu o build. O site aponta para
  `releases/latest`.
  Automático: `.github/workflows/release-windows.yml` faz tudo isso num runner Windows a cada tag
  `v*` (alpha/beta viram pré-lançamento) e anexa o zip ao release; o LEIA-ME fica em
  `dist/windows/LEIA-ME.txt` (`{VERSION}` vem da tag). A assinatura entra como um passo entre o
  export e o zip.
- **Assinatura do .exe:** ainda sem assinatura (o Windows mostra o SmartScreen). Plano: SignPath
  Foundation (grátis para código aberto; pede build automatizado no repositório e um release já
  publicado). O Azure Artifact Signing não atende empresas do Brasil.
- Não invente datas, números ou parcerias em textos do jogo ou da loja.
