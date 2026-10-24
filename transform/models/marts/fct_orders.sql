-- Hechos a nivel de orden: una fila por orden con sus hitos, su importe y los
-- indicadores que aplican las definiciones de negocio (ver README, Decisiones).

with orders as (

    select * from {{ ref('int_orders__lifecycle') }}

),

order_amounts as (

    select
        order_id,
        count(*)         as line_count,
        sum(quantity)    as unit_count,
        sum(line_amount) as gross_amount
    from {{ ref('int_order_items__priced') }}
    group by order_id

),

flagged as (

    select
        orders.*,
        order_amounts.order_id is null as is_missing_items,
        coalesce(order_amounts.line_count, 0)   as line_count,
        coalesce(order_amounts.unit_count, 0)   as unit_count,
        coalesce(order_amounts.gross_amount, 0) as gross_amount,

        -- Entregada: llegó al cliente, aunque después se devolviera.
        orders.final_status in ('delivered', 'returned') as is_delivered,
        orders.final_status = 'cancelled'                as is_cancelled,
        orders.cancelled_at is not null
            and orders.paid_at is not null               as is_cancelled_after_payment,

        -- Venta: orden pagada y no cancelada después.
        orders.paid_at is not null
            and orders.cancelled_at is null              as is_sale,
        -- Ingreso neto: venta que además no se devolvió.
        orders.paid_at is not null
            and orders.cancelled_at is null
            and orders.returned_at is null               as is_net_revenue
    from orders
    left join order_amounts
        on orders.order_id = order_amounts.order_id

)

select
    order_id,
    customer_id,
    created_at,
    cast(created_at as date) as created_date,
    paid_at,
    cast(paid_at as date)    as paid_date,
    shipped_at,
    delivered_at,
    cancelled_at,
    returned_at,
    last_event_at,
    final_status,
    case
        when final_status in ('delivered', 'returned', 'cancelled') then final_status
        else 'in_progress'
    end                      as status_group,
    is_closed,
    is_delivered,
    is_cancelled,
    is_cancelled_after_payment,
    is_sale,
    is_net_revenue,
    line_count,
    unit_count,
    gross_amount,
    case when is_net_revenue then gross_amount else 0 end as net_revenue_amount,
    is_missing_items,
    is_missing_created_event
from flagged
