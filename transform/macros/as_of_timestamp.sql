{#
    Fecha de referencia de las métricas (ver var as_of_date en dbt_project.yml).
    Por defecto, el corte de los datos: la última extracción de clientes.
#}
{% macro as_of_timestamp() -%}
    {%- if var('as_of_date') -%}
        cast('{{ var("as_of_date") }}' as timestamp)
    {%- else -%}
        (select max(_extracted_at) from {{ ref('stg_ecommerce__customers') }})
    {%- endif -%}
{%- endmacro %}
