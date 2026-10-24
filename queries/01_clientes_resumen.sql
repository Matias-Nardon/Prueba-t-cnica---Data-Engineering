-- Pregunta: ¿cuántos clientes tenemos y cuántos están activos?
-- Cliente: registrado en la plataforma a la fecha de referencia.
-- Activo: al menos una orden no cancelada en los últimos 30 días
-- (variable active_customer_window_days).

select
    any_value(as_of_at)                                       as fecha_referencia,
    count(*) filter (where is_registered)                     as clientes_registrados,
    count(*) filter (where is_registered and has_ordered)     as clientes_con_compra,
    count(*) filter (where is_registered and is_active)       as clientes_activos,
    round(
        100.0 * count(*) filter (where is_registered and is_active)
        / count(*) filter (where is_registered),
        1
    )                                                         as pct_activos
from marts.dim_customers
