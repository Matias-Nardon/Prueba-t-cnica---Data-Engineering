{#
    Test genérico: falla si alguna fila tiene la columna a cero, negativa o nula.
    Evita depender de paquetes externos (dbt_utils) para un caso tan simple.
#}
{% test is_positive(model, column_name) %}

select {{ column_name }}
from {{ model }}
where {{ column_name }} is null
   or {{ column_name }} <= 0

{% endtest %}
