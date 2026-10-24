-- Pregunta: ¿cuáles son los ingresos totales?
-- KPI principal: ingreso neto = ventas (pagadas y no canceladas) que no se
-- devolvieron. Se presenta como un puente desde el importe pagado para que
-- se vea de dónde sale cada diferencia.
-- Importe = cantidad × precio de lista actual, en USD (la fuente no guarda el
-- precio de la venta; ver Decisiones en el README).

with orders as (

    select * from marts.fct_orders where paid_at is not null

),

bridge as (

    select 1 as orden, 'Órdenes pagadas' as concepto,
           count(*) as ordenes, sum(gross_amount) as importe_usd
    from orders

    union all

    select 2, '(-) Canceladas después del pago',
           -count(*), -sum(gross_amount)
    from orders
    where is_cancelled_after_payment

    union all

    select 3, '(=) Ventas',
           count(*), sum(gross_amount)
    from orders
    where is_sale

    union all

    select 4, '(-) Devueltas',
           -count(*), -sum(gross_amount)
    from orders
    where is_sale and not is_net_revenue

    union all

    select 5, '(=) Ingreso neto',
           count(*), sum(net_revenue_amount)
    from orders
    where is_net_revenue

)

select
    concepto,
    ordenes,
    importe_usd,
    -- Ticket medio solo en las filas de total, no en las de ajuste.
    case when orden in (1, 3, 5) then round(importe_usd / ordenes, 2) end as ticket_medio_usd
from bridge
order by orden
