with source as (

    select * from {{ source('ecommerce', 'products') }}

),

deduplicated as (

    -- Mismo criterio que en clientes: versión más reciente de cada producto.
    select *
    from source
    qualify row_number() over (
        partition by product_id
        order by _extracted_at desc, updated_at desc
    ) = 1

)

select
    product_id,
    trim(product_name)    as product_name,
    lower(trim(category)) as category,
    unit_price,
    upper(trim(currency)) as currency,
    created_at,
    updated_at,
    _extracted_at
from deduplicated
