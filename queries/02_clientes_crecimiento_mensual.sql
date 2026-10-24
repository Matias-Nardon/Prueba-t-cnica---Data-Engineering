-- Pregunta: ¿cómo crece la base de clientes mes a mes?
-- Se mide por altas en la plataforma (signup_month). No se usa el mes de la
-- primera compra porque el histórico de órdenes empieza en enero de 2026 y
-- daría un pico artificial ese mes.
-- El calendario (dim_date) garantiza que un mes sin altas aparezca con 0.
-- Solo meses completos: el mes de la fecha de referencia (julio de 2026, con
-- 3 horas de datos) mostraría un crecimiento del 0 % que no es real.

with months as (

    select distinct month_start_date
    from marts.dim_date
    where last_day(month_start_date)
        < (select cast(max(as_of_at) as date) from marts.dim_customers)

),

signups as (

    select signup_month, count(*) as altas
    from marts.dim_customers
    where is_registered
    group by signup_month

),

monthly as (

    select
        months.month_start_date,
        coalesce(signups.altas, 0) as altas
    from months
    left join signups
        on months.month_start_date = signups.signup_month

)

select
    strftime(month_start_date, '%Y-%m')                             as mes,
    altas,
    cast(sum(altas) over (order by month_start_date) as bigint)     as clientes_acumulados,
    -- Altas del mes sobre la base acumulada al cierre del mes anterior.
    round(
        100.0 * altas
        / nullif(sum(altas) over (order by month_start_date) - altas, 0),
        1
    )                                                               as pct_crecimiento_base
from monthly
order by month_start_date
