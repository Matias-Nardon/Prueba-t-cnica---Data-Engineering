-- Valoriza cada línea de orden con el precio de lista del producto.
-- Limitación: la fuente no guarda el precio de la venta ni su histórico,
-- así que se usa el precio vigente en la extracción.

with items as (

    select * from {{ ref('stg_ecommerce__order_items') }}

),

products as (

    select * from {{ ref('stg_ecommerce__products') }}

)

select
    items.order_item_id,
    items.order_id,
    items.line_number,
    items.product_id,
    products.category,
    items.quantity,
    products.unit_price,
    products.currency,
    items.quantity * products.unit_price as line_amount
from items
inner join products
    on items.product_id = products.product_id
