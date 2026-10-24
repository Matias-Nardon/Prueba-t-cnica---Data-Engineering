-- Hechos a nivel de línea de orden. Permite abrir el ingreso por producto y
-- categoría con los mismos criterios de venta e ingreso que fct_orders.

with items as (

    select * from {{ ref('int_order_items__priced') }}

),

orders as (

    select * from {{ ref('fct_orders') }}

)

select
    items.order_item_id,
    items.order_id,
    orders.customer_id,
    items.product_id,
    items.category,
    items.quantity,
    items.unit_price,
    items.currency,
    items.line_amount,
    orders.paid_date,
    orders.final_status,
    orders.is_sale,
    orders.is_net_revenue,
    case when orders.is_net_revenue then items.line_amount else 0 end as net_revenue_amount
from items
inner join orders
    on items.order_id = orders.order_id
