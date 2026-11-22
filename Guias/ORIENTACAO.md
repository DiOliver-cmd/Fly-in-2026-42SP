# Orientação do Projeto — Fly-In (42) — v2.0

> **O que é este arquivo:** guia-mestre de contexto para **retomar o projeto em
> qualquer sessão futura**. Resume o subject oficial **v2.0**, o escopo
> **mandatório**, as regras de simulação, o formato de entrada/saída, os
> entregáveis e as convenções do repositório. Leia **antes** de qualquer outro e
> antes de escrever código.
>
> **Idioma:** explicação em português; **termos técnicos e nomes de campos do
> subject ficam em inglês** para fidelidade ao enunciado.

---

## 0. Metadados

| Item | Valor |
|---|---|
| Projeto | **Fly-In** — roteamento de drones sobre grafo (currículo 42) |
| Versão do subject | **2.0** (texto oficial fornecido nesta sessão) |
| Linguagem | **Python 3.10+** |
| Branch de trabalho dos guias | **`Guias`** (não será mergeada na `main`) |
| Branch base | `main` (commit inicial com `maps.tar.gz`) |
| Guias | `Guias/ORIENTACAO.md` (este), `Guias/ESTUDO_MANDATORIO.md`, `Guias/TAREFAS_MANDATORIO.md` |
| Data de atualização | 2026-11-21 |

> ✅ **Fonte agora é o subject oficial v2.0.** A versão anterior destes guias havia
> sido reconstruída a partir de implementações de referência (o CDN do intra
> retornava HTTP 403). Esta versão foi **reconciliada com o texto oficial**.

---

## 1. Visão geral

Uma frota de drones deve sair de um `start_hub` e chegar a um `end_hub` através de
uma rede de **zonas** (nós) e **conexões** (arestas **bidirecionais**). Cada mapa
define o número de drones, as zonas (coordenadas + metadados) e as conexões. O
programa deve:

1. **Parsear e validar** o arquivo de mapa.
2. **Planejar rotas** para todos os drones respeitando capacidades e tipos de zona.
3. **Simular turno a turno** o movimento **simultâneo** da frota.
4. **Imprimir** a simulação no `stdout` no formato exigido.
5. **Fornecer representação visual** (terminal colorido e/ou interface gráfica).

Objetivo: entregar todos os drones no **menor número de turnos** (`makespan`).
**Corretude é avaliada separadamente do número de turnos.**

Pipeline: `parse → validate → check reachability → plan routes → simulate → print → visual`.

---

## 2. Restrições bloqueantes (reprovação direta)

O subject é explícito: falhar em qualquer item abaixo é **blocking condition**.

- [ ] **Python 3.10 ou superior.**
- [ ] **Proibido usar bibliotecas de lógica de grafo** (ex.: `networkx`,
      `graphlib`, etc.). Implemente o grafo você mesmo.
- [ ] **Projeto completamente orientado a objetos** — será demonstrado na defesa.
- [ ] **`flake8` limpo.**
- [ ] **`mypy` sem erros** (com as flags do subject).
- [ ] **Type hints** em parâmetros, retornos e variáveis (módulo `typing`).
- [ ] **Docstrings** PEP 257 (Google ou NumPy) em funções e classes.
- [ ] **Exceções tratadas** (try/except) — nenhum crash por exceção não tratada
      durante a avaliação.

> ❌ `networkx`/`graphlib`, lint/type errors ou design não-OO = **reprovação**.

---

## 3. Escopo MANDATÓRIO (o que precisa funcionar)

- [ ] Ler o arquivo de mapa (argumento de linha de comando).
- [ ] **Parser** completo + validação; erros com linha e causa.
- [ ] Detectar **grafo desconectado** (end inalcançável) e reportar claramente —
      **isso não é erro de parsing**, mas deve ser detectado (sem crash/loop).
- [ ] **Simulation engine** respeitando movimento, ocupação e capacidades.
- [ ] **Pathfinding** (uma ou várias estratégias) capaz de minimizar turnos.
- [ ] Movimento **simultâneo** com decisões a partir do estado **início do turno**.
- [ ] **Representação visual** obrigatória: **terminal colorido e/ou** interface
      gráfica (ver §8).
- [ ] **Saída** no formato exigido (ver §6), uma linha por turno.
- [ ] `Makefile` com `install/run/debug/clean/lint` (`lint-strict` opcional).
- [ ] `README.md` com todos os campos (ver §9).
- [ ] `.gitignore`; arquivos na **raiz do repositório**.

**Bônus (opcional, só se todo o mandatório passar):** resolver o mapa
**challenger** no ótimo de **43 turnos**. Ver §10.

---

## 4. Formato do mapa (entrada)

Arquivo texto. Linhas em branco ignoradas; `#` inicia comentário. Exemplo oficial:

```text
nb_drones: 5
start_hub: hub 0 0 [color=green]
end_hub: goal 10 10 [color=yellow]
hub: roof1 3 4 [zone=restricted color=red]
hub: roof2 6 2 [zone=normal color=blue]
hub: corridorA 4 3 [zone=priority color=green max_drones=2]
hub: tunnelB 7 4 [zone=normal color=red]
hub: obstacleX 5 5 [zone=blocked color=gray]
connection: hub-roof1
connection: hub-corridorA
connection: roof1-roof2
connection: roof2-goal
connection: corridorA-tunnelB [max_link_capacity=2]
connection: tunnelB-goal
```

### 4.1 Diretivas

```text
nb_drones: <positive_integer>
start_hub: <name> <x> <y> [<metadata>]
end_hub:   <name> <x> <y> [<metadata>]
hub:       <name> <x> <y> [<metadata>]
connection: <name1>-<name2> [<metadata>]
```

- **Primeira linha** = `nb_drones: <positive_integer>`.
- Exatamente **um** `start_hub` e **um** `end_hub`; qualquer número de `hub`.
- Conexões **bidirecionais**, declaradas **depois** que as duas zonas existem.
- Nomes de zona **únicos**, **sem `-` e sem espaço**. Coordenadas inteiras e únicas.

### 4.2 Metadados (bloco `[...]`, `key=value`, ordem livre)

**Zonas:**

| Chave | Valores | Padrão | Observação |
|---|---|---|---|
| `zone` | `normal`, `blocked`, `restricted`, `priority` | `normal` | tipo |
| `color` | qualquer **palavra única** (red, blue, gray…) | sem cor | sem lista fixa |
| `max_drones` | inteiro positivo | `1` | capacidade da zona; **ignorado em start/end** |

**Conexões:**

| Chave | Valores | Padrão | Observação |
|---|---|---|---|
| `max_link_capacity` | inteiro positivo | `1` | capacidade **simultânea**, compartilhada nas duas direções |

### 4.3 Validações (Parser Constraints, §VII.4)

- Primeira linha `nb_drones: <positive_integer>`; suportar **qualquer** número de drones.
- Exatamente um `start_hub` e um `end_hub`; nomes e coordenadas únicas.
- Nomes: quaisquer caracteres válidos **exceto `-` e espaço**.
- Conexões ligam **apenas zonas já definidas**; sem duplicata (`a-b` == `b-a`).
- Metadados sintaticamente válidos; `zone` ∈ {normal, blocked, restricted, priority}.
- Capacidades (`max_drones`, `max_link_capacity`) **inteiros positivos**.
- `max_drones` **ignorado** em `start_hub`/`end_hub` — **não é erro** se presente.
- Qualquer outro erro de parsing: parar com **mensagem clara indicando linha e causa**.
- Mapa sintaticamente válido mas sem caminho start→end **não é erro de parsing**:
  detectar e reportar claramente (sem crash/loop infinito).

---

## 5. Modelo de simulação (semântica dos turnos)

Parte **mais cobrada na defesa**. A ordem e a simultaneidade mudam o resultado.

### 5.1 Tipos de zona (custo de entrada)

| Tipo | Custo | Comportamento |
|---|---|---|
| `normal` | **1 turno** | padrão |
| `priority` | **1 turno** | deve ser **preferida** no pathfinding (desempate) |
| `restricted` | **2 turnos** | drone ocupa a **conexão** durante o trânsito e **deve** chegar no turno seguinte |
| `blocked` | — | **inacessível** (não entrar/passar; qualquer caminho por ele é inválido) |

### 5.2 Ocupação (Zone Occupancy Rules, §VII.2)

- Zona comum: no máximo **1** drone por turno (padrão).
- `max_drones=N`: até **N** drones simultâneos.
- **Exceções:** `start_hub` e `end_hub` **sem limite** de capacidade.
- Dois drones não entram na mesma zona no mesmo turno salvo se a capacidade permitir.
- A capacidade da conexão (`max_link_capacity`) limita quantos drones a atravessam
  **simultaneamente**.

### 5.3 Movimento e turnos (Movement and Turn Mechanics, §VII.3)

A cada turno, cada drone pode:

- **mover** para zona adjacente conectada (se a capacidade permitir);
- **mover para uma conexão** rumo a zona `restricted` (chegada em 2 turnos); o
  drone **DEVE** chegar no turno seguinte — **não pode esperar** na conexão;
- **ficar parado** (esperar, ou se o movimento estiver bloqueado).

Regras de avaliação:

- **Movimentos simultâneos:** cada movimento é decidido a partir do estado **no
  início do turno**; não há mudança de decisão no meio do turno.
- **Desocupar libera capacidade no MESMO turno:** quem sai libera a vaga para quem
  entra naquele turno (uma coluna single-file avança 1 passo por turno).
- A zona de destino deve ter vaga **após** as saídas do turno.
- `restricted`: o drone ocupa a conexão no trânsito e **deve** chegar após os
  turnos previstos; **não** espera na conexão por vaga no destino.
- A conexão `restricted` é **liberada no turno da chegada**: outro drone pode
  começar a cruzá-la **no mesmo turno**, respeitando as demais regras.

**Exemplo oficial (fila em conexão restrita, `max_link_capacity=1`):**

```text
D1-restrictedConn
D1-restrictedZone D2-restrictedConn
D2-restrictedZone
```

> D1 cruza no turno 1 e chega no turno 2, liberando a conexão a partir do turno 2;
> D2 começa a cruzar no turno 2 e chega no turno 3.

---

## 6. Formato de saída (stdout) — obrigatório (§VII.5)

- **Uma linha por turno**, listando todos os movimentos do turno separados por espaço.
- Formato de cada movimento:
  - **Chegada a zona:** `D<ID>-<zone>`
  - **Em trânsito rumo a `restricted`:** `D<ID>-<connection>` — a conexão é
    identificada pelos **dois extremos** (ex.: `D1-roof1-roof2`, em ordem canônica
    estável). O subject ilustra com um rótulo (`D1-restrictedConn`); como conexões
    não têm nome próprio, use `origem-destino`.
- `D<ID>` = identificador único (`D1`, `D2`, …).
- Drones que **não se movem** são **omitidos** naquele turno.
- Drones que chegam ao **end** são **entregues** e **não são mais rastreados**.
- A simulação **termina** quando todos chegam ao end.

Exemplo oficial:

```text
D1-roof1 D2-corridorA
D1-roof2 D2-tunnelB
D1-goal D2-goal
```

> Nomes de zona não contêm `-` justamente para o token `D1-a-b` identificar
> inequivocamente um trânsito em conexão.

---

## 7. Erros e exit codes

| Situação | Mensagem | Canal | Exit |
|---|---|---|---|
| Mapa inválido (parsing) | mensagem clara com **linha e causa** | `stderr` | `1` |
| Grafo desconectado / end inalcançável | `Error: no path from '<start>' to '<end>'` (ou equivalente claro) | `stderr` | `1` |
| Arquivo inexistente/ilegível | erro claro | `stderr` | `1` |
| Sucesso | — | — | `0` |
| `KeyboardInterrupt` (se tratar) | — | `stderr` | `130` |

- `stdout` contém **apenas** a saída de movimentos.
- Nunca emitir traceback cru em uso normal; use `try/except` + `with open(...)`.

---

## 8. Representação visual (MANDATÓRIA)

O subject exige feedback visual da simulação, por **uma ou ambas** as opções:

- **Terminal colorido** exibindo movimentos e estado das zonas; quando `color=` for
  especificado, a implementação **deve** oferecer feedback visual (cor) naquele
  canal. Sem lista fixa de cores; qualquer palavra única é aceita.
- **Interface gráfica** mostrando a rede e as posições dos drones.
- Ambas = experiência reforçada.

Boas práticas: a camada visual deve **ler os turnos já calculados**, sem influenciar
a simulação; quando a saída for redirecionada/pipe, manter o formato textual limpo
(sem códigos ANSI) quando apropriado.

> No README, é obrigatório documentar os recursos visuais e **como eles melhoram a
> experiência** do usuário.

---

## 9. Entregáveis e qualidade

### 9.1 Estrutura (arquivos na **raiz** do repositório)

O subject pede **todos os arquivos na raiz do repositório**. Layout seguro:

```text
fly_in.py            # entry point
models.py / zone.py / connection.py / drone.py / network.py
parser.py
pathfinder.py        # ou planner.py
simulation.py
output.py / renderer.py
maps/                # mapas fornecidos (easy/medium/hard/challenger)
tests/
Makefile
README.md
.gitignore
```

> Módulos podem ficar soltos na raiz (recomendado pelo subject) ou num pacote na
> raiz; **não** enterrar o ponto de entrada em subpastas profundas.

### 9.2 `Makefile` (§III.2)

| Regra | Ação |
|---|---|
| `install` | instalar dependências (pip/uv/pipx) |
| `run` | executar o script principal |
| `debug` | rodar sob `pdb` |
| `clean` | remover `__pycache__`, `.mypy_cache`, etc. |
| `lint` | **`flake8 .`** + **`mypy . --warn-return-any --warn-unused-ignores --ignore-missing-imports --disallow-untyped-defs --check-untyped-defs`** |
| `lint-strict` (opcional) | `flake8 .` + `mypy . --strict` |

### 9.3 Qualidade

- Python 3.10+, `flake8`, `mypy`, **type hints**, **docstrings** PEP 257.
- Tratamento de exceções + **context managers**; sem leaks.
- **Design OO** (classes, responsabilidades claras) — será arguido na defesa.
- **Sem bibliotecas de grafo.**
- Testes com `pytest`/`unittest` (não avaliados, mas recomendados).
- `.gitignore`; virtualenv recomendado.

### 9.4 `README.md` (em inglês) (§VIII)

- **Primeira linha itálica exata:**
  `*This project has been created as part of the 42 curriculum by <login1>[, <login2>[, ...]].*`
- **Description** (objetivo + visão geral).
- **Instructions** (compilação/instalação/execução).
- **Resources** (referências clássicas) **+ descrição de como a IA foi usada**
  (para quais tarefas e partes do projeto).
- **Descrição detalhada das escolhas de algoritmo e estratégia de implementação.**
- **Documentação da representação visual** e como ela melhora a experiência.
- **Exemplo de entrada e saída esperada.**
- Pode haver seções adicionais (exemplos de uso, features, escolhas técnicas).

---

## 10. Pontuação, benchmarks e bônus

### 10.1 Correção vs. turnos

- **Correção é avaliada de forma independente** do número de turnos (regras,
  custos, capacidades, sem conflitos).
- O **turn count** é medido e reportado separadamente como medida de otimização.
- **Velocidade nunca reprova** e não afeta a nota.

### 10.2 Alvos (mapas do subject — a única referência)

Não existe faixa easy/medium/hard separada; a tabela é a única referência.

| Mapa | Drones | Ótimo |
|---|---:|---:|
| easy/01 linear path | 2 | **4** |
| easy/02 simple fork | 4 | **4** |
| easy/03 basic capacity | 4 | **4** |
| medium/01 dead end trap | 5 | **8** |
| medium/02 circular loop | 6 | **10** |
| medium/03 priority puzzle | 5 | **6** |
| hard/01 maze nightmare | 8 | **13** |
| hard/02 capacity hell | 12 | **16** |
| hard/03 ultimate challenge | 15 | **26** |
| challenger/01 the impossible dream | 25 | **43** (bônus) |

- Pontuação: (1) todo mapa roda corretamente (independente de turnos);
  (2) pontos se ficar **dentro de 25% do ótimo** em todo mapa;
  (3) mais pontos se atingir o **ótimo exato** em todo mapa.
- Challenger: throughput limitado por gates/exit de capacidade 1; ótimo
  `19 + (25-1) = 43`.

### 10.3 Bônus (Chapter IX)

- **Único bônus:** resolver o **Challenger Map** no ótimo de **43 turnos**.
- Só é revisado se **todo o mandatório** estiver cumprido.

---

## 11. Decisões de arquitetura sugeridas (OO, sem libs de grafo)

- **Modelos OO:** `Zone` (nome, x, y, tipo, cor, capacidade), `Connection` (a, b,
  capacidade, chave canônica), `Drone` (id, estado/posição, rota), `Network`
  (zonas + adjacência + índices). Cada classe encapsula suas regras.
- **Parser** linha a linha, acumulando `line_no` para erros.
- **Pathfinding:** busca no **espaço-tempo** com estado `(zone, turn)`.
  - Dijkstra/A* com `heapq`; custo = turno de chegada; desempate por menos
    movimentos para zonas **não-priority**.
  - **Reservation table** `zone_use[(zone, turn)]` e `link_use[(conn, turn)]`.
- **Planejamento sequencial priorizado** D1..DN reservando cada rota; os mapas do
  subject são atingíveis, mas não é ótimo global.
- **Simulação** consome o cronograma e valida capacidades; imprime os turnos.
- **Renderer** separado (terminal colorido e/ou GUI), lendo os turnos calculados.
- **Sem `networkx`/`graphlib`**; estrutura de grafo própria.

---

## 12. Protocolo para as próximas sessões

1. **Ler nesta ordem:** `ORIENTACAO.md` → `ESTUDO_MANDATORIO.md` → `TAREFAS_MANDATORIO.md`.
2. Confirmar branch `Guias` (`git branch --show-current`). A `Guias` **não** é
   mergeada na `main`; código do projeto pode ir em outra branch/PR.
3. Escolher a próxima tarefa **não concluída** com dependências satisfeitas.
4. Implementar → `make lint` → `make test` → rodar **todos** os mapas.
5. Atualizar checklist (§14) e o `TAREFAS_MANDATORIO.md`.

**Definição de pronto:** código OO + tipado + docstring, lint/mypy limpos,
teste/validação passando, saída conferida em ao menos um mapa, sem biblioteca de grafo.

---

## 13. Riscos e armadilhas

- ❌ Usar `networkx`/`graphlib` → **reprovação**.
- ❌ Design não-OO (funções soltas, sem classes) → **reprovação**.
- ❌ Erros de `flake8`/`mypy` → **reprovação**.
- ❌ Esquecer a **representação visual** (é **obrigatória**, não bônus).
- ❌ Confundir capacidade de **zona** com a de **conexão** (compartilhada 2 sentidos).
- ❌ Não liberar vaga **no mesmo turno** da saída.
- ❌ Deixar drone **esperando na conexão** (proibido) ou mover 2× no turno.
- ❌ Tratar `restricted` como custo 1; esquecer do token de **trânsito**.
- ❌ Planejar só espacialmente (ignorar o turno) → conflitos/fila inválida.
- ❌ Loop infinito em grafo desconectado/deadlock → detectar e abortar.
- ❌ Nome de zona com `-` quebrando o parsing; logs contaminando o `stdout`.
- ❌ Deixar type hints/lint **para o fim** (custo alto).
- ❌ Ignorar que **mapas de avaliação podem ser diferentes** e que pode haver
  **modificação ao vivo** (esteja pronto para pequenas alterações).

---

## 14. Checklist mandatório

- [ ] Python 3.10+; **OO**; **sem bibliotecas de grafo**.
- [ ] Parser completo + validação (linha/causa); `max_drones` ignorado em start/end.
- [ ] Detecção de grafo desconectado (mensagem clara, exit 1, sem loop).
- [ ] Modelos OO: Zone/Connection/Drone/Network + tipos de zona.
- [ ] Busca espaço-tempo `(zone, turn)` com wait e custos de zona.
- [ ] Reservation table de zonas e conexões.
- [ ] Planejamento de todos os drones.
- [ ] Simulação simultânea turno a turno respeitando todas as capacidades.
- [ ] Saída `D<ID>-<zone>` / `D<ID>-<conexão>`, 1 linha por turno; omitir parados.
- [ ] **Representação visual** (terminal colorido e/ou GUI), documentada.
- [ ] `make run` funciona; 9 mapas executam corretamente (turnos reportados).
- [ ] `Makefile` com `install/run/debug/clean/lint` (+ `lint-strict`).
- [ ] `README.md` (inglês) com primeira linha itálica e todas as seções.
- [ ] `flake8` e `mypy` (flags do subject) limpos; type hints + docstrings.
- [ ] `.gitignore`; arquivos na raiz; repositório limpo.
- [ ] (Bônus) Challenger em **43 turnos**.

---

## 15. Relação com os outros guias

| Arquivo | Papel |
|---|---|
| `Guias/ORIENTACAO.md` | **Este** — contexto oficial, regras e protocolo de retomada |
| `Guias/ESTUDO_MANDATORIO.md` | Base teórica (grafos, busca, MAPF, complexidade) para entender/defender |
| `Guias/TAREFAS_MANDATORIO.md` | Plano de execução faseado, com critérios e dependências |
