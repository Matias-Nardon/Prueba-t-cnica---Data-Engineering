-- Dimensión de productos (catálogo actual).

select
    product_id,
    product_name,
    category,
    unit_price,
    currency,
    created_at,
    updated_at
from {{ ref('stg_ecommerce__products') }}
