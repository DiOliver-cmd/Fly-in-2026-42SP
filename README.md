# Fly-In (42)

Simulador de tráfego de drones entre zonas, com busca de caminhos no
espaço-tempo e representação visual no terminal.

## Requisitos

- Python >= 3.10
- `flake8`, `mypy`, `pytest` (ver `Makefile` / `scripts/ci.sh`)

## Estrutura

```
fly_in.py          # entry point
models.py          # Zone, Connection, Drone, Network, ZoneType (OO)
parser.py          # leitura dos mapas
graph.py           # grafo próprio e alcançabilidade (BFS)
pathfinder.py      # busca espaço-tempo
simulation.py      # simulação
output.py          # formato de saída
renderer.py        # visualização no terminal
maps/              # easy/ medium/ hard/ challenger/
tests/
```

## Uso

```bash
python3 fly_in.py maps/easy/01_linear_path.txt
```

## Verificações

```bash
bash scripts/ci.sh
```

O mesmo comando roda no GitHub Actions (job `checks`) em cada pull request
para `main`.
