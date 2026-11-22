# Tarefas de Execução — Parte Mandatória (Fly-In v2.0)

> Plano de execução **passo a passo** da parte mandatória do projeto **Fly-In**
> (subject oficial **v2.0**). Cada tarefa tem: **objetivo**, **arquivos afetados**,
> **ações**, **critério de conclusão** e **dependências**. Termos técnicos em
> inglês; explicação em português.
>
> **Ordem recomendada:** seguir a numeração. Fases 0–3 são pré-requisito do
> núcleo. **A representação visual (Fase 8) é MANDATÓRIA** — não é bônus. O único
> bônus é o Challenger em 43 turnos (Fase 13). A branch dos guias é `Guias` (não
> mergear na `main`); o código do projeto pode ir em outra branch.

**Restrições bloqueantes (do subject):** Python 3.10+; **sem bibliotecas de grafo**
(`networkx`, `graphlib`, …); **projeto OO**; `flake8` e `mypy` sem erros; type hints;
docstrings PEP 257; exceções tratadas. Falhar em qualquer uma = reprovação.

**Convenções:** `start_hub`/`end_hub` têm capacidade ilimitada; `normal`/`priority`
custam 1 turno, `restricted` custa 2 (1 em trânsito), `blocked` é impassável;
capacidade de conexão é compartilhada nas duas direções.

---

## Fase 0 — Setup do Repositório e Ambiente

### T0.1 — Inicializar estrutura, `.gitignore` e mapas
- **Objetivo:** base versionada e limpa, **com arquivos na raiz**.
- **Arquivos:** `.gitignore`, estrutura de diretórios.
- **Ações:**
  - Descompactar `tar -xzf maps.tar.gz` (gera `maps/`).
  - Estrutura sugerida (módulos na raiz do repositório):
    ```
    fly_in.py          # entry point
    models.py          # Zone, Connection, Drone, Network, ZoneType (OO)
    parser.py
    graph.py           # alcançabilidade (BFS) — grafo próprio, SEM networkx
    pathfinder.py      # busca espaço-tempo
    simulation.py
    output.py          # formato de saída
    renderer.py        # representação visual (obrigatória)
    maps/              # easy/ medium/ hard/ challenger/
    tests/
    Makefile
    README.md
    .gitignore
    ```
  - `.gitignore`: `__pycache__/`, `*.pyc`, `.mypy_cache/`, `.pytest_cache/`,
    `dist/`, `build/`, `*.egg-info/`, `venv/`, `.venv/`.
- **Critério:** `git status` limpo; `maps/` presente; arquivos na raiz.
- **Depende de:** —

### T0.2 — Virtualenv e dependências de dev
- **Ações:** `python3 -m venv venv && source venv/bin/activate`;
  `pip install flake8 mypy pytest`.
- **Critério:** `python --version` ≥ 3.10; ferramentas instaladas.
- **Depende de:** T0.1

### T0.3 — `Makefile` (regras obrigatórias)
- **Objetivo:** automatizar as regras do subject (§III.2).
- **Conteúdo mínimo:**
  ```makefile
  .PHONY: install run debug clean lint lint-strict test

  install:
  	pip install flake8 mypy pytest

  run:
  	python3 fly_in.py $(MAP)

  debug:
  	python3 -m pdb fly_in.py $(MAP)

  test:
  	pytest -q

  clean:
  	rm -rf __pycache__ .mypy_cache .pytest_cache tests/__pycache__

  lint:
  	flake8 .
  	mypy . --warn-return-any --warn-unused-ignores --ignore-missing-imports \
  	       --disallow-untyped-defs --check-untyped-defs

  lint-strict:
  	flake8 .
  	mypy . --strict
  ```
- **Critério:** `make lint` executa (mesmo sem código ainda).
- **Depende de:** T0.1

> 🔧 **MARCO 0:** confirme `python3 --version`, `flake8 --version`, `mypy --version`
> e que `make lint` não quebra por sintaxe do Makefile.

---

## Fase 1 — Modelos de Domínio (Orientação a Objetos)

> Esta fase garante o requisito bloqueante de **design OO** e a **ausência de
> bibliotecas de grafo**. Cada classe deve encapsular suas próprias regras.

### T1.1 — `ZoneType` e `Zone`
- **Objetivo:** representar zonas e seu comportamento.
- **Arquivos:** `models.py` (ou `zone.py`).
- **Ações:**
  - `class ZoneType(Enum): NORMAL, PRIORITY, RESTRICTED, BLOCKED`.
  - Método/propriedade de **custo de entrada**: `NORMAL/PRIORITY -> 1`,
    `RESTRICTED -> 2`, `BLOCKED -> impassável`.
  - `@dataclass Zone`: `name`, `x`, `y`, `zone_type`, `color: str | None`,
    `max_drones: int = 1`; comportamento de "zona especial" (start/end sem limite).
- **Critério:** criar zonas de todos os tipos e obter custo correto.
- **Depende de:** T0.1

### T1.2 — `Connection`
- **Ações:**
  - `@dataclass Connection`: `a`, `b`, `max_link_capacity: int = 1`.
  - `key = tuple(sorted((a, b)))` (canônica; `a-b == b-a`).
  - Adjacência bidirecional.
- **Critério:** `Connection("a","b").key == Connection("b","a").key`.
- **Depende de:** T1.1

### T1.3 — `Drone` e `Network`
- **Ações:**
  - `@dataclass Drone`: `id`, estado/posição (zona atual, em trânsito, rota,
    índice do passo).
  - `Network`: `zones: dict[str, Zone]`, `connections: dict[tuple[str,str], Connection]`,
    `adjacency: dict[str, list[str]]`, `start`, `end`, `nb_drones`.
  - Método `neighbors(zone)`.
- **Critério:** montar `Network` manualmente e navegar pela adjacência.
- **Depende de:** T1.1, T1.2

---

## Fase 2 — Parser e Validação

### T2.1 — Leitura linha a linha
- **Arquivos:** `parser.py`.
- **Ações:**
  - `with open(path, encoding="utf-8")`; ignorar linhas em branco e comentários (`#`).
  - Guardar `line_no` para `Error: line N: ...`.
  - Dispatch pelo prefixo (`nb_drones`, `start_hub`, `end_hub`, `hub`, `connection`).
  - Exceção própria `ParseError(line_no, message)`.
- **Critério:** mapa válido parseia; inválido gera `ParseError` com linha.
- **Depende de:** Fase 1

### T2.2 — Metadados `[...]`
- **Ações:**
  - Extrair `[...]`; `split` por espaço em `key=value` (ordem livre).
  - Chaves por contexto: zonas `zone`/`color`/`max_drones`; conexões `max_link_capacity`.
  - Rejeitar chave desconhecida/duplicada ou valor inválido.
  - `zone=normal` padrão; capacidades inteiros **positivos**.
- **Critério:** metadados inválidos rejeitados com linha e motivo.
- **Depende de:** T2.1

### T2.3 — Validação global (§VII.4)
- **Ações (ao final da leitura):**
  - `nb_drones` presente e > 0; suportar qualquer número de drones.
  - Exatamente um `start_hub` e um `end_hub`.
  - Nomes/coordenadas únicos; nomes sem espaço e sem `-`.
  - Conexões ligam zonas **já definidas**; sem duplicata/auto-conexão.
  - `max_drones` em start/end: **ignorar** (não é erro).
  - Erros com **linha e causa**.
- **Critério:** cada regra tem teste; mensagens claras e `exit 1`.
- **Depende de:** T2.1, T2.2, T1.3

---

## Fase 3 — Grafo e Alcançabilidade (grafo próprio)

### T3.1 — Checagem de caminho (BFS)
- **Arquivos:** `graph.py`.
- **Ações:**
  - BFS a partir de `start` ignorando `blocked` (implementação própria, **sem
    `networkx`**).
  - Se `end` não for alcançado: reportar claramente (ex.:
    `Error: no path from '<start>' to '<end>'`), `exit 1`.
- **Critério:** mapa desconectado é detectado; sem crash e sem loop infinito.
- **Depende de:** Fase 1, T2.3

> 🔧 **MARCO 1:** valide parser + BFS com mapas triviais (linear/fork) e com um
> mapa desconectado caseiro.

---

## Fase 4 — Busca no Espaço-Tempo (Núcleo)

### T4.1 — Estado e vizinhos
- **Arquivos:** `pathfinder.py`.
- **Ações:**
  - Estado `(zone, turn)` + custo acumulado + predecessor.
  - Ações:
    - **wait**: `(zone, turn+1)` se a zona tiver vaga.
    - **move**: vizinho não-`blocked`; chega em `turn + cost` (1 ou 2); valida
      capacidade da conexão no turno de partida e da zona no turno de chegada.
  - `restricted`: reserva conexão na partida e zona no turno seguinte.
- **Critério:** rota single-drone correta sem concorrência.
- **Depende de:** Fase 3

### T4.2 — Dijkstra/A* com heap e desempate priority
- **Ações:**
  - `heapq` ordenado por `(turn, non_priority_moves)`.
  - Primeira vez que `end` sai da heap = chegada mais cedo.
  - Desempate por menos entradas em zonas **não-priority** (não alterar o custo
    primário de `priority`).
  - Reconstruir rota via `parent`; evitar reprocessar pior (`best`/`visited`).
- **Critério:** rota válida e de menor turno; priority escolhida em empate.
- **Depende de:** T4.1

---

## Fase 5 — Planejamento Multi-Drone (Reservation Table)

### T5.1 — Reservation table
- **Arquivos:** `pathfinder.py` / `reservations.py`.
- **Ações:**
  - `zone_use[(zone, turn)] -> int`
  - `link_use[(connection_key, turn)] -> int`
  - `can_use_zone`, `can_use_link`, `reserve_route`.
  - `start`/`end` sem limite.
- **Critério:** após reservar uma rota, as vagas ficam indisponíveis.
- **Depende de:** Fase 4

### T5.2 — Planejamento sequencial priorizado
- **Ações:**
  - Para D1..DN: buscar rota com a tabela atual; reservar; próximo.
  - Se um drone não achar rota no horizonte, expandir horizonte ou reportar erro
    claro (não travar). **(Opcional: testar ordens alternativas para melhorar turnos.)**
- **Critério:** todos roteados **sem violar** capacidades.
- **Depende de:** T5.1

> 🔧 **MARCO 2:** rode `easy/01` e `easy/02`; a frota inteira deve ser roteada e o
> makespan deve bater com o alvo (4 e 4).

---

## Fase 6 — Simulação Turno a Turno

### T6.1 — Motor de turnos
- **Arquivos:** `simulation.py`.
- **Ações:**
  - Movimentos **simultâneos**, decididos a partir do estado **início do turno**.
  - Ordem prática: decolagens → chegadas → movimentos → commit; validar tudo antes.
  - **Desocupar libera vaga no mesmo turno.**
  - `restricted`: transita na conexão e **deve** chegar no turno seguinte;
    conexão liberada no turno da chegada.
  - Não permitir espera em conexão nem 2 movimentos por turno.
  - Drones entregues saem do rastreamento/ocupação.
- **Critério:** mapa executa sem violar nenhuma regra.
- **Depende de:** Fase 5

### T6.2 — Deadlock / desconexão
- **Ações:**
  - Se nenhum drone se mover por N turnos e a frota não terminou, abortar com erro
    claro (exit 1), nunca em loop infinito.
- **Critério:** mapa problemático termina com erro.
- **Depende de:** T6.1

---

## Fase 7 — Saída e CLI

### T7.1 — Formatador de saída
- **Arquivos:** `output.py`.
- **Ações:**
  - Uma linha por turno; movimentos separados por espaço.
  - `D<ID>-<zone>` para chegadas; `D<ID>-<conexão>` para trânsito rumo a
    `restricted` (conexão pelos dois extremos, ex.: `D1-a-b`, ordem canônica).
  - Omitir drones parados/entregues; a simulação termina quando todos chegam.
- **Critério:** formato idêntico ao do subject; `stdout` limpo.
- **Depende de:** T6.1

### T7.2 — Entry point e tratamento de erros
- **Arquivos:** `fly_in.py`.
- **Ações:**
  - `def main(argv: list[str]) -> int:`; exigir caminho do mapa.
  - `try/except` para `FileNotFoundError`, `ParseError`, `SimulationError`,
    `KeyboardInterrupt`; erros em `stderr`; `exit 1`/`130`.
  - Sucesso → `return 0`.
  - `if __name__ == "__main__": sys.exit(main(sys.argv[1:]))`.
- **Critério:** execução válida retorna 0 e imprime só turnos; inválida retorna 1
  sem traceback.
- **Depende de:** T7.1, Fase 2

> 🔧 **MARCO 3:** rode os 9 mapas easy/medium/hard e confira corretude + makespan
> frente à tabela de ótimos.

---

## Fase 8 — Representação Visual (MANDATÓRIA)

> **Não é bônus.** O subject exige feedback visual (terminal colorido e/ou GUI).

### T8.1 — Terminal colorido
- **Arquivos:** `renderer.py`.
- **Ações:**
  - Ao menos uma estratégia: **cores ANSI** no terminal por `color=` (qualquer
    palavra é aceita; sem lista fixa), colorindo nomes de zona/movimentos.
  - Quando a saída for redirecionada/pipe, manter o formato textual limpo
    (sem ANSI) para não contaminar a saída exigida.
  - Opcional: painel/estado das zonas por turno.
- **Critério:** mapa com `color=` exibe feedback colorido; formato de saída intacto.
- **Depende de:** T7.1

### T8.2 — (Alternativa/Adicional) Interface gráfica
- **Ações:** GUI (ex.: `pygame`/Qt) desenhando a rede e as posições dos drones,
  lendo os turnos **já calculados** (o visual não influencia a simulação).
- **Critério:** janela exibe rede e drones; não altera resultado.
- **Depende de:** T7.1

> 🔧 **MARCO 4:** demonstre o feedback visual em um mapa com várias cores. Se fizer
> GUI, garanta que o modo terminal também continua correto.

---

## Fase 9 — Testes

### T9.1 — Testes unitários (`pytest`)
- **Arquivos:** `tests/`.
- **Ações:** cobrir parser (cada regra T2.3), BFS/alcançabilidade, custo por
  `ZoneType`, reservation table (conflito de zona e conexão), planejamento sem
  violação, simulação com `restricted` (2 turnos + trânsito), formatador de saída,
  determinismo e deadlock.
- **Critério:** `make test` verde; edge cases cobertos.
- **Depende de:** Fases 2–8

### T9.2 — Regressão nos mapas
- **Ações:** rodar cada mapa, verificar terminação e que capacidades nunca são
  excedidas; opcionalmente comparar makespan com o ótimo.
- **Critério:** 9 mapas mandatórios passam.
- **Depende de:** T9.1

---

## Fase 10 — Qualidade (Lint, Tipos e OO)

### T10.1 — Type hints e docstrings
- **Ações:** anotar parâmetros/retornos; docstrings PEP 257 em módulos, classes e
  funções (Google/NumPy).
- **Critério:** `mypy . --disallow-untyped-defs --check-untyped-defs` sem erros.
- **Depende de:** código da Fase 8

### T10.2 — flake8 e mypy
- **Ações:** `make lint` (flags exatas) e, recomendado, `make lint-strict`.
- **Critério:** zero erros. **(Bloqueante.)**
- **Depende de:** T10.1

### T10.3 — Revisão de design OO
- **Ações:** garantir classes com responsabilidades claras, encapsulamento e
  ausência de `networkx`/`graphlib`; nenhuma lógica de grafo "de biblioteca".
- **Critério:** design explicável na defesa; `grep` não encontra libs proibidas.
- **Depende de:** Fases 1–8

---

## Fase 11 — Documentação (README em inglês)

### T11.1 — `README.md`
- **Ações:** incluir
  - primeira linha itálica exata com login(s);
  - **Description**, **Instructions**, **Resources** (com uso de IA);
  - **escolhas de algoritmo + estratégia de implementação** (e complexidade);
  - **documentação da representação visual** e como melhora a experiência;
  - **exemplo de entrada e saída esperada**;
  - gestão de equipe/projeto (papéis, planejamento, o que funcionou/melhorar, ferramentas).
- **Critério:** todos os campos presentes; revisão por pares.
- **Depende de:** Fase 8

---

## Fase 12 — Validação Final e Defesa

### T12.1 — Revisão de requisitos
- **Ações:** percorrer o checklist §14 do `ORIENTACAO.md`.
- **Critério:** todos marcados.

### T12.2 — Limpeza e commit
- **Ações:** `make clean`; confirmar arquivos na raiz, `maps/`, `Makefile`,
  `README.md`, `.gitignore`; commit descritivo.
- **Critério:** repositório limpo e completo.

### T12.3 — Ensaio de defesa + modificação ao vivo
- **Ações:** explicar parser, modelos OO, busca `(zone, turn)`, reservation table,
  ordem/simultaneidade do turno, visual, complexidade. Treinar uma **modificação
  rápida** (ex.: novo tipo de custo, validação extra, ajuste de render).
- **Critério:** defender sem consultar; modificar ao vivo sem quebrar lint/regras.
- **Observação:** mapas de avaliação **podem diferir** dos fornecidos.

---

## Fase 13 — Bônus (OPCIONAL — só após Fase 12)

### T13.1 — Challenger em 43 turnos
- **Objetivo:** resolver `challenger/01_the_impossible_dream` no ótimo de **43**.
- **Ações:** otimizar planejamento (ordem de drones, backtracking, CBS/PBS,
  bound por fluxo) sem violar nenhuma regra.
- **Critério:** execução comprova **43 turnos**.
- **Depende de:** Fase 12 completa.

---

## Resumo de Dependências

```
Fase 0 (setup/Makefile)
  └─► Fase 1 (modelos OO)
        └─► Fase 2 (parser) ─► Fase 3 (BFS/alcançabilidade)
              └─► Fase 4 (busca espaço-tempo)
                    └─► Fase 5 (reservation + multi-drone)
                          └─► Fase 6 (simulação)
                                └─► Fase 7 (saída + CLI)
                                      └─► Fase 8 (VISUAL — obrigatório)
                                            ├─► Fase 9 (testes)
                                            ├─► Fase 10 (lint/tipos/OO)
                                            └─► Fase 11 (README)
                                                  └─► Fase 12 (validação/defesa)
                                                        └─► Fase 13 (bônus Challenger 43)
```

> **Regra de ouro:** a **Fase 8 (visual) é obrigatória**, não bônus. Só invista na
> Fase 13 (Challenger) depois que a Fase 12 estiver 100% validada nos mapas
> mandatórios. O núcleo (parser → busca → simulação → saída) é o coração do projeto.
