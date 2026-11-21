# Orientação do Projeto — Fly-In (42)

> **O que é este arquivo:** guia-mestre de contexto para **retomar o projeto em
> qualquer sessão futura**. Ele resume o subject, o escopo **mandatório**, as regras
> de simulação, o formato de entrada/saída, os entregáveis e as convenções do
> repositório. Leia este arquivo **antes** de qualquer outro e antes de escrever
> código.
>
> **Idioma:** explicação em português; **termos técnicos e nomes de campos do
> subject ficam em inglês** para manter fidelidade ao enunciado.

---

## 0. Metadados desta sessão

| Item | Valor |
|---|---|
| Projeto | **Fly-In** — simulação de drones sobre grafo (currículo 42) |
| Linguagem | **Python 3.10+** |
| Branch de trabalho | **`Guias`** (esta branch **não será mergeada** na `main`) |
| Branch base | `main` (commit inicial com `maps.tar.gz`) |
| Guias gerados | `Guias/ORIENTACAO.md` (este), `Guias/ESTUDO_MANDATORIO.md`, `Guias/TAREFAS_MANDATORIO.md` |
| Data de geração | 2026-11-21 |

> ⚠️ **Ressalva sobre a fonte do subject.** O link oficial
> `https://cdn.intra.42.fr/pdf/pdf/229653/en.subject.pdf` retornou **HTTP 403**
> (o CDN exige autenticação no intra). Os requisitos abaixo foram
> **reconstruídos a partir de múltiplas implementações de referência** do mesmo
> subject (leituras convergem) e do pacote `maps.tar.gz` do repositório.
> **Antes da defesa**, confirme cada item contra o PDF oficial aberto com a sua
> conta do intra e ajuste este arquivo se houver divergência de versão.

---

## 1. Visão geral do projeto

Um conjunto de **drones** deve sair de um `start_hub` e chegar a um `end_hub`
através de uma rede de **zonas** (nós) e **conexões** (arestas bidirecionais).
Cada mapa define o número de drones, as zonas (com coordenadas e metadados) e as
conexões. O programa deve:

1. **Parsear e validar** o arquivo de mapa.
2. **Planejar uma rota** para cada drone sem violar nenhuma capacidade.
3. **Simular turno a turno** o movimento simultâneo da frota.
4. **Imprimir a simulação** no `stdout` no formato exigido.

O objetivo é entregar todos os drones no **menor número de turnos possível**
(`makespan`), respeitando zonas `priority`, `restricted` e `blocked` e as
capacidades de zonas e conexões.

**Pipeline conceitual:** `parse → validate → check reachability → plan routes →
simulate → print`.

---

## 2. Escopo MANDATÓRIO (o que precisa funcionar)

O mandatório é um simulador **funcional e determinístico** por linha de comando:

- [ ] Ler um arquivo de mapa passado como argumento de linha de comando.
- [ ] Validar o mapa e **rejeitar entradas inválidas** com erro claro e `exit 1`.
- [ ] Detectar quando o `end_hub` é **inalcançável** e sair com erro claro.
- [ ] Planejar rotas para **todos** os drones respeitando capacidades e tipos de zona.
- [ ] Simular o movimento **simultâneo** turno a turno, sem colisões nem
      estouro de capacidade.
- [ ] Imprimir **uma linha por turno** no formato exigido (ver §5).
- [ ] Entregar todos os drones (a saída termina quando a frota chega ao `end_hub`).
- [ ] `Makefile`, `README.md`, `.gitignore` e código com **type hints**, docstrings,
      **flake8** e **mypy** limpos (com as flags exigidas pelo subject).

**Fora do mandatório (bônus / opcional):** representação visual (animação no
terminal, `pygame`, Qt), colorir a saída, otimizações avançadas (CBS/ICBS), bater
o recorde do mapa *challenger* (43 turnos na versão 2). Ver §8.

> **Regra de ouro:** o mandatório precisa ser **correto e sempre terminar**.
> Nunca deixar o programa em loop infinito, deadlock sem erro, ou traceback não
> tratado durante a defesa.

---

## 3. Formato do mapa (entrada)

Arquivo texto UTF-8. Linhas em branco são ignoradas. `#` inicia comentário
(inclusive comentário no fim da linha).

### 3.1 Diretivas

```text
nb_drones: <positive_integer>
start_hub: <name> <x> <y> [<metadata>]
end_hub:   <name> <x> <y> [<metadata>]
hub:       <name> <x> <y> [<metadata>]
connection: <name_a>-<name_b> [<metadata>]
```

- `nb_drones:` é a **primeira linha significativa** do arquivo.
- Exatamente **um** `start_hub` e **um** `end_hub`; qualquer número de `hub`.
- Conexões são **bidirecionais** e declaradas **depois** que as duas zonas existem.
- Nomes de zona: **únicos**, **sem espaços e sem `-`** (o hífen é o separador de
  conexões). Coordenadas `x y` inteiras e **únicas**.

### 3.2 Metadados (bloco `[...]` opcional, `key=value` separados por espaço)

**Zonas:**

| Chave | Valores | Padrão | Observação |
|---|---|---|---|
| `zone` | `normal`, `priority`, `restricted`, `blocked` | `normal` | tipo de comportamento |
| `color` | uma palavra (ex.: `green`, `red`, `blue`) | sem cor | usado no bônus visual |
| `max_drones` | inteiro positivo | `1` | capacidade da zona; **ignorado** em start/end |

**Conexões:**

| Chave | Valores | Padrão | Observação |
|---|---|---|---|
| `max_link_capacity` | inteiro positivo | `1` | capacidade **compartilhada bidirecionalmente** |

### 3.3 Validações obrigatórias (rejeitar com erro)

- `nb_drones` ausente ou não positivo (ex.: `0`, negativo, não inteiro).
- `start_hub`/`end_hub` ausente, duplicado, ou iguais entre si.
- **`start_hub` ou `end_hub` do tipo `blocked`**.
- Zona duplicada (nome ou coordenadas); conexão duplicada (`a-b == b-a`) ou
  auto-conexão (`a-a`).
- Conexão referenciando zona **não declarada**.
- Tipo de zona inválido; chave de metadado desconhecida ou repetida.
- Capacidades (`max_drones`, `max_link_capacity`) ou count inválidos (`<= 0`).
- Nome de zona contendo `-` ou espaço.
- Mapa sem nenhuma conexão / grafo desconectado (end inalcançável).

---

## 4. Modelo de simulação (semântica dos turnos)

Esta é a parte **mais cobrada na defesa**. A ordem das operações dentro de um
turno muda o resultado; siga a semântica abaixo.

### 4.1 Tipos de zona e custo de entrada

| Tipo | Custo de entrada | Comportamento |
|---|---|---|
| `normal` | **1 turno** | movimento padrão |
| `priority` | **1 turno** | em empate, prefira rotas que passam por priority |
| `restricted` | **2 turnos** | o drone fica **em trânsito na conexão** por 1 turno intermediário e chega no turno seguinte |
| `blocked` | — | **não pode ser entrado** (remova da adjacência) |

### 4.2 Regras de capacidade e ocupação

- Todos os drones começam no **`start_hub`**.
- **`start_hub` e `end_hub` têm capacidade ilimitada** (`max_drones` é ignorado).
- Zonas comuns: no máximo **`max_drones`** drones ao mesmo tempo.
- Conexões: no máximo **`max_link_capacity`** drones por turno, **somando as duas
  direções**.
- **Sair libera a vaga no mesmo turno**: um drone pode entrar numa zona que está
  sendo desocupada naquele turno.
- Entrar em `restricted` reserva a vaga no **turno de partida** e a chegada ocorre
  no turno seguinte; **não é permitido esperar em cima de uma conexão**.
- Drone pode **esperar** (wait) na zona em que está, se houver vaga.
- Um drone **não pode se mover duas vezes no mesmo turno**.
- Drones entregues **deixam de ocupar** o `end_hub` para fins de contagem ativa.

### 4.3 Ordem recomendada dentro de um turno

1. Determinar **quem pode decolar** (antes das chegadas), para que um drone que
   chega neste turno não parta no mesmo turno.
2. Processar **chegadas** (drones em trânsito em `restricted`).
3. Processar **movimentos** dos drones parados, tipicamente ordenando por
   proximidade do goal (quem está mais perto anda primeiro), liberando vagas no
   mesmo turno.
4. Validar todas as capacidades antes de **efetivar** (commit) o turno.

> Detectar **deadlock**: se nenhum drone se mover por N turnos consecutivos e a
> frota não terminou, pare com erro claro em vez de girar para sempre.

---

## 5. Formato de saída (stdout) — obrigatório

- **Uma linha por turno**.
- Cada movimento é um token:
  - **Chegada a uma zona:** `D<id>-<zone>`
  - **Em trânsito para zona `restricted`:** `D<id>-<a>-<b>` (conexão com
    extremos em ordem canônica/estável)
- Drones que **esperam** ou que **já foram entregues** são **omitidos**.
- Um turno sem nenhum movimento é uma **linha vazia**.
- A simulação termina quando **todos** os drones chegam ao `end_hub`.

Exemplo (`medium/03_priority_puzzle.txt`, 5 drones, ótimo = 6 turnos):

```text
D1-fast_junction D3-start-slow_path1
D1-fast_path D2-fast_junction D3-slow_path1 D5-start-slow_path1
D1-merge_point D2-fast_path D3-slow_path2 D4-fast_junction D5-slow_path1
D1-goal D2-merge_point D3-merge_point D4-fast_path D5-slow_path2
D2-goal D3-goal D4-merge_point D5-merge_point
D4-goal D5-goal
```

> **Atenção:** nomes de zona **não contêm `-`** exatamente para que a presença de
> dois hífens no token (`D1-a-b`) identifique inequivocamente um trânsito em
> conexão. Não quebre essa regra.

---

## 6. Erros e exit codes

| Situação | Mensagem (stderr) | Exit |
|---|---|---|
| Mapa inválido | `Error: line N: <motivo>` | `1` |
| End inalcançável | `Error: no path from '<start>' to '<end>'` | `1` |
| Arquivo inexistente/ilegível | erro claro de arquivo | `1` |
| Sucesso | — | `0` |

- Mensagens de erro vão para **`stderr`**, não para `stdout`.
- O `stdout` deve conter **apenas** a saída de movimentos (quando `--display moves`).
- Nunca emitir traceback cru em uso normal: capture e traduza exceções esperadas.

---

## 7. Entregáveis e requisitos de qualidade

### 7.1 Estrutura recomendada do repositório

```text
fly-in/
├── fly_in.py              # entry point (ou pacote src/ com __main__.py)
├── src/ (ou pacote)       # parser, modelos, pathfinding, simulação, renderer
├── maps/                  # mapas do subject (easy/medium/hard/challenger)
├── tests/                 # pytest (não avaliado, mas essencial)
├── Makefile
├── README.md
├── .gitignore
└── LICENSE.md             # (se exigido pela versão do subject; verificar)
```

### 7.2 `Makefile` (regras exigidas)

| Regra | Ação |
|---|---|
| `install` | instalar dependências (pytest/flake8/mypy; libs do bônus se houver) |
| `run` | `python3 fly_in.py <map>` (mapa padrão ou via `MAP=`) |
| `debug` | rodar sob `pdb` |
| `lint` | `flake8 .` + `mypy .` com as flags exigidas |
| `lint-strict` | `flake8 .` + `mypy . --strict` |
| `test` | `pytest` |
| `clean` | remover caches/artefatos |

Flags de mypy exigidas pelo subject (confirmar no PDF):

```makefile
mypy . --warn-return-any --warn-unused-ignores --ignore-missing-imports \
       --disallow-untyped-defs --check-untyped-defs
```

### 7.3 `README.md`

- **Primeira linha** deve ser itálica e conter os logins:
  `*This project has been created as part of the 42 curriculum by <login>[, <login2>].*`
- Seções obrigatórias: **Description**, **Instructions**, **Resources**.
- Em **Resources**, descrever **como a IA foi usada** (exigência padrão do currículo).
- Explicar: formato do mapa, algoritmo escolhido e **por quê**, complexidade,
  representação visual, gestão de equipe/projeto (papéis, planejamento, o que
  funcionou/melhorar, ferramentas).
- Responder às **10 perguntas** do subject (eficiência, escala, complexidade,
  cache/recálculo, memória, visual, benchmarks, comparação com metas, otimizações,
  recorde do challenger).

### 7.4 Qualidade de código

- **Python 3.10+**, **type hints** em tudo, **docstrings** (PEP 257).
- `flake8` limpo; `mypy` limpo com as flags do subject.
- Tratamento de exceções e **context managers** (`with`) para arquivos.
- Determinismo: mesma entrada → mesma saída (útil para testes e defesa).

---

## 8. Bônus (não é mandatório)

- **Representação visual:** animação/step no terminal (`--visual`/`--display`),
  `pygame`, ou app Qt. Deve **ler os turnos já calculados** (não influenciar a
  simulação).
- **Cores ANSI** por `color=` (quando redirecionado, sair sem cor).
- **Challenger map** `01_the_impossible_dream` (25 drones): a versão 2 pede o
  **ótimo de 43 turnos** para o bônus. (O `maps/README.md` do pacote cita 45 como
  benchmark; `19 + 24 = 43` é o lower bound citado nas referências.)
- Otimizações avançadas: **CBS/ICBS**, **PBS**, **LNS**, lower bounds por fluxo.

> Só investir em bônus **depois** que o mandatório estiver 100% validado.

---

## 9. Mapas do repositório e metas (conhecidas)

O arquivo `maps.tar.gz` contém `maps/{easy,medium,hard,challenger}/`. Metas de
**makespan** relatadas por implementações de referência (confirmar rodando):

| Mapa | Drones | Ótimo conhecido |
|---|---:|---:|
| `easy/01_linear_path` | 2 | 4 |
| `easy/02_simple_fork` | 4 | 4 |
| `easy/03_basic_capacity` | 4 | 4 |
| `medium/01_dead_end_trap` | 5 | 8 |
| `medium/02_circular_loop` | 6 | 10 |
| `medium/03_priority_puzzle` | 5 | 6 |
| `hard/01_maze_nightmare` | 8 | 13 |
| `hard/02_capacity_hell` | 12 | 16 |
| `hard/03_ultimate_challenge` | 15 | 26 |
| `challenger/01_the_impossible_dream` | 25 | 43 (bônus v2) |

> Descompacte com `tar -xzf maps.tar.gz` e **rode todos os mapas** antes de
> declarar concluído. Não confie em números não reproduzidos.

---

## 10. Decisões de arquitetura sugeridas

- **Modelos de domínio:** `Zone` (nome, x, y, tipo, cor, capacidade), `Connection`
  (a, b, capacidade, chave canônica), `Drone` (id, posição/estado, rota), `Network`
  (zonas + adjacência + índices).
- **Parser** linha a linha, acumulando o número da linha para erros.
- **Pathfinding:** busca no **espaço-tempo** com estado `(zone, turn)`.
  - Dijkstra/A* com heap (`heapq`); custo = turno de chegada; desempate por
    menos movimentos para zonas **não-priority** (implementa "priority preferida").
  - **Reservation table** `zone_use[(zone, turn)]` e `link_use[(conn, turn)]`.
- **Planejamento sequencial priorizado:** planeje D1..DN, reservando cada rota;
  cada drone seguinte vê só as vagas restantes. Simples, determinístico e atinge
  os ótimos dos mapas do subject (mas não é ótimo global).
- **Simulação:** consome o cronograma e imprime os turnos; validar capacidades.
- **Sem dependência de biblioteca de grafos** (a não ser que o subject permita).

---

## 11. Protocolo para as próximas sessões

Ao iniciar uma nova sessão:

1. **Ler nesta ordem:** `Guias/ORIENTACAO.md` → `Guias/ESTUDO_MANDATORIO.md` →
   `Guias/TAREFAS_MANDATORIO.md`.
2. Confirmar que está na branch **`Guias`** (`git branch --show-current`).
   Trabalho de código do projeto deve ir para outra branch/PR; **a `Guias` não é
   mergeada na `main`**.
3. Escolher a próxima tarefa **não concluída** com dependências satisfeitas
   (ver `TAREFAS_MANDATORIO.md`).
4. Implementar, rodar **`make lint`**, **`make test`** e **todos os mapas**.
5. Atualizar o checklist de progresso no fim deste arquivo (§13) ou no
   `TAREFAS_MANDATORIO.md`.

**Definição de pronto (por tarefa):** código tipado + docstring, lint limpo,
teste/validação correspondente passando, e saída conferida em pelo menos um mapa.

---

## 12. Riscos e armadilhas comuns

- ❌ Confundir **capacidade de zona** com **capacidade de conexão**.
- ❌ Não liberar a vaga **no mesmo turno** da saída (gera subutilização/erros).
- ❌ Deixar drone **esperando na conexão** (proibido) ou mover 2× no turno.
- ❌ Tratar `restricted` como custo 1; esquecer do token de **trânsito**.
- ❌ Planejar só espacialmente (ignorar o turno) → colisões/fila inválida.
- ❌ Loop infinito em deadlock/grafo circular → detectar e abortar.
- ❌ Nome de zona com `-` quebrando o parsing da saída.
- ❌ Escrever no `stdout` logs que contaminem o formato de movimentos.
- ❌ Não validar `start/end` `blocked` ou grafo desconectado.
- ❌ Deixar para adicionar type hints/lint **no fim** (custo alto).

---

## 13. Checklist mandatório (marcar ao concluir)

- [ ] Parser completo + validação linha a linha com `Error: line N:`.
- [ ] Detecção de end inalcançável com mensagem e `exit 1`.
- [ ] Modelo de grafo (zonas + conexões bidirecionais + adjacência).
- [ ] Busca espaço-tempo `(zone, turn)` com wait e custos de zona.
- [ ] Reservation table de zonas e conexões.
- [ ] Planejamento sequencial de todos os drones.
- [ ] Simulação turno a turno respeitando todas as capacidades.
- [ ] Saída no formato `D<id>-<zone>` / `D<id>-<a>-<b>`, 1 linha por turno.
- [ ] `make run` funciona com um mapa do subject.
- [ ] Todos os 9 mapas easy/medium/hard entregues sem violar regras.
- [ ] `Makefile` com `install/run/debug/lint/lint-strict/test/clean`.
- [ ] `README.md` com primeira linha itálica e seções exigidas.
- [ ] `flake8` e `mypy` (flags do subject) limpos.
- [ ] `.gitignore` e repositório limpo.
- [ ] (Bônus) visual e/ou challenger 43 turnos.

---

## 14. Relação com os outros guias

| Arquivo | Papel |
|---|---|
| `Guias/ORIENTACAO.md` | **Este** — contexto, regras e protocolo de retomada |
| `Guias/ESTUDO_MANDATORIO.md` | Base teórica (grafos, busca, MAPF, complexidade) para **entender e defender** |
| `Guias/TAREFAS_MANDATORIO.md` | Plano de execução faseado, com critérios de conclusão e dependências |
