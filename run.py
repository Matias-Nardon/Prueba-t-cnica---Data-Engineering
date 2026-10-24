"""Punto de entrada del proceso batch diario.

Construye el modelo de datos a partir de raw (dbt build: modelos + tests) y,
a continuación, ejecuta las consultas de negocio de queries/ sobre el warehouse.

Uso:
    python run.py                  # proceso completo
    python run.py --skip-queries   # solo construir el modelo
    python run.py --select staging # construir una parte del modelo

Devuelve código de salida 0 si todo va bien y 1 si algo falla, para que un
orquestador (Airflow, cron...) pueda detectar el error.
"""

import argparse
import logging
import os
import sys
import time
from pathlib import Path

import duckdb
from dbt.cli.main import dbtRunner

ROOT = Path(__file__).resolve().parent
RAW_PATH = ROOT / "data" / "ecommerce.duckdb"
WAREHOUSE_PATH = ROOT / "data" / "warehouse.duckdb"
DBT_DIR = ROOT / "transform"
QUERIES_DIR = ROOT / "queries"

log = logging.getLogger("pipeline")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Proceso batch del modelo de e-commerce.")
    parser.add_argument("--select", help="Selector de dbt para construir solo una parte del modelo.")
    parser.add_argument("--skip-queries", action="store_true", help="No ejecutar las consultas de negocio.")
    return parser.parse_args()


def build_model(select: str | None) -> bool:
    """Ejecuta dbt build (run + test en orden de dependencias)."""
    os.environ["RAW_PATH"] = str(RAW_PATH)
    os.environ["WAREHOUSE_PATH"] = str(WAREHOUSE_PATH)

    args = ["build", "--project-dir", str(DBT_DIR), "--profiles-dir", str(DBT_DIR)]
    if select:
        args += ["--select", select]

    result = dbtRunner().invoke(args)
    return result.success


def run_queries() -> None:
    """Ejecuta cada consulta de queries/ e imprime el resultado."""
    query_files = sorted(QUERIES_DIR.glob("*.sql"))
    if not query_files:
        log.info("No hay consultas en %s", QUERIES_DIR)
        return

    with duckdb.connect(str(WAREHOUSE_PATH), read_only=True) as con:
        for path in query_files:
            print(f"\n=== {path.stem} ===")
            con.sql(path.read_text(encoding="utf-8")).show(max_rows=60)


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    # La consola de Windows no siempre usa UTF-8 y las tablas de DuckDB llevan caracteres de caja.
    sys.stdout.reconfigure(encoding="utf-8")
    args = parse_args()

    if not RAW_PATH.exists():
        log.error("No se encuentra el origen: %s", RAW_PATH)
        return 1

    start = time.monotonic()
    log.info("Construyendo el modelo (dbt build)...")
    if not build_model(args.select):
        log.error("dbt build ha fallado: revisa la salida anterior.")
        return 1

    if not args.skip_queries:
        log.info("Ejecutando consultas de negocio...")
        run_queries()

    log.info("Proceso terminado en %.1f s", time.monotonic() - start)
    return 0


if __name__ == "__main__":
    sys.exit(main())
