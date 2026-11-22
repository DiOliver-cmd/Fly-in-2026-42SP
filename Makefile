.PHONY: install run debug test clean lint lint-strict

PYTHON ?= python3
MAP ?= maps/easy/01_linear_path.txt

install:
	$(PYTHON) -m pip install flake8 mypy pytest

run:
	$(PYTHON) fly_in.py $(MAP)

debug:
	$(PYTHON) -m pdb fly_in.py $(MAP)

test:
	$(PYTHON) -m pytest -q

clean:
	rm -rf __pycache__ .mypy_cache .pytest_cache tests/__pycache__

lint:
	flake8 .
	mypy . --warn-return-any --warn-unused-ignores --ignore-missing-imports \
	       --disallow-untyped-defs --check-untyped-defs

lint-strict:
	flake8 .
	mypy . --strict
