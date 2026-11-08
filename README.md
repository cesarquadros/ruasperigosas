# Rua de Fogo (Godot 4.3)

Beat 'em up 2D em pixel art, estilo Little Fighter 2. 3 heróis (Kael, Murilo, Dr. Vortex), 3 fases, combos, especiais, IA com limite de agressores e controles de toque.

## Rodar no PC
1. Instale o Godot 4.3 (https://godotengine.org/download).
2. Abra a pasta como projeto e aperte F5.
3. Teclado: 1/2/3 escolhe o herói · setas/WASD move (toque duplo corre) · Z soco · X chute · C pular · V energia · F especial · B defesa.

## Build automático (GitHub Actions)
- Pull request: compila o APK como artefato (aba Actions).
- Merge na `main`: cria a release `vX.Y.Z` com o APK e o AAB anexados. `feature/*` sobe a versão menor, os demais prefixos sobem o patch.
- Para o AAB assinado, configure os segredos `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD` e `ANDROID_KEY_ALIAS`; sem eles usa chave temporária.

## Gerar APK manualmente (Android)
1. Instale o JDK 17 e o Android SDK (command-line tools, platform-tools, build-tools 34, platform 34).
2. Godot → Editor → Gerenciar templates de exportação → baixe os da 4.3.
3. Editor → Configurações do editor → Exportar → Android: aponte o SDK e o keystore de debug.
4. Projeto → Exportar → Android → "Exportar projeto" (ou "Executar" com o celular em modo depurador USB).

## Estrutura
- `scripts/game.gd`: toda a lógica (estados, combate, IA, ondas, HUD, toque) e desenho.
- `assets/`: atlas de sprites, efeitos, retratos, cenários e `meta.json` (quadros por animação).

Teste automático: `godot --headless --path . -- --bot`
