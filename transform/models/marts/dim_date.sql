-- Calendario continuo desde el primer alta de cliente hasta la fecha de
-- referencia. Permite mostrar días, semanas y meses sin actividad (con 0)
-- en lugar de que desaparezcan de los informes.

with bounds as (

    select
        cast(min(created_at) as date)       as start_date,
        cast({{ as_of_timestamp() }} as date) as end_date
    from {{ ref('stg_ecommerce__customers') }}

),

spine as (

    select cast(unnest(generate_series(
        cast(start_date as timestamp),
        cast(end_date as timestamp),
        interval 1 day
    )) as date) as date_day
    from bounds

)

select
    date_day,
    year(date_day)                               as year,
    month(date_day)                              as month,
    cast(date_trunc('month', date_day) as date)  as month_start_date,
    strftime(date_day, '%Y-%m')                  as year_month,
    -- Semana ISO: empieza en lunes.
    cast(date_trunc('week', date_day) as date)   as week_start_date,
    strftime(date_day, '%G-W%V')                 as iso_year_week,
    isodow(date_day)                             as iso_day_of_week,
    isodow(date_day) in (6, 7)                   as is_weekend
from spine
