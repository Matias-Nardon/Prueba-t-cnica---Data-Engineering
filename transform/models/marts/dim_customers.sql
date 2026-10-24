-- Dimensión de clientes con su actividad a la fecha de referencia.

with customers as (

    select * from {{ ref('stg_ecommerce__customers') }}

),

as_of as (

    select {{ as_of_timestamp() }} as as_of_at

),

customer_orders as (

    select
        orders.customer_id,
        count(*)                                           as order_count,
        count(*) filter (where not orders.is_cancelled)    as valid_order_count,
        min(orders.created_at)                             as first_order_at,
        max(orders.created_at) filter (where not orders.is_cancelled) as last_valid_order_at
    from {{ ref('fct_orders') }} as orders
    cross join as_of
    where orders.created_at <= as_of.as_of_at
    group by orders.customer_id

)

select
    customers.customer_id,
    customers.first_name,
    customers.last_name,
    customers.email,
    customers.country_code,
    customers.segment,
    customers.created_at                                    as signup_at,
    cast(customers.created_at as date)                      as signup_date,
    cast(date_trunc('month', customers.created_at) as date) as signup_month,
    customer_orders.first_order_at,
    customer_orders.last_valid_order_at,
    coalesce(customer_orders.order_count, 0)                as order_count,
    coalesce(customer_orders.valid_order_count, 0)          as valid_order_count,
    coalesce(customer_orders.order_count, 0) > 0            as has_ordered,
    -- No se filtra la dimensión: se marca, para que ningún hecho quede huérfano.
    customers.created_at <= as_of.as_of_at                  as is_registered,
    -- Activo: al menos una orden no cancelada en la ventana de actividad.
    coalesce(
        customer_orders.last_valid_order_at
            > as_of.as_of_at - to_days({{ var('active_customer_window_days') }}),
        false
    )                                                       as is_active,
    as_of.as_of_at
from customers
cross join as_of
left join customer_orders
    on customers.customer_id = customer_orders.customer_id
