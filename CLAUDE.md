# FREE: regras do projeto para o Claude Code

- **Sandbox (D99):** sempre que um componente novo for criado (um símbolo novo no mapa, em
  `LevelData.GLYPHS`, ou um tipo de objeto novo, em `scripts/editor/objects.gd`), ponha um exemplo
  dele em `tools/levels/sandbox.py` e rode `python3 tools/levels/sandbox.py`. O teste
  `test_sandbox` (em `tests/run_tests.gd`) falha se faltar algum. Exceção: o ácido (`%`), porque
  uma sala só aceita um fluido e a sandbox usa água.
- **Testes:** `godot --headless --path . -s tests/run_tests.gd` e `-s tests/editor_tests.gd`.
- **Campanha:** fases em `levels/campaign`, provadas por replay (`*.replay.json`) ou por bot (`BOT_IDS`
  nos testes). Mudou a física? Rode os testes; rotas do robô se refazem com `tools/robot.gd` e os
  replays com `tools/update_replay.gd` (não mexe nos arquivos das fases).
- **Decisões** ficam em `docs/DECISOES.md` (numeradas, D1…); o resto da documentação em `docs/`.
