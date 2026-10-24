-- Pregunta: ¿qué proporción de las órdenes se entrega y qué proporción se cancela?
-- Cada orden cuenta por su estado final.
-- Denominador principal: órdenes cerradas (delivered, returned, cancelled).
-- Las que siguen en curso aún no han podido entregarse y, si se incluyeran,
-- bajarían la tasa de entrega de forma artificial. Se muestra también el %
-- sobre el total para que la comparación sea transparente.
-- Una orden devuelta cuenta como entregada (llegó al cliente) y se desglosa.

with orders as (

    select * from marts.fct_orders

),

totals as (

    select
        count(*)                     as total,
        count(*) filter (where is_closed) as cerradas
    from orders

),

breakdown as (

    select 1 as orden, 'Entregadas' as resultado, count(*) as ordenes, true as es_cerrada
    from orders where is_delivered
    union all
    select 2, '   sin devolución', count(*), true
    from orders where final_status = 'delivered'
    union all
    select 3, '   devueltas después', count(*), true
    from orders where final_status = 'returned'
    union all
    select 4, 'Canceladas', count(*), true
    from orders where is_cancelled
    union all
    select 5, '   antes del pago', count(*), true
    from orders where is_cancelled and not is_cancelled_after_payment
    union all
    select 6, '   después del pago', count(*), true
    from orders where is_cancelled_after_payment
    union all
    select 7, 'En curso (no cerradas)', count(*), false
    from orders where not is_closed
    union all
    select 8, 'Total', count(*), null
    from orders

)

select
    breakdown.resultado,
    breakdown.ordenes,
    case when breakdown.es_cerrada
        then round(100.0 * breakdown.ordenes / totals.cerradas, 1)
    end                                                  as pct_sobre_cerradas,
    round(100.0 * breakdown.ordenes / totals.total, 1)   as pct_sobre_total
from breakdown
cross join totals
order by breakdown.orden
