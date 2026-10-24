-- El ingreso debe dar lo mismo sumado por orden que por línea. Si no cuadra,
-- una de las dos tablas de hechos pierde o duplica filas.

with by_order as (

    select
        sum(gross_amount)       as gross_amount,
        sum(net_revenue_amount) as net_revenue_amount
    from {{ ref('fct_orders') }}

),

by_line as (

    select
        sum(line_amount)        as gross_amount,
        sum(net_revenue_amount) as net_revenue_amount
    from {{ ref('fct_order_items') }}

)

select *
from by_order
cross join by_line
where by_order.gross_amount <> by_line.gross_amount
   or by_order.net_revenue_amount <> by_line.net_revenue_amount
