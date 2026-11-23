# Contributing to Swan Race

Thanks for wanting to help! 🦢 Swan Race is a small open source game made by
Schlupfwerk with Godot. Contributions are welcome through pull requests.

> 🇧🇷 Português: resumo no final da página.

## How it works

1. **Open an issue first** for anything bigger than a small fix, so we can
   agree on the idea before you spend time on it.
2. **Fork** the repository and create a branch from `main`.
3. Make your change and test it in Godot (see the README for the version).
4. **Sign off every commit** (see "Developer Certificate of Origin" below).
5. Open a **pull request** describing what changed and why. Screenshots or a
   short video help a lot for gameplay and visual changes.

The `main` branch is protected: every change goes through a pull request and
needs a review from the maintainer before it is merged. Not every pull request
will be accepted; the maintainer has the final word on the game's direction.

## Developer Certificate of Origin (DCO)

Every commit must be signed off, confirming that you wrote the change, or have
the right to submit it, under the project's licenses. Add the `-s` flag when
committing:

```
git commit -s -m "Add swan takeoff from water"
```

This adds a line like `Signed-off-by: Your Name <you@example.com>` to the
commit, meaning you agree to the Developer Certificate of Origin 1.1
(https://developercertificate.org/).

## Licensing of your contributions

By submitting a contribution, you agree that:

1. **Code** you contribute is licensed under the GNU GPL version 3 **together
   with the additional permission in `LICENSE-EXCEPTION.md`**, which allows
   the game to be published in app stores such as the Apple App Store and
   Google Play.
2. **Assets** you contribute (anything under `assets/`) are licensed to the
   public under CC BY-NC-SA 4.0, as described in `ASSETS_LICENSE.md`, **and**
   you also grant the project maintainer a non-exclusive, worldwide,
   royalty-free, perpetual and irrevocable license to use, modify and
   distribute those assets in the official game, **including commercial
   distribution** in app stores and as part of optional paid items such as
   cosmetic skins.
3. You keep the copyright to your contribution, and you will be credited in
   `CREDITS.md`.

If you include anything made by someone else (a model, sound or texture),
it must have a license compatible with the above, and you must add its author,
source and license to `assets/CREDITS.md`.

## Style

- GDScript follows the official Godot style guide (snake_case, tabs).
- Keep game logic separate from input and visuals, so bots and online players
  can use the same code paths.
- Keep the game light: compress textures and keep models low poly.
- Write commit messages and code comments in English.

## Code of conduct

Be kind and respectful. This is a family-friendly game, and the project space
should be too. Harassment or offensive content leads to removal from the
project.

---

## Resumo em português

- Para mudanças grandes, **abra uma issue antes** para combinar a ideia.
- Faça um fork, crie uma branch e abra um **pull request**. Tudo passa pela
  revisão do mantenedor antes de entrar na `main`.
- **Assine cada commit** com `git commit -s` (DCO).
- Ao contribuir, você concorda que:
  - o **código** entra sob GPLv3 com a permissão extra para lojas de apps;
  - os **assets** entram sob CC BY-NC-SA 4.0 para o público e, além disso, você
    autoriza o mantenedor a usá-los no jogo oficial, **inclusive comercialmente**
    (lojas de apps e skins pagas);
  - você continua dono do que fez e recebe crédito no jogo.
- Seja gentil: é um jogo para toda a família.

*Este resumo é informativo; vale o texto em inglês acima.*
