-- =============================================================================
-- Perfilado del schema raw (fase 0, antes de modelar)
-- =============================================================================
-- Objetivo: entender la granularidad de cada tabla, detectar problemas de
-- calidad y medir las alternativas de cada definición de negocio.
-- Se ejecuta contra data/ecommerce.duckdb, por ejemplo:
--   duckdb data/ecommerce.duckdb -readonly < analysis/01_perfilado_raw.sql
-- Los resultados obtenidos están anotados en cada bloque (corte 2026-07-01 03:00).


-- 1. Volumen y estructura ------------------------------------------------------
select schema_name, table_name, estimated_size from duckdb_tables();
-- customers 600 | products 80 | orders 15.608 | order_items 7.820

summarize raw.customers;
summarize raw.products;
summarize raw.orders;
summarize raw.order_items;
-- Sin nulos en ninguna columna. customers y products tienen un único
-- _extracted_at (2026-07-01 03:00): son snapshots completos.
-- orders y order_items son append con _ingested_at: llegan como eventos.


-- 2. Unicidad de claves --------------------------------------------------------
select count(*) as filas, count(distinct customer_id) as ids from raw.customers;
-- 600 / 600: sin duplicados

select count(*) as filas, count(distinct product_id) as ids from raw.products;
-- 80 / 80: sin duplicados

select
    count(*)                              as filas,
    count(distinct order_id)              as ordenes,
    count(distinct (order_id, status))    as orden_estado
from raw.orders;
-- 15.608 filas, 3.998 órdenes, 15.165 pares orden-estado

-- ¿Son duplicados exactos o eventos distintos?
select count(*) as duplicados_exactos
from (select order_id, status, event_at from raw.orders group by all having count(*) > 1);
-- 443 eventos repetidos: mismo order_id, status y event_at con distinto
-- _ingested_at. Es una reentrega (at-least-once), no un evento nuevo.

select count(*) as filas, count(distinct (order_id, line_number)) as pk from raw.order_items;
-- 7.820 / 7.615: 205 líneas reingestadas con el mismo contenido.


-- 3. Integridad referencial ----------------------------------------------------
select count(*) as ordenes_sin_cliente
from raw.orders o
where not exists (select 1 from raw.customers c where c.customer_id = o.customer_id);
-- 0

select count(*) as items_sin_producto
from raw.order_items i
where not exists (select 1 from raw.products p where p.product_id = i.product_id);
-- 0

select count(*) as items_sin_orden
from raw.order_items i
where not exists (select 1 from raw.orders o where o.order_id = i.order_id);
-- 0

select count(distinct order_id) as ordenes_sin_items
from raw.orders o
where not exists (select 1 from raw.order_items i where i.order_id = o.order_id);
-- 5: órdenes con importe 0


-- 4. Ciclo de vida de las órdenes ----------------------------------------------
select status, count(*) from raw.orders group by 1 order by 2 desc;
-- created, paid, shipped, delivered, cancelled, returned

select secuencia, count(*) as ordenes
from (
    select order_id, string_agg(status, ' > ' order by event_at) as secuencia
    from (select distinct order_id, status, event_at from raw.orders)
    group by 1
)
group by 1
order by 2 desc;
-- La secuencia dominante es created > paid > shipped > delivered.
-- 4 órdenes empiezan en paid sin evento created.

select count(*) as eventos_fuera_de_orden
from (
    select
        order_id,
        min(event_at) filter (status = 'created')   as created_at,
        min(event_at) filter (status = 'paid')      as paid_at,
        min(event_at) filter (status = 'delivered') as delivered_at,
        min(event_at) filter (status = 'cancelled') as cancelled_at,
        min(event_at) filter (status = 'returned')  as returned_at
    from raw.orders
    group by 1
)
where delivered_at < paid_at or cancelled_at < created_at or returned_at < delivered_at;
-- 0


-- 5. Cobertura temporal --------------------------------------------------------
select min(created_at), max(created_at) from raw.customers;
-- 2025-07-02 -> 2026-06-30

select min(event_at), max(event_at) from raw.orders;
-- 2026-01-01 -> 2026-07-01: el histórico de órdenes empieza en enero de 2026,
-- seis meses después que el de clientes.


-- 6. Precio ---------------------------------------------------------------------
select count(*) as productos_modificados from raw.products where updated_at > created_at;
-- 26: el precio pudo cambiar y no hay histórico ni precio en order_items.

select distinct currency from raw.products;
-- USD únicamente


-- 7. Insumos para las definiciones de negocio ----------------------------------
-- Frecuencia de compra: días entre órdenes consecutivas de un mismo cliente.
select median(dias) as mediana, quantile_cont(dias, 0.8) as p80
from (
    select datediff(
        'day',
        lag(primer_evento) over (partition by customer_id order by primer_evento),
        primer_evento
    ) as dias
    from (select order_id, customer_id, min(event_at) as primer_evento from raw.orders group by all)
)
where dias is not null;
-- mediana 7 días, p80 17 días: una ventana de actividad de 30 días discrimina;
-- con 90 días casi todos los compradores salen activos (398 de 399).
