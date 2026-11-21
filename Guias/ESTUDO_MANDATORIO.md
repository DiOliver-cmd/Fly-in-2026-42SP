# Estudo Mandatório — Fly-In (42)

> Base teórica para **entender, implementar e defender** o projeto **Fly-In**.
> Explicação em português; termos técnicos e nomes de campos do subject em inglês.
>
> **Foco:** apenas a **parte mandatória**. Bônus (visual, challenger) aparece só
> quando ajuda a explicar o modelo. **Nenhuma fonte da Wikipedia foi utilizada** —
> todas as referências são acadêmicas, documentação oficial ou artigos técnicos.
>
> **Ressalva:** o PDF oficial do subject no intra retornou HTTP 403. Os requisitos
> foram reconstruídos a partir de `Guias/ORIENTACAO.md`, `Guias/TAREFAS_MANDATORIO.md`,
> do pacote `maps.tar.gz` e de implementações de referência. **Antes da defesa**,
> confirme cada item contra o PDF oficial aberto com sua conta do intra.

---

## 1. Grafos: conceitos e representação

Um grafo é um par `G = (V, E)`: `V` é o conjunto de vértices e `E` o conjunto de
arestas. Em grafos **não direcionados**, uma aresta `{u, v}` pode ser percorrida
nos dois sentidos. Em grafos **direcionados**, a aresta `(u, v)` só permite
`u → v`. Um grafo **ponderado** associa um peso/custo a cada aresta.

No Fly-In:

- **Zonas** são vértices.
- **Conexões** são arestas **bidirecionais**.
- `max_drones` é uma **capacidade de vértice**.
- `max_link_capacity` é uma **capacidade de aresta**, compartilhada nas duas direções.
- `blocked` remove o vértice da adjacência.
- `restricted` não remove o vértice: aumenta o custo de entrada para 2 turnos.
- `priority` não reduz o custo: serve apenas como **critério de desempate**.

A representação mais adequada é **lista de adjacência**:

```text
zones:       dict[str, Zone]
connections: dict[tuple[str, str], Connection]
adjacency:   dict[str, list[str]]
```

A chave canônica de uma conexão deve ser `tuple(sorted((a, b)))`, para que `a-b`
e `b-a` sejam a **mesma** aresta. Isso simplifica a reservation table e a
validação de duplicatas.

Complexidade de memória: `O(V + E)` com lista de adjacência. Matriz de adjacência
seria `O(V²)`, desnecessária para os mapas do projeto.

**Fontes:** Diestel, *Graph Theory* (`https://diestel-graph-theory.com/`);
Dasgupta, Papadimitriou e Vazirani, cap. 4
(`https://people.eecs.berkeley.edu/~vazirani/algorithms/chap4.pdf`).

---

## 2. BFS e DFS

### 2.1 BFS — Breadth-First Search

A BFS explora o grafo em **camadas**: primeiro o vértice inicial, depois todos os
vizinhos a distância 1, depois os de distância 2, e assim por diante. Usa uma
**fila** (`queue`). Em grafos **não ponderados**, a primeira vez que um vértice é
descoberto fornece a **menor distância em número de arestas**.

- Tempo: `O(V + E)`.
- Espaço: `O(V)`.
- Uso típico: alcançabilidade, distância em arestas, componentes conexos.

No Fly-In, BFS é útil para:

1. Detectar se o `end_hub` é alcançável ignorando `blocked`.
2. Calcular uma **lower bound** simples em número de arestas.
3. Comparar com o custo real: no challenger, o caminho tem 15 arestas, mas custa
   19 turnos por causa de 4 entradas em zonas `restricted`.

BFS **não basta** para planejar o movimento real, porque:

- `restricted` custa 2, então o grafo **não é unitário**.
- Capacidades e reservas dependem do **turno**.
- O objetivo é minimizar **turnos**, não arestas.

### 2.2 DFS — Depth-First Search

A DFS explora o mais fundo possível antes de retroceder. Pode ser implementada com
recursão ou pilha explícita.

- Tempo: `O(V + E)`.
- Espaço: `O(V)` no pior caso.
- Uso típico: detecção de ciclos, topological sort, componentes, backtracking.

No Fly-In, DFS **não** é adequada para menor caminho. Pode aparecer em validação de
ciclos ou algoritmos de backtracking, mas o planejamento principal deve usar
Dijkstra/A* no espaço-tempo.

**Fontes:** Dasgupta cap. 4; MIT OCW 6.006
(`https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-spring-2020/pages/lecture-notes/`);
CP-Algorithms BFS (`https://cp-algorithms.com/graph/breadth-first-search.html`).

---

## 3. Dijkstra

O algoritmo de Dijkstra resolve **single-source shortest paths** em grafos com
pesos **não negativos**. Mantém uma fila de prioridade com os vértices ainda não
finalizados, sempre extraindo o de menor distância provisória e relaxando suas
arestas.

Pseudocódigo conceitual:

```text
dist[s] = 0
para todo v != s: dist[v] = infinito
fila = {(0, s)}

enquanto fila não vazia:
    (d, u) = extrai_min(fila)
    se d > dist[u]: continua
    para cada (v, w) em adjacência(u):
        se dist[v] > dist[u] + w:
            dist[v] = dist[u] + w
            pai[v] = u
            insere (dist[v], v) na fila
```

- Com **binary heap**: `O((V + E) log V)`.
- Com array simples: `O(V²)`.
- Dijkstra **não funciona** com arestas negativas.

No Fly-In:

- Dijkstra no **grafo estático**, com custo 1 para `normal`/`priority` e 2 para
  `restricted`, calcula uma distância **otimista** ignorando outros drones. Isso
  serve como **lower bound** e como **heurística admissível** para A*.
- Dijkstra no **grafo espaço-tempo**, com reservation table, é o núcleo do
  planejamento single-drone.
- Em Python, `heapq` é um **min-heap**. Não há `decrease-key` nativo; o padrão é
  inserir uma nova entrada e **ignorar entradas antigas** quando `d > dist[u]`
  (*lazy deletion*).

**Fontes:** Dijkstra, 1959 (`https://link.springer.com/article/10.1007/BF01386390`);
Dasgupta §4.4; CP-Algorithms
(`https://cp-algorithms.com/graph/dijkstra.html`,
`https://cp-algorithms.com/graph/dijkstra_sparse.html`);
Python `heapq` (`https://docs.python.org/3/library/heapq.html`).

---

## 4. A* (A-star)

A* é uma busca **best-first** que ordena os nós por:

```text
f(n) = g(n) + h(n)
```

- `g(n)` é o custo real do caminho do start até `n`.
- `h(n)` é uma estimativa do custo de `n` até o goal.

Definições importantes:

- **Admissible:** `h(n) ≤ h*(n)` para todo `n`, onde `h*(n)` é o custo ótimo real.
  A heurística **nunca superestima**.
- **Consistent / monotone:** `h(u) ≤ c(u, v) + h(v)` para toda aresta `u → v`
  (desigualdade triangular).
- Toda heurística **consistente** é admissível, mas nem toda admissível é
  consistente.
- A* com `h` **admissível** é ótimo em *tree search* ou em *graph search* com
  **reabertura** de nós.
- A* com `h` **consistente** é ótimo em *graph search* **sem** reabertura, pois
  `f` não decresce ao longo do caminho.

No Fly-In:

- Uma boa heurística é a **distância estática de Dijkstra** até o `end_hub`,
  ignorando outros drones e reservas. Como usa os mesmos custos de entrada
  (1 ou 2), é **admissível e consistente**.
- `h = 0` também é admissível, mas transforma A* em Dijkstra e perde eficiência.
- O desempate por `priority` deve ser **secundário**, não uma alteração do custo
  primário. Critério lexicográfico: primeiro menor turno de chegada; em empate,
  menos entradas em zonas **não-priority**.
- Não dê custo negativo ou zero a `priority`: isso quebra Dijkstra/A* e pode
  produzir ciclos.

**Fontes:** Hart, Nilsson e Raphael, 1968
(`https://ieeexplore.ieee.org/document/4082128`); MIT 6.4110, L08
(`https://airr.mit.edu/_static/spring26/lectures/lec08/L08-Search.pdf`); McGill
COMP-424 (`https://www.cs.mcgill.ca/~dprecup/courses/AI/Lectures/ai-lecture03.pdf`);
Russell e Norvig, AIMA (`https://aima.cs.berkeley.edu/`).

---

## 5. Grafo expandido no tempo (time-expanded graph)

Um **time-expanded graph** transforma o planejamento com tempo em um grafo em que
cada nó representa um estado `(vértice, turno)`. Movimento e espera viram arestas
entre turnos.

Modelo básico:

- Nó: `(zona, t)`.
- **Espera:** `(zona, t) → (zona, t+1)`.
- **Movimento normal:** `(u, t) → (v, t+1)`, se `u-v` existe e há capacidade.
- **Movimento para `restricted`:** `(u, t-1) → (transit(u,v), t) → (v, t+1)`.
  - O link `u-v` é reservado no turno `t`.
  - A zona `v` é reservada no turno `t+1`.
  - O drone **não pode esperar** no estado de trânsito.
- `blocked` simplesmente **não gera arestas**.

Se o horizonte é `T`, o grafo tem `O(VT)` nós no modelo unitário e `O((V+E)T)`
arestas. Com estados de trânsito para `restricted`, adicione `O(ET)` nós/arestas.

No Fly-In, o time-expanded graph é a forma **correta** de modelar:

- chegada em turnos diferentes;
- espera em zonas;
- ocupação de zonas por turno;
- capacidade de links por turno;
- trânsito em `restricted`;
- reservas de rotas já planejadas.

A **reservation table** é a implementação **esparsa** desse grafo: em vez de
materializar todos os nós, guardamos apenas os usos `(zona, turno)` e
`(link, turno)`.

**Fontes:** Silver, *Cooperative Pathfinding* (2005), que busca em “three
dimensional space-time”
(`https://cdn.aaai.org/ojs/18726/18726-52-22369-1-10-20210928.pdf`); Stern et al.
(2019), que formaliza tempo discreto e ações de wait/move
(`https://cdn.aaai.org/ojs/18510/18510-77-22026-1-2-20210717.pdf`); Ford e
Fulkerson (1958), para redes dinâmicas e time-expanded networks
(`https://doi.org/10.1287/opre.6.3.419`).

---

## 6. MAPF — Multi-Agent Path Finding

MAPF é o problema de planejar caminhos para **múltiplos agentes**, cada um com
start e goal, de modo que os planos possam ser executados **simultaneamente** sem
colisões.

No MAPF clássico:

- O tempo é **discreto**.
- Cada ação (`move` ou `wait`) custa 1 time step.
- Cada agente ocupa exatamente um vértice por time step.
- Conflitos comuns: **vertex conflict**, **edge conflict**, **following
  conflict**, **cycle conflict**, **swapping conflict**.
- Objetivos comuns: **makespan** (tempo até o último agente chegar) e
  **sum of costs** (soma dos tempos de chegada).
- O problema é **NP-hard** em geral.

O Fly-In é uma variante **capacitada** de MAPF:

- Zonas podem ter `max_drones > 1`.
- Links têm `max_link_capacity`, compartilhada nas duas direções.
- `restricted` tem custo 2 e estado de trânsito.
- `priority` é **critério de desempate**, não custo.
- O objetivo é **makespan**.
- Start e end têm capacidade ilimitada.
- Drones entregues deixam de ocupar o `end_hub`.

Portanto, **não** é MAPF clássico com capacidade 1 por vértice. As definições de
conflito precisam ser generalizadas:

- **Vertex conflict** → violação de `max_drones`.
- **Edge conflict** → violação de `max_link_capacity`; dois drones no mesmo link no
  mesmo turno contam 2.
- **Following** é permitido se a capacidade da zona permitir, pois a vaga é
  liberada no mesmo turno.
- **Swap** consome 2 slots do link. Com `max_link_capacity=1`, é inviável; com
  capacidade 2, pode ser viável se as zonas também permitirem.

**Fontes:** Stern et al., *Multi-Agent Pathfinding: Definitions, Variants, and
Benchmarks* (2019); Erdmann e Lozano-Pérez, *On Multiple Moving Objects* (1987)
(`https://dl.acm.org/doi/10.1007/BF01840371`).

---

## 7. Cooperative A* e reservation table

**Cooperative A*** (CA*) é uma abordagem **decoupled**: resolve o problema como uma
**sequência de buscas single-agent**. Cada agente busca em espaço-tempo, desviando
das rotas já reservadas pelos agentes anteriores.

O artigo de Silver descreve que as buscas individuais são feitas em espaço-tempo
tridimensional, considerando as rotas planejadas dos outros agentes; uma ação de
**wait** é incluída; após calcular a rota de cada agente, os estados ao longo dela
são marcados na **reservation table**.

No Fly-In, a reservation table pode ser implementada como:

```text
zone_use[(zone, turn)]          -> int
link_use[(connection_key, turn)] -> int
```

Regras:

- Reservar a **rota inteira** do drone antes de planejar o próximo.
- `start_hub` e `end_hub` **não** precisam de reserva de capacidade.
- **Sair libera a vaga no mesmo turno.**
- `restricted`: reservar o **link** no turno de trânsito e a **zona** no turno de
  chegada.
- **Não** permitir wait no estado de trânsito.
- Um **swap** usa o mesmo link duas vezes no mesmo turno; com capacidade 1, é
  proibido.

CA* é **guloso e dependente da ordem**. Pode falhar mesmo quando existe solução,
porque uma rota ótima para um agente pode bloquear todos os caminhos possíveis para
outro (Silver mostra um contraexemplo). Variantes: **HCA*** usa heurística abstrata
para acelerar; **WHCA*** usa janelas de tempo para reduzir custo.

No mandatório do Fly-In, o **planejamento sequencial priorizado D1..DN** com
reservation table é suficiente para os mapas do subject, mas **não é ótimo
global**. Para o challenger, pode ser necessário melhorar a ordem, usar
backtracking ou aplicar CBS/PBS.

**Fonte:** Silver, *Cooperative Pathfinding*, AIIDE 2005
(`https://ojs.aaai.org/index.php/aiide/article/view/18726`; PDF:
`https://cdn.aaai.org/ojs/18726/18726-52-22369-1-10-20210928.pdf`).

---

## 8. CBS e PBS (alternativas — opcionais)

### 8.1 CBS — Conflict-Based Search

CBS é um algoritmo **optimal** de dois níveis:

- **High level:** busca em uma **árvore de restrições** (*constraint tree*, CT).
  Cada nó contém restrições do tipo `(agente, vértice, turno)`, uma solução e um custo.
- **Low level:** para cada agente, resolve um single-agent pathfinding em
  espaço-tempo respeitando as restrições do nó.
- Quando a solução do nó tem **conflito**, CBS cria dois filhos: um proíbe o agente
  `i` de ocupar o vértice conflitante no turno `t`; o outro proíbe o agente `j`.
- O primeiro nó válido extraído do high level é **ótimo** para o custo usado.

CBS clássico otimiza **sum of costs**. Para **makespan**, é necessário adaptar a
função de custo do high level e a poda — não é simplesmente trocar uma linha. CBS é
bom em corredores e gargalos, mas pode ser caro em espaços abertos. O high level é
**exponencial** no número de conflitos.

### 8.2 PBS — Priority-Based Search

> ⚠️ Neste contexto, **PBS = Priority-Based Search**, não “Principled CBS”.

PBS é uma generalização do prioritized planning:

- Mantém uma **ordem de prioridade parcial** entre agentes.
- Planeja os agentes em ordem, tratando os de maior prioridade como obstáculos
  dinâmicos.
- Quando dois planos conflitam, adiciona uma ordem `i ≺ j` ou `j ≺ i` e continua.
- Explora o espaço de ordens de prioridade com **depth-first search**.
- É mais eficiente que CBSw/P e costuma produzir soluções **near-optimal**, mas
  **não garante otimalidade**.
- Prioritized planning com ordem fixa é um **caso especial** de PBS.

No Fly-In:

- O mandatório pode usar **prioritized planning sequencial**, uma forma simples de
  PBS com ordem fixa.
- CBS/PBS são mais úteis para **bônus**, challenger ou para melhorar a qualidade.
- Se usar CBS, adapte as restrições para capacidades `> 1` (o CBS clássico assume
  conflito binário de vértice).
- Se usar PBS, não espere garantia de makespan ótimo.

**Fontes:** Sharon, Stern, Felner e Sturtevant, *Conflict-Based Search for Optimal
Multi-Agent Pathfinding*, Artificial Intelligence 219 (2015), pp. 40–66
(`https://doi.org/10.1016/j.artint.2014.11.006`; PDF AAAI 2012:
`https://cdn.aaai.org/ojs/8140/8140-13-11667-1-2-20201228.pdf`). Ma, Harabor,
Stuckey, Li e Koenig, *Searching with Consistent Prioritization for Multi-Agent
Path Finding*, AAAI 2019 (`https://doi.org/10.1609/aaai.v33i01.33017643`; PDF:
`https://www2.cs.sfu.ca/~hangma/pub/aaai19a.pdf`).

---

## 9. Capacidades e lower bounds

### 9.1 Regras de capacidade do Fly-In

- `max_drones` é a capacidade da **zona**.
- `max_link_capacity` é a capacidade da **conexão**, somando as duas direções.
- `start_hub` e `end_hub` têm capacidade **ilimitada**.
- **Sair libera a vaga no mesmo turno.**
- Um drone **não** pode se mover duas vezes no mesmo turno.
- **Não** pode esperar em cima de uma conexão.
- Drones entregues deixam de ocupar o `end_hub`.

### 9.2 Lower bound 1 — caminho mais curto ignorando congestionamento

Calcule o menor custo de start até end no grafo estático, com custos 1/2 e sem
outros drones. Esse valor é um **lower bound** para o makespan.

No challenger:

- O caminho mais curto tem **19 turnos**.
- São 15 arestas, mas 4 entradas em `restricted` adicionam 4 turnos extras:
  `15 + 4 = 19`.

### 9.3 Lower bound 2 — gargalo / fluxo

Se todos os drones precisam passar por um recurso de capacidade `c`, e o primeiro
drone pode chegar ao goal no turno `d`, então o último drone não pode chegar antes
de:

```text
d + ceil(D / c) - 1
```

Para `c = 1`, isso vira `d + D - 1`.

No challenger:

- `D = 25`.
- O primeiro drone pode chegar ao goal em 19.
- `final_torture2` tem `max_drones=1` e está em todos os caminhos após
  `final_merge`.
- Logo, os 25 drones precisam cruzar esse gargalo em turnos distintos; o último
  não pode chegar antes de `19 + 24 = 43`.
- O `maps/README.md` reporta **45 turnos** para a implementação de referência.
- Portanto, **43 é lower bound**; 45 é benchmark. Se 43 for alcançável, é ótimo.
  A versão 2 do bônus pede 43 (ver `Guias/ORIENTACAO.md`).

Uma forma mais forte é montar uma **time-expanded network** com capacidades e rodar
**max-flow** para um horizonte `T`. Se o fluxo máximo for menor que `D`, `T` é
inviável. Busca binária no horizonte dá um lower bound melhor. Ford e Fulkerson
formalizam fluxos dinâmicos e a construção de redes time-expanded.

**Fonte:** Ford e Fulkerson, *Constructing Maximal Dynamic Flows from Static
Flows*, Operations Research 6(3), 1958
(`https://doi.org/10.1287/opre.6.3.419`).

---

## 10. Complexidade

Notação:

- `Z` = número de zonas.
- `E` = número de conexões.
- `D` = número de drones.
- `T` = horizonte de tempo.
- `L` = número de linhas do mapa.

| Etapa | Complexidade |
|---|---:|
| Parsing e validação | `O(L)` |
| BFS/DFS de alcançabilidade | `O(Z + E)` |
| Dijkstra estático | `O((Z + E) log Z)` |
| Dijkstra/A* single-drone no espaço-tempo | `O((Z + E)T log(ZT))` |
| Planejamento sequencial de `D` drones | `O(D (Z + E)T log(ZT))` |
| Reservation table densa | `O((Z + E)T)` memória |
| Reservation table esparsa | `O(DT)` memória |
| CBS high level | exponencial no número de conflitos |
| PBS | exponencial no número de ordens de prioridade |

Observações:

- O fator `T` domina. Um horizonte mal escolhido pode inviabilizar a busca.
- Em Python, `heapq` com lazy deletion pode gerar mais entradas que o número de
  estados; ainda assim, o pico é polinomial no tamanho do grafo espaço-tempo.
- CBS e PBS são opcionais; o mandatório deve priorizar uma solução **correta e
  determinística**.

**Fontes:** Dasgupta cap. 4; CP-Algorithms; Sharon et al. (CBS); Ma et al. (PBS).

---

## 11. Parsing, validação e erros

### 11.1 Gramática do mapa

```text
nb_drones: <positive_integer>
start_hub: <name> <x> <y> [<metadata>]
end_hub:   <name> <x> <y> [<metadata>]
hub:       <name> <x> <y> [<metadata>]
connection: <name_a>-<name_b> [<metadata>]
```

Regras:

- `nb_drones:` é a **primeira linha significativa**.
- Linhas em branco são ignoradas.
- `#` inicia comentário, inclusive no fim da linha.
- Exatamente um `start_hub` e um `end_hub`.
- Conexões são **bidirecionais** e declaradas **depois** que as duas zonas existem.
- Nomes de zona são **únicos**, sem espaços e sem `-`.
- Coordenadas `x y` são inteiras e únicas.
- Metadados de zona: `zone`, `color`, `max_drones`.
- Metadados de conexão: `max_link_capacity`.
- `zone` padrão é `normal`; `max_drones` e `max_link_capacity` padrão são 1.
- Capacidades devem ser inteiros **positivos**.

### 11.2 Validações obrigatórias

Rejeitar com erro:

- `nb_drones` ausente, não inteiro ou `<= 0`.
- `start_hub`/`end_hub` ausente, duplicado ou iguais.
- `start_hub` ou `end_hub` do tipo `blocked`.
- Zona duplicada por nome ou coordenada.
- Conexão duplicada (`a-b` e `b-a`) ou auto-conexão (`a-a`).
- Conexão referenciando zona não declarada.
- Tipo de zona inválido.
- Chave de metadado desconhecida ou repetida.
- Capacidade inválida.
- Nome com `-` ou espaço.
- Mapa sem conexões.
- Grafo desconectado / end inalcançável.

### 11.3 Erros e exit codes

- Mapa inválido: `Error: line N: <motivo>` em **`stderr`**, exit `1`.
- End inalcançável: `Error: no path from '<start>' to '<end>'`, exit `1`.
- Arquivo inexistente/ilegível: erro claro, exit `1`.
- Sucesso: exit `0`.
- `KeyboardInterrupt`: exit `130`, se implementado.

O `stdout` deve conter **apenas** a saída de movimentos. Nunca emitir traceback cru
em uso normal. Use `with open(...)` para garantir o fechamento do arquivo.

### 11.4 Determinismo

A mesma entrada deve produzir a **mesma** saída. Para isso:

- Ordem fixa de drones.
- Chaves canônicas para conexões.
- Critério de desempate explícito.
- Ordenação estável de vizinhos.
- Nada de `set` não ordenado influenciando a saída.

**Fontes:** Python docs — `argparse`
(`https://docs.python.org/3/library/argparse.html`), `sys.exit`
(`https://docs.python.org/3/library/sys.html#sys.exit`), `dataclasses`
(`https://docs.python.org/3/library/dataclasses.html`), `enum`
(`https://docs.python.org/3/library/enum.html`), `heapq`
(`https://docs.python.org/3/library/heapq.html`).

---

## 12. Checklist de conceitos para dominar

- [ ] Grafo: vértice, aresta, grafo conexo, ciclo, direcionado vs não direcionado.
- [ ] Lista de adjacência `O(V + E)` vs matriz `O(V²)`.
- [ ] BFS: fila, camadas, `O(V+E)`, reconstrução de caminho, alcançabilidade.
- [ ] DFS: pilha/recursão e quando **não** usar para menor caminho.
- [ ] Dijkstra: pesos não negativos, heap, `O((V+E) log V)`, lazy deletion.
- [ ] A*: `f=g+h`, admissível vs consistente, quando é ótimo.
- [ ] Time-expanded graph: estado `(zona, turno)`, wait, `restricted` (2 turnos).
- [ ] MAPF: conflitos, makespan vs sum of costs, NP-hard.
- [ ] Cooperative A* + reservation table: sequencial, guloso, dependente da ordem.
- [ ] CBS (constraint tree) e PBS (Priority-Based Search), e por que são opcionais.
- [ ] Capacidade de zona vs conexão (compartilhada bidirecional); liberar vaga no
      mesmo turno; proibido wait em conexão.
- [ ] Lower bounds: caminho mais curto e gargalo `d + ceil(D/c) - 1`.
- [ ] Complexidade do planejamento `O(D (Z+E) T log(ZT))`.
- [ ] Parsing/validação linha a linha com `Error: line N:` e exit codes.
- [ ] Determinismo (ordem fixa, chave canônica, desempate estável).

---

## Apêndice A — Perguntas prováveis de defesa

1. **Por que BFS não basta?**
   Porque `restricted` custa 2 e o problema tem capacidades por turno; BFS só
   resolve menor número de arestas.
2. **Por que Dijkstra e não BFS?**
   Porque os custos não são unitários: `restricted` custa 2.
3. **Por que A* é ótimo?**
   Com `h` admissível, A* não expande um goal subótimo antes de um caminho ótimo;
   com `h` consistente, graph search sem reabertura também é ótimo.
4. **Como modelar `restricted`?**
   Com estado de trânsito: link reservado no turno `t`, zona reservada no turno
   `t+1`; sem wait no trânsito.
5. **Como garantir liberação de vaga no mesmo turno?**
   Reservando a rota e validando o turno inteiro antes do commit; quem sai libera a
   vaga para quem entra.
6. **CA*, CBS e PBS: qual a diferença?**
   CA* é decoupled/guloso e dependente da ordem; CBS é optimal e usa constraint
   tree; PBS explora ordens de prioridade com DFS e é near-optimal.
7. **Como calcular lower bound?**
   Caminho mais curto ignorando congestionamento e, se houver gargalo,
   `d + ceil(D/c) - 1`.
8. **Qual a complexidade do planejamento?**
   `O(D (Z+E) T log(ZT))` para planejamento sequencial com Dijkstra/A* no
   espaço-tempo.
9. **Como evitar deadlock?**
   Horizonte máximo, detecção de N turnos sem movimento, erro claro e, se
   necessário, backtracking/reordenação.
10. **Por que 43 no challenger?**
    Primeiro drone chega em 19; `final_torture2` tem capacidade 1; os outros 24
    precisam de turnos distintos; `19 + 24 = 43`. O README cita 45 como benchmark.

---

## 13. Referências (sem Wikipedia)

### Grafos, BFS, DFS, Dijkstra e A*

- Diestel, *Graph Theory* — `https://diestel-graph-theory.com/`
- Dasgupta, Papadimitriou e Vazirani, *Algorithms*, cap. 4 —
  `https://people.eecs.berkeley.edu/~vazirani/algorithms/chap4.pdf`
- MIT OCW 6.006 — `https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-spring-2020/`
- MIT OCW 6.006, lecture notes —
  `https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-spring-2020/pages/lecture-notes/`
- MIT OCW 6.006, BFS —
  `https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-spring-2020/resources/mit6_006s20_lec9/`
- MIT OCW 6.006, Dijkstra —
  `https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-spring-2020/resources/mit6_006s20_lec13/`
- CP-Algorithms, BFS — `https://cp-algorithms.com/graph/breadth-first-search.html`
- CP-Algorithms, Dijkstra — `https://cp-algorithms.com/graph/dijkstra.html`
- CP-Algorithms, Dijkstra sparse —
  `https://cp-algorithms.com/graph/dijkstra_sparse.html`
- Dijkstra (1959) — `https://link.springer.com/article/10.1007/BF01386390`
- Hart, Nilsson e Raphael (1968) —
  `https://ieeexplore.ieee.org/document/4082128`
- MIT 6.4110, L08 Search —
  `https://airr.mit.edu/_static/spring26/lectures/lec08/L08-Search.pdf`
- McGill COMP-424, Informed Search —
  `https://www.cs.mcgill.ca/~dprecup/courses/AI/Lectures/ai-lecture03.pdf`
- Russell e Norvig, AIMA — `https://aima.cs.berkeley.edu/`

### MAPF, Cooperative A*, CBS e PBS

- Silver, *Cooperative Pathfinding*, AIIDE 2005 —
  `https://ojs.aaai.org/index.php/aiide/article/view/18726`
- Silver, PDF —
  `https://cdn.aaai.org/ojs/18726/18726-52-22369-1-10-20210928.pdf`
- Stern et al., *MAPF: Definitions, Variants, and Benchmarks*, AAAI 2019 —
  `https://cdn.aaai.org/ojs/18510/18510-77-22026-1-2-20210717.pdf`
- Sharon et al., *Conflict-Based Search for Optimal Multi-Agent Pathfinding*,
  Artificial Intelligence 219 (2015) —
  `https://doi.org/10.1016/j.artint.2014.11.006`
- CBS, PDF AAAI 2012 —
  `https://cdn.aaai.org/ojs/8140/8140-13-11667-1-2-20201228.pdf`
- Ma et al., *Searching with Consistent Prioritization for MAPF*, AAAI 2019 —
  `https://doi.org/10.1609/aaai.v33i01.33017643`
- PBS, PDF — `https://www2.cs.sfu.ca/~hangma/pub/aaai19a.pdf`
- Erdmann e Lozano-Pérez, *On Multiple Moving Objects* (1987) —
  `https://dl.acm.org/doi/10.1007/BF01840371`
- Ford e Fulkerson, *Constructing Maximal Dynamic Flows from Static Flows* (1958) —
  `https://doi.org/10.1287/opre.6.3.419`

### Python e projeto

- `heapq` — `https://docs.python.org/3/library/heapq.html`
- `enum` — `https://docs.python.org/3/library/enum.html`
- `dataclasses` — `https://docs.python.org/3/library/dataclasses.html`
- `sys.exit` — `https://docs.python.org/3/library/sys.html#sys.exit`
- `argparse` — `https://docs.python.org/3/library/argparse.html`
- `Guias/ORIENTACAO.md`, `Guias/TAREFAS_MANDATORIO.md`
- `maps.tar.gz` → `maps/README.md`, `maps/challenger/01_the_impossible_dream.txt`

---

## Apêndice B — Estado verificado e pendências

**Verificado:**

- `Guias/ORIENTACAO.md` e `Guias/TAREFAS_MANDATORIO.md` existem.
- `maps.tar.gz` contém 9 mapas mandatórios + challenger.
- Challenger: 25 drones, 54 zonas, 70 conexões.
- Caminho mais curto do challenger: 19 turnos.
- Gargalo `final_torture2`: `max_drones=1`.
- Lower bound: 43; README do pacote: 45.
- PDFs de Silver, Stern, CBS e PBS localizados.

**Pendências:**

- Confirmar o PDF oficial do subject no intra e ajustar qualquer divergência.
- Validar os números de makespan **rodando os mapas**, não apenas confiando nos
  READMEs de referência.
