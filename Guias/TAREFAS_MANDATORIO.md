# Tarefas de Execução — Parte Mandatória (Fly-In)

> Plano de execução **passo a passo** da parte mandatória do projeto **Fly-In**.
> Cada tarefa tem: **objetivo**, **arquivos afetados**, **ações**,
> **critério de conclusão** e **dependências**. Termos técnicos em inglês;
> explicação em português.
>
> **Ordem recomendada:** seguir a numeração. Fases 0–3 são pré-requisito do
> núcleo. **Não** comece bônus (visual/challenger) antes de a Fase 11 passar em
> **todos** os mapas. A branch de trabalho dos guias é `Guias` (não mergear na
> `main`); o código do projeto pode ir em outra branch.

**Convenções do projeto:**
- Turnos discretos; `start_hub` e `end_hub` têm capacidade ilimitada.
- `normal`/`priority` custam **1 turno**; `restricted` custa **2** (1 em trânsito);
  `blocked` é impassável.
- Capacidade de conexão é **compartilhada nas duas direções**.

---

## Fase 0 — Setup do Repositório e Ambiente

### T0.1 — Inicializar estrutura e `.gitignore`
- **Objetivo:** base versionada e limpa.
- **Arquivos:** `.gitignore`, estrutura de diretórios.
- **Ações:**
  - Descompactar `tar -xzf maps.tar.gz` (gera `maps/`).
  - Estrutura sugerida:
    ```
    fly_in.py            # entry point
    src/                 # parser, models, graph, planner, simulation, output
    maps/                # easy/ medium/ hard/ challenger/
    tests/
    Makefile
    README.md
    .gitignore
    ```
  - `.gitignore`: `__pycache__/`, `*.pyc`, `.mypy_cache/`, `.pytest_cache/`,
    `dist/`, `build/`, `*.egg-info/`, `venv/`, `.venv/`.
- **Critério:** `git status` limpo; `maps/` presente.
- **Depende de:** —

### T0.2 — Criar e ativar virtualenv
- **Ações:** `python3 -m venv venv && source venv/bin/activate`;
  `pip install flake8 mypy pytest`.
- **Critério:** `python --version` ≥ 3.10; ferramentas instaladas.
- **Depende de:** T0.1

### T0.3 — Criar o `Makefile`
- **Objetivo:** automatizar as regras exigidas.
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
  	rm -rf __pycache__ .mypy_cache .pytest_cache src/__pycache__ tests/__pycache__

  lint:
  	flake8 .
  	mypy . --warn-return-any --warn-unused-ignores --ignore-missing-imports \
  	       --disallow-untyped-defs --check-untyped-defs

  lint-strict:
  	flake8 .
  	mypy . --strict
  ```
- **Critério:** `make lint` executa (mesmo que ainda não haja código).
- **Depende de:** T0.1

---

## Fase 1 — Modelos de Domínio

### T1.1 — `ZoneType` e `Zone`
- **Objetivo:** representar zonas e seu comportamento de custo.
- **Arquivos:** `src/models.py` (ou `src/zone.py`).
- **Ações:**
  - `class ZoneType(Enum): NORMAL, PRIORITY, RESTRICTED, BLOCKED`.
  - Propriedade/método de **custo de entrada**: `NORMAL/PRIORITY -> 1`,
    `RESTRICTED -> 2`, `BLOCKED -> impassável`.
  - `@dataclass Zone`: `name: str`, `x: int`, `y: int`, `zone_type: ZoneType`,
    `color: str | None`, `max_drones: int` (default 1). Start/end tratados
    como capacidade ilimitada na camada de simulação.
- **Critério:** criar zonas de todos os tipos e obter custo correto.
- **Depende de:** T0.1

### T1.2 — `Connection`
- **Objetivo:** aresta bidirecional com chave canônica.
- **Ações:**
  - `@dataclass Connection`: `a: str`, `b: str`, `max_link_capacity: int` (default 1).
  - `key` canônica = `tuple(sorted((a, b)))` (evita duplicatas `a-b`/`b-a`).
  - Adjacência bidirecional.
- **Critério:** `Connection("a","b").key == Connection("b","a").key`.
- **Depende de:** T1.1

### T1.3 — `Drone` e `Network`
- **Objetivo:** frota e grafo consolidado.
- **Ações:**
  - `@dataclass Drone`: `id: int`, posição/estado (zona atual, em trânsito,
    rota, índice do passo).
  - `Network`: dicionários `zones: dict[str, Zone]`,
    `connections: dict[tuple[str,str], Connection]`, `adjacency: dict[str, list[str]]`,
    além de `start: str`, `end: str`, `nb_drones: int`.
  - Método `neighbors(zone)`.
- **Critério:** montar `Network` manualmente e navegar pela adjacência.
- **Depende de:** T1.1, T1.2

---

## Fase 2 — Parser e Validação

### T2.1 — Leitura linha a linha
- **Objetivo:** transformar o arquivo em modelo, com erro localizado.
- **Arquivos:** `src/parser.py`.
- **Ações:**
  - Ler com `with open(path, encoding="utf-8")`.
  - Ignorar linhas em branco e comentários (`#`), inclusive inline.
  - Guardar `line_no` para mensagens `Error: line N: ...`.
  - Dispatch pelo prefixo antes de `:` (`nb_drones`, `start_hub`, `end_hub`,
    `hub`, `connection`).
  - Definir exceção própria `ParseError(line_no, message)`.
- **Critério:** parseia um mapa válido; mapa malformado gera `ParseError` com linha.
- **Depende de:** Fase 1

### T2.2 — Metadados `[...]`
- **Ações:**
  - Extrair bloco entre `[` e `]`; `split` por espaço em `key=value`.
  - Validar chaves aceitas por contexto:
    - zonas: `zone`, `color`, `max_drones`;
    - conexões: `max_link_capacity`.
  - Rejeitar chave desconhecida, duplicada ou valor inválido.
  - `zone=normal` default; `max_drones`/`max_link_capacity` inteiros > 0.
- **Critério:** metadados inválidos rejeitados com linha e motivo.
- **Depende de:** T2.1

### T2.3 — Validação global do mapa
- **Ações (ao final da leitura):**
  - `nb_drones` presente e > 0.
  - Exatamente um `start_hub` e um `end_hub`; `start != end`.
  - Nenhum dos dois é `blocked`.
  - Nomes/coordenadas únicos; nomes sem espaço e sem `-`.
  - Conexões ligam zonas declaradas; sem duplicata/auto-conexão.
  - Pelo menos uma conexão.
- **Critério:** cada regra tem teste; erros claros e `exit 1`.
- **Depende de:** T2.1, T2.2, T1.3

---

## Fase 3 — Grafo e Alcançabilidade

### T3.1 — Checagem de caminho (BFS)
- **Objetivo:** detectar end inalcançável antes de planejar.
- **Arquivos:** `src/graph.py`.
- **Ações:**
  - BFS a partir de `start` ignorando zonas `blocked`.
  - Se `end` não for alcançado: `Error: no path from '<start>' to '<end>'`, `exit 1`.
- **Critério:** mapa desconectado gera a mensagem exata e exit 1.
- **Depende de:** Fase 1, T2.3

> 🔧 **MARCO 1:** antes de avançar, valide parser + BFS com mapas triviais
> (linear e fork). Confirme a mensagem de erro de grafo desconectado.

---

## Fase 4 — Busca no Espaço-Tempo (Núcleo)

### T4.1 — Estado e vizinhos
- **Objetivo:** busca single-drone em `(zone, turn)`.
- **Arquivos:** `src/planner.py`.
- **Ações:**
  - Nó/estado: `(zone: str, turn: int)` (+ custo acumulado, predecessor).
  - Ações a partir de `(zone, turn)`:
    - **wait**: `(zone, turn + 1)` se a zona tiver vaga no novo turno.
    - **move**: para cada vizinho não-`blocked`: chega em
      `turn + cost(neighbor)` (1 ou 2); verifica capacidade da conexão no turno
      de partida e da zona no turno de chegada.
  - `restricted`: reserva conexão na partida e zona na chegada (turno seguinte).
- **Critério:** rota single-drone correta em mapa sem concorrência.
- **Depende de:** Fase 3

### T4.2 — Dijkstra/A* com heap e desempate priority
- **Ações:**
  - Fila de prioridade (`heapq`) ordenada por `(turn, non_priority_moves)`.
  - Primeira vez que `end` sai da heap = chegada mais cedo (custo = turno).
  - Desempate: menos entradas em zonas **não-priority** (implementa
    "priority preferida" **sem** dar custo menor à priority).
  - Reconstruir rota via dicionário `parent`.
  - `visited`/`best` por estado para evitar reprocessar pior.
- **Critério:** rota válida e de menor turno; priority escolhida em empate.
- **Depende de:** T4.1

---

## Fase 5 — Planejamento Multi-Drone (Reservation Table)

### T5.1 — Reservation table
- **Objetivo:** impedir conflitos entre drones.
- **Arquivos:** `src/planner.py` / `src/reservations.py`.
- **Ações:**
  - `zone_use[(zone, turn)] -> int`
  - `link_use[(connection_key, turn)] -> int`
  - Métodos `can_use_zone`, `can_use_link`, `reserve_route`.
  - Start/end **sem limite**.
- **Critério:** após reservar uma rota, as vagas ocupadas ficam indisponíveis.
- **Depende de:** Fase 4

### T5.2 — Planejamento sequencial priorizado
- **Ações:**
  - Para D1..DN (ordem numérica): buscar rota com a reservation table atual;
    reservar a rota inteira; seguir para o próximo.
  - Se um drone não achar rota dentro do horizonte, expandir horizonte ou
    reportar erro claro (não travar).
- **Critério:** todos os drones têm rota **sem violar** nenhuma capacidade.
- **Depende de:** T5.1

> 🔧 **MARCO 2:** rode o planejamento em `easy/01` e `easy/02`; verifique que a
> frota inteira é roteada e que o makespan bate com o esperado.

---

## Fase 6 — Simulação Turno a Turno

### T6.1 — Motor de turnos
- **Objetivo:** executar as rotas respeitando a ordem e as capacidades.
- **Arquivos:** `src/simulation.py`.
- **Ações:**
  - Ordem do turno (§4.3 do `ORIENTACAO.md`): decolagens → chegadas →
    movimentos (mais perto do goal primeiro) → commit.
  - Validar todas as capacidades **antes** de efetivar.
  - Tratar `restricted` (chegada no turno seguinte; token de trânsito).
  - Não permitir espera em conexão nem 2 movimentos por turno.
  - Drones entregues saem da ocupação ativa.
- **Critério:** simulação de um mapa respeita 100% das regras; sem colisões.
- **Depende de:** Fase 5

### T6.2 — Detecção de deadlock/loop
- **Ações:** se nenhum drone se mover por N turnos consecutivos e a frota não
  terminou, abortar com `SimulationError`/mensagem clara (exit 1).
- **Critério:** mapa problemático termina com erro, nunca em loop infinito.
- **Depende de:** T6.1

---

## Fase 7 — Saída e CLI

### T7.1 — Formatador de saída
- **Arquivos:** `src/output.py`.
- **Ações:**
  - Uma linha por turno.
  - `D<id>-<zone>` para chegadas; `D<id>-<a>-<b>` para trânsito em restricted
    (extremos em ordem canônica).
  - Omitir drones parados/entregues; turno idle = linha vazia.
- **Critério:** saída idêntica em formato ao exemplo do subject.
- **Depende de:** T6.1

### T7.2 — Entry point e tratamento de erros
- **Arquivos:** `fly_in.py`.
- **Ações:**
  - `def main(argv: list[str]) -> int:`; exigir caminho do mapa.
  - `try/except` para `FileNotFoundError`, `ParseError`, `SimulationError`,
    `KeyboardInterrupt`; mensagens em `stderr`; `exit 1`/`130`.
  - Sucesso → `return 0`.
  - `if __name__ == "__main__": sys.exit(main(sys.argv[1:]))`.
- **Critério:** `python3 fly_in.py maps/easy/01_linear_path.txt` imprime só os
  turnos e retorna 0; entradas inválidas retornam 1 sem traceback.
- **Depende de:** T7.1, Fase 2

> 🔧 **MARCO 3:** rode os 9 mapas easy/medium/hard e confira makespan e ausência
> de violações. Só então siga para qualidade/testes.

---

## Fase 8 — Testes

### T8.1 — Testes unitários (`pytest`)
- **Arquivos:** `tests/`.
- **Ações:** cobrir
  - parser válido/inválido (cada regra de T2.3);
  - BFS de alcançabilidade e mensagem de erro;
  - custo de cada `ZoneType`;
  - reservation table (conflito de zona e de conexão);
  - planejamento de D drones sem violação;
  - simulação com `restricted` (2 turnos + trânsito);
  - formatador de saída;
  - **determinismo**: mesma entrada → mesma saída;
  - deadlock → erro.
- **Critério:** `make test` verde; cobre edge cases.
- **Depende de:** Fases 2–7

### T8.2 — Regressão nos mapas
- **Ações:** script/teste que roda cada mapa e verifica terminação e regras
  (capacidades nunca excedidas) e, opcionalmente, o makespan conhecido.
- **Critério:** 100% dos 9 mapas mandatórios passam.
- **Depende de:** T8.1

---

## Fase 9 — Qualidade (Lint e Tipos)

### T9.1 — Type hints e docstrings
- **Ações:** anotar parâmetros/retornos; docstrings PEP 257 em módulos, classes
  e funções (Google ou NumPy style).
- **Critério:** `mypy . --disallow-untyped-defs --check-untyped-defs` sem erros.
- **Depende de:** código da Fase 7

### T9.2 — flake8 e mypy
- **Ações:** `make lint` (flags exatas) e, recomendado, `make lint-strict`.
- **Critério:** zero saída de erro.
- **Depende de:** T9.1

---

## Fase 10 — Documentação (README)

### T10.1 — `README.md`
- **Ações:** incluir
  - primeira linha itálica com login(s);
  - **Description**, **Instructions**, **Resources** (com uso de IA);
  - formato completo do mapa;
  - algoritmo escolhido + justificativa + complexidade;
  - representação visual e limitações;
  - gestão de equipe/projeto (papéis, planejamento, o que funcionou/melhorar,
    ferramentas);
  - respostas às 10 perguntas do subject.
- **Critério:** todos os campos presentes; revisão por pares.
- **Depende de:** Fase 7

---

## Fase 11 — Validação Final e Defesa

### T11.1 — Revisão de requisitos
- **Ações:** percorrer o checklist §13 do `ORIENTACAO.md`, item a item.
- **Critério:** todos marcados.

### T11.2 — Limpeza e commit
- **Ações:** `make clean`; confirmar `maps/`, `Makefile`, `README.md`,
  `.gitignore`; commit descritivo.
- **Critério:** repositório limpo e completo.

### T11.3 — Ensaio de defesa
- **Ações:** explicar parser, modelo, busca `(zone, turn)`, reservation table,
  ordem do turno, complexidade; simular uma **modificação ao vivo** (ex.: mudar
  custo de priority, adicionar validação, novo mapa).
- **Critério:** defender cada parte sem consultar; modificar ao vivo sem quebrar.

---

## Fase 12 — Bônus (OPCIONAL — só após Fase 11)

### T12.1 — Visual
- **Ações:** animação/step no terminal ou `pygame`/Qt lendo os turnos já
  calculados; cores ANSI por `color=` (sem cor quando redirecionado).
- **Critério:** visual não altera a simulação; funciona em um mapa hard.

### T12.2 — Challenger 43 turnos
- **Ações:** otimizar planejamento/busca para atingir o ótimo do
  `challenger/01_the_impossible_dream` (v2: **43**).
- **Critério:** 43 turnos comprovados na execução.

---

## Resumo de Dependências

```
Fase 0 (setup)
  └─► Fase 1 (modelos)
        └─► Fase 2 (parser) ─► Fase 3 (BFS/alcançabilidade)
              └─► Fase 4 (busca espaço-tempo)
                    └─► Fase 5 (reservation table + multi-drone)
                          └─► Fase 6 (simulação)
                                └─► Fase 7 (saída + CLI)
                                      ├─► Fase 8 (testes)
                                      ├─► Fase 9 (lint/tipos)
                                      └─► Fase 10 (README)
                                            └─► Fase 11 (validação/defesa)
                                                  └─► Fase 12 (bônus, opcional)
```

> **Regra de ouro:** **nunca** avance para bônus (Fase 12) sem que a Fase 11
> esteja validada em **todos** os mapas mandatórios. O núcleo (parser → busca →
> simulação → saída) é o coração do projeto.
