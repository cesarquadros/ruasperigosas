# Regras para quem trabalha neste repositório (inclusive o Claude)

- Nunca commitar nem dar push direto na `main`. Sempre criar uma branch com prefixo (`feature/`, `fix/`, `doc/`, `ci/`, `refactor/`, `chore/`) e abrir um pull request.
- Quem faz o merge é o dono do repositório, salvo pedido explícito em contrário.
- As Actions rodam em pull requests (compila o APK como artefato) e no merge na `main` (cria a release com o APK). Todo merge gera uma release; não crie tags de release à mão.
- Versão automática: branch `feature/*` sobe a versão menor (v0.1.0 → v0.2.0); qualquer outro prefixo sobe o patch (v0.1.0 → v0.1.1).
- Antes de abrir o PR, validar o projeto com o Godot 4.3 (`godot --headless --path . --quit-after 120` sem erros).
- Mensagens de commit e documentação em português.
