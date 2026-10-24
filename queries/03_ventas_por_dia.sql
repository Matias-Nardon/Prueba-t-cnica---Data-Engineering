-- Pregunta: ¿cuántas ventas hay por día?
-- Venta: orden pagada y no cancelada después (is_sale), fechada por el pago.
-- Rango: desde la primera orden registrada hasta la fecha de referencia; los
-- días sin ventas aparecen con 0 gracias al calendario.

with sales as (

    select paid_date, count(*) as ventas
    from marts.fct_orders
    where is_sale
    group by paid_date

),

date_range as (

    select
        (select min(created_date) from marts.fct_orders)           as first_day,
        (select cast(max(as_of_at) as date) from marts.dim_customers) as last_day

)

select
    dim_date.date_day                  as dia,
    dim_date.iso_year_week             as semana_iso,
    coalesce(sales.ventas, 0)          as ventas,
    -- El día de corte solo tiene las primeras horas (hasta las 03:00).
    dim_date.date_day < date_range.last_day as dia_completo
from marts.dim_date
cross join date_range
left join sales
    on dim_date.date_day = sales.paid_date
where dim_date.date_day between date_range.first_day and date_range.last_day
order by dim_date.date_day
