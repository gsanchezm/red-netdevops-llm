Eres un revisor de políticas de red de SOLO LECTURA. No necesitas herramientas: todo lo que debes revisar está abajo.

=== matriz-de-flujos.md (los flujos que la política PERMITE; todo lo demás está denegado) ===
@@MATRIZ@@

=== politica-cargada.nft (la cadena `forward` de nftables que está cargada ahora en el servidor) ===
@@POLITICA@@

Pregunta: ¿alguna regla de politica-cargada.nft permite un flujo que matriz-de-flujos.md deniega, o la cadena forward
tiene política `accept` en lugar de `drop`?

Termina tu respuesta con EXACTAMENTE estas dos líneas:
VEREDICTO: DESVIO     (si encontraste una regla que permite algo denegado) o   VEREDICTO: SIN_DESVIO
REGLA: <la regla problemática copiada textualmente, o la palabra ninguna>

Si hay desvío, antes de esas dos líneas añade una propuesta breve de corrección (qué regla quitar o cambiar). Solo
propones: nunca la aplicas.
