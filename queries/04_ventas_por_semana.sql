-- Pregunta: ¿cuántas ventas hay por semana?
-- Misma definición de venta que por día. Semana ISO: de lunes a domingo.
-- La primera semana (empieza el lunes 2025-12-29, los datos el 2026-01-01) y
-- la última (corte a mitad de semana) están incompletas: se marcan para no
-- compararlas con el resto como si lo fueran.

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

),

daily as (

    select
        dim_date.week_start_date,
        dim_date.iso_year_week,
        dim_date.date_day,
        coalesce(sales.ventas, 0) as ventas
    from marts.dim_date
    cross join date_range
    left join sales
        on dim_date.date_day = sales.paid_date
    where dim_date.date_day between date_range.first_day and date_range.last_day

)

select
    iso_year_week                 as semana_iso,
    week_start_date               as lunes,
    cast(sum(ventas) as bigint)   as ventas,
    round(avg(ventas), 1)         as media_diaria,
    -- Completa si tiene sus 7 días y ninguno es el día de corte.
    count(*) = 7
        and max(date_day) < (select last_day from date_range) as semana_completa
from daily
group by iso_year_week, week_start_date
order by week_start_date
