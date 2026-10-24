-- Pregunta: ¿cómo se abren los ingresos por categoría de producto?
-- Misma definición que el total (ingreso neto), a nivel de línea de orden.
-- La suma de las categorías cuadra con el ingreso neto total (lo garantiza el
-- test assert_revenue_reconciles_between_facts).

select
    category                                                    as categoria,
    count(distinct order_id)                                    as ordenes,
    cast(sum(quantity) as bigint)                               as unidades,
    sum(net_revenue_amount)                                     as ingreso_neto_usd,
    round(100.0 * sum(net_revenue_amount) / sum(sum(net_revenue_amount)) over (), 1)
                                                                as pct_del_total
from marts.fct_order_items
where is_net_revenue
group by category
order by ingreso_neto_usd desc
