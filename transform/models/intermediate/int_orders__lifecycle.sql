-- Una fila por orden: pasa del log de eventos a las fechas de cada hito
-- y al estado final.

with events as (

    select
        *,
        -- Posición en el ciclo de vida. Solo se usa para desempatar si dos
        -- eventos de una orden tuvieran el mismo event_at (hoy no ocurre).
        case status
            when 'created'   then 1
            when 'paid'      then 2
            when 'shipped'   then 3
            when 'delivered' then 4
            when 'returned'  then 5
            when 'cancelled' then 6
        end as status_rank
    from {{ ref('stg_ecommerce__order_events') }}

),

orders as (

    select
        order_id,
        any_value(customer_id)                            as customer_id,
        min(event_at) filter (where status = 'created')   as created_event_at,
        min(event_at)                                     as first_event_at,
        min(event_at) filter (where status = 'paid')      as paid_at,
        min(event_at) filter (where status = 'shipped')   as shipped_at,
        min(event_at) filter (where status = 'delivered') as delivered_at,
        min(event_at) filter (where status = 'cancelled') as cancelled_at,
        min(event_at) filter (where status = 'returned')  as returned_at,
        max(event_at)                                     as last_event_at,
        arg_max(status, (event_at, status_rank))          as final_status
    from events
    group by order_id

)

select
    order_id,
    customer_id,
    -- 5 órdenes no tienen evento created: se toma su primer evento.
    coalesce(created_event_at, first_event_at) as created_at,
    created_event_at is null                   as is_missing_created_event,
    paid_at,
    shipped_at,
    delivered_at,
    cancelled_at,
    returned_at,
    last_event_at,
    final_status,
    final_status in ('delivered', 'returned', 'cancelled') as is_closed
from orders
