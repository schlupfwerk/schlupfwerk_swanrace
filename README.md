# Swan Race

A light 3D racing game for Android, iOS and PC (Steam: Windows, Linux/Steam Deck and macOS), made with Godot by **Schlupfwerk**.
Race as a swan through four kinds of terrain in a single run:

1. **Downhill**: slide down a mountain at full speed
2. **Run**: sprint through streets and trails
3. **Swim**: cross lakes, rivers and the sea, then run on the water to take off
4. **Fly**: glide, flap and dive to the finish line

Tracks are inspired by real places: 🇨🇭 Switzerland, 🇩🇪 Germany and 🇧🇷 Rio de
Janeiro, with more to come.

> 🇧🇷 Português logo abaixo.

## Principles

- **Offline first**: plays fully offline against AI swans with their own
  personalities.
- **No ads, no data collection.** Online leaderboards (Game Center, Google
  Play Games and Steam) and multiplayer will be optional. What the game sends
  and stores is listed in the [privacy audit](docs/privacy-audit.md).
- **No paid items**: skins are earned by playing. The only purchase is an
  optional tip, which unlocks nothing.
- **Your progress follows you** through your Google, Apple or Steam account.
- **Family friendly.**

## Controls

| Terrain | Left / Right | Accelerate | Brake | Jump |
|---|---|---|---|---|
| Downhill | steer | tuck (more speed) | open wings | jump ramps |
| Run | steer | run | brake | jump obstacles |
| Swim | steer | swim harder | brake | run on water and take off |
| Fly | steer | dive | glide | flap |

Steering can also use the phone's tilt (optional, with calibration).

Play with touch, keyboard or a controller (Xbox, PlayStation and generic
Bluetooth controllers, also on phones). Switch any time: the game follows
whatever you use.

## Status

🐣 **Alpha 0.0.8**: playable prototype on Windows; Android build in testing (touch controls). One track (the Desert Island, with ramps),
AI racers, character customization, an easy mode that runs by itself. Expect rough edges
and big changes.

## Download

**[Download the alpha for Windows](https://github.com/schlupfwerk/schlupfwerk_swanrace/releases/latest)**:
free, no installation. Unzip it and open `SwanRace.exe`. Windows may show "Windows protected
your PC" (SmartScreen): click **More info**, then **Run anyway**. Android, iOS and Steam: coming soon.

### Code signing

Free code signing provided by [SignPath.io](https://signpath.io), certificate by
[SignPath Foundation](https://signpath.org). Signing starts once the project is approved;
until then the Windows builds are not signed.

## Building

Clone with [Git LFS](https://git-lfs.com) installed (`git lfs install` once),
since large art files are stored with LFS.

Requirements will be listed here as the project grows:
- Godot 4.x (exact version to be pinned)
- Android: Android SDK and JDK, as described in Godot's export docs
- iOS: a Mac with Xcode
- PC: Windows, Linux/SteamOS and macOS exports from Godot, published on Steam

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md)
first.

## License

- **Code**: [GNU GPL v3](LICENSE) with an
  [additional permission for app stores](LICENSE-EXCEPTION.md)
- **Assets** (`assets/`): [CC BY-NC-SA 4.0](ASSETS_LICENSE.md)
- **Names and logos**: not licensed, see [TRADEMARKS.md](TRADEMARKS.md)

---

## 🇧🇷 Português

Jogo de corrida 3D leve para Android, iOS e PC (Steam), feito em Godot pela
**Schlupfwerk**. Você corre como um cisne por quatro terrenos numa mesma
corrida: **descida** de montanha, **corrida**, **nado** (com decolagem correndo
sobre a água) e **voo** até a linha de chegada. As pistas são inspiradas na
Suíça, na Alemanha e no Rio de Janeiro.

- Funciona **offline**, contra cisnes controlados por IA.
- **Sem anúncios e sem coleta de dados.** Placares e multiplayer serão
  opcionais. O que o jogo envia e guarda está na
  [auditoria de privacidade](docs/privacy-audit.md).
- **Sem itens pagos:** as skins são ganhas jogando. A única compra é uma
  gorjeta opcional, que não libera nada.
- O progresso acompanha você pela sua conta Google, Apple ou Steam.
- Jogue com toque, teclado ou controle (Xbox, PlayStation e controles
  Bluetooth genéricos, inclusive no celular), trocando quando quiser.
- Feito para **toda a família**.

O código é **GPLv3** (com permissão extra para lojas de apps), os assets são
**CC BY-NC-SA 4.0**, e o nome e o logo não estão licenciados. Quer ajudar? Leia
o [CONTRIBUTING.md](CONTRIBUTING.md).
