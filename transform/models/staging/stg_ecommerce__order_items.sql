with source as (

    select * from {{ source('ecommerce', 'order_items') }}

),

deduplicated as (

    -- Igual que en los eventos: una línea puede llegar más de una vez.
    -- La clave natural es (order_id, line_number); conservamos la primera ingesta.
    select *
    from source
    qualify row_number() over (
        partition by order_id, line_number
        order by _ingested_at
    ) = 1

)

select
    concat_ws('-', order_id, line_number) as order_item_id,
    order_id,
    line_number,
    product_id,
    quantity,
    _ingested_at
from deduplicated
