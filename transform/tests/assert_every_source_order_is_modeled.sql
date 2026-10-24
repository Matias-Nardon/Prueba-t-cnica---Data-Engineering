-- Ninguna orden de la fuente se pierde por el camino: toda order_id que llega
-- a raw tiene que estar en fct_orders.

select distinct source_orders.order_id
from {{ source('ecommerce', 'orders') }} as source_orders
left join {{ ref('fct_orders') }} as fct
    on source_orders.order_id = fct.order_id
where fct.order_id is null
