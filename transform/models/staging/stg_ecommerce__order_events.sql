with source as (

    select * from {{ source('ecommerce', 'orders') }}

),

deduplicated as (

    -- La fuente reentrega eventos: mismo order_id, status y event_at con otro
    -- _ingested_at (entrega at-least-once). Conservamos la primera ingesta.
    select *
    from source
    qualify row_number() over (
        partition by order_id, status, event_at
        order by _ingested_at
    ) = 1

)

select
    md5(concat_ws('|', order_id, status, event_at)) as order_event_id,
    order_id,
    customer_id,
    lower(trim(status)) as status,
    event_at,
    _ingested_at
from deduplicated
