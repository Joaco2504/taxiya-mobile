---
name: textos-app-es-ar
description: Cómo escribir los textos de una página web y de una app Android en español rioplatense con tono de Catamarca, evitando los rasgos de escritura de IA que cataloga Wikipedia en "Signs of AI writing". Usar siempre que haya que redactar o revisar texto visible para el usuario final (botones, menús, pantallas vacías, errores, notificaciones, onboarding, títulos, descripciones, meta tags, alt, strings.xml, copy de landing, FAQ, mensajes de formulario), aunque el pedido sea solo "armá la pantalla" o "hacé la web" y no mencione los textos.
---

# Textos para web y app Android, en argentino de Catamarca y sin marcas de IA

Esta skill es para la IA que construye la página web y la app Android. Cubre una sola cosa: cómo se escribe cada texto que ve la persona que usa el producto. El código, el diseño y la arquitectura quedan fuera.

## De dónde sale esto

Wikipedia mantiene una guía de campo, "Wikipedia:Signs of AI writing" (WikiProject AI Cleanup), con los patrones que más se repiten en texto generado por modelos de lenguaje. La guía dice de sí misma que es descriptiva y que no es una política. También avisa dos cosas que esta skill toma como regla de trabajo:

1. Los patrones son señales de un problema, no el problema. El problema real es el texto genérico, inflado y sin datos propios. Si solo se borran las muletillas y queda el mismo vacío, el texto sigue mal y además es más difícil de detectar.
2. Parte de la guía habla de convenciones de Wikipedia (citas, tono enciclopédico) que no aplican a una app. Acá se usa lo que sirve para textos de producto, y se agrega lo propio de interfaces.
3. La guía lista indicadores que no sirven para detectar IA y que, por lo tanto, no hay que "corregir": gramática perfecta, registro formal o mezcla de registros, palabras de transición sueltas, texto con fuentes. Escribir bien no es un defecto, y meter errores de ortografía a propósito no vuelve humano a un texto. Lo que lo vuelve humano es que diga algo específico.

Esta versión se cotejó con una copia en PDF de la página, de octubre de 2026 (oldid 1385986997). La guía cambia seguido y los modelos nuevos no repiten los rasgos de 2023. El detalle por época está en `references/rasgos-wikipedia.md`.

Hay dos reglas de oficio que se suman a lo anterior: el texto de una interfaz tiene que ser corto, y tiene que sonar a la gente del lugar, no a un folleto traducido.

## Proceso

1. Antes de escribir, juntá los datos reales: nombre del negocio, qué vende o qué hace la app, precios, horarios, zona, medios de pago, qué pasa cuando algo falla. Si el pedido no los trae, preguntá o dejá un marcador visible (`TODO_DATO: horario de atención`). No los inventes. Un horario falso en un botón es peor que un texto genérico.
2. Escribí cada texto pensando en una pantalla concreta y en una acción concreta de la persona.
3. Pasá la lista de control del final antes de entregar.
4. Si algo no sabés (un dato del negocio, cómo dicen una palabra en el pueblo), decilo una vez en la respuesta y seguí. No rellenes.

## Registro: español de Argentina, tono catamarqueño

### Base

- Voseo siempre: vos, tenés, querés, elegí, ingresá, mirá, fijate. Nunca "tú", "tienes", "ingresa tu contraseña" en tuteo.
- Tratamiento de usted solo si el negocio lo pide (un estudio contable, una obra social). En ese caso se mantiene en toda la app, sin mezclar.
- Frases cortas, verbos concretos, orden natural. Se escribe como se le explicaría algo a un cliente en el mostrador.
- Ortografía completa, con tildes y signos de apertura. Sin abreviaturas de chat ("q", "xq", "tb") en ningún texto de interfaz.
- `lang="es-AR"` en la web y recursos en `values-es-rAR` en Android, con `values-es` como respaldo.

### Formatos argentinos

- Dinero: `$ 12.500,50`. Punto para miles, coma para decimales, símbolo antes del número.
- Fechas: `16/11/2026` o "16 de noviembre". Nunca mes primero.
- Hora: 24 horas, "18:30" o "18:30 hs".
- Teléfono: `+54 9` más característica y número, y sin el 0 ni el 15.
- Provincia y localidades con su nombre real: Catamarca, San Fernando del Valle de Catamarca (la gente dice "la Capital"), Valle Viejo, Belén, Hualfín, Tinogasta, Fiambalá, Andalgalá, Santa María.

### Regionalismos

Sobre el habla de Catamarca no tengo una fuente que pueda citar, y la guía de Wikipedia agrega que los modelos saben menos de las variedades poco habladas y alucinan más en ellas. Lo que sigue es criterio general del noroeste argentino y conviene que lo confirmen dos o tres personas del lugar antes de publicar.

- Usá poco. Uno o dos giros locales por pantalla alcanzan, y solo donde el contexto es relajado: bienvenida, pantallas vacías, mensajes de éxito, promociones.
- No los uses en pagos, datos personales, errores graves, salud, legales ni confirmaciones de borrado. Ahí va español rioplatense neutro, claro y sin color local.
- Palabras que suenan naturales en el noroeste y que se pueden usar con moderación: "chango" y "changa" para chico o chica, "yapa" para el extra que se regala, "ahora mismo", "ya mismo", "mirá", "fijate". "Che" se usa menos en el norte que en Buenos Aires; no lo pongas de relleno.
- Referencias del lugar solo si tienen relación con lo que hace la app: el poncho, el dulce de alcayota, las nueces, el comino y el pimentón de Tinogasta, la empanada catamarqueña, la aloja, el vino de altura. Una referencia por producto, no una por pantalla.
- Prohibido el acento caricaturesco: nada de ortografía fonética ("pa'", "ma'", "vo'"), nada de modismos de otras provincias (el "boludo" porteño, el "che pibe") y nada de lunfardo.
- Si el texto suena a publicidad provincial de un ministerio de turismo, está mal.

## Rasgos de escritura de IA y qué hacer en cada caso

Cada punto sigue la estructura de la guía de Wikipedia, adaptada a texto de producto.

### Contenido

Importancia inflada. La IA agrega frases que dicen que algo es "fundamental", "clave", un "referente", un "legado". En una app eso aparece como "Una experiencia única que transforma la forma de comprar". Escribí qué hace la cosa, para quién y cuánto cuesta. Si el dato no alcanza para llenar la frase, la frase sobra.

Lenguaje promocional. "Descubrí", "increíble", "ideal para vos", "joya", "inigualable", "en el corazón de". Se reemplaza por hechos: "Pedís hasta las 11 y te llega a la tarde".

Análisis de relleno con gerundios. "Ofreciendo soluciones y reflejando nuestro compromiso con la calidad". Se corta la segunda mitad. Si queda una sola idea, se escribe en una oración corta.

Atribución vaga. "Los clientes dicen", "según los expertos", "muchos usuarios". Se pone nombre, cifra o fuente, o se saca. Los testimonios que aparezcan en la web son de personas reales con permiso, nunca generados.

Cierres sobre desafíos y futuro. "Seguimos trabajando para el futuro". No va en ningún texto de producto. Una pantalla de "Acerca de" cuenta qué es la app, quién la hace y cómo contactarlos. Lo mismo vale para secciones rígidas como "Desafíos y perspectivas", "Premios y reconocimientos" o cualquier encabezado con formato "X y Y", que la guía marca como muy típicos.

Avisos de que falta información. "Los detalles son escasos", "según la información disponible", "no hay datos públicos", "debe tomarse como X y no como Y", "no debe confundirse con". Según la guía, esos "encuadres correctivos" son típicos de modelos de mediados de 2026 y lo que dicen suele ser especulación. En una app no existen: si falta un dato, va `TODO_DATO` en el código y se avisa en la respuesta, nunca un aviso de relleno en pantalla.

Conexión vaga. "Asociado con", "vinculado a", "en relación con" en lugar de decir cuál es la relación. Escribí "Juan es el dueño" o "Ana atiende los martes".

Influencia inflada. "Ha generado debate sobre", "ha moldeado conversaciones". Sin uso en un producto.

Presencia online y cobertura. "Mantiene una fuerte presencia en redes", "destacado en medios regionales", "su sitio lo identifica como". En "Acerca de" no se cuenta que el negocio sale en medios ni que "los registros lo identifican como". Si salió en una nota, va el nombre real del medio, la fecha y el enlace.

Texto genérico donde falta información. Es el problema de fondo. Un párrafo que serviría igual para una ferretería y para una veterinaria no sirve para ninguna. Cada texto debe tener al menos un dato que solo pueda ser de este negocio.

### Lenguaje y gramática

Vocabulario de IA. La guía documenta que ciertas palabras aparecen muy por encima de lo normal y que suelen venir juntas: con una o dos puede ser casualidad, con muchas es de las señales más fuertes. La lista original es en inglés; estos son los equivalentes en español (la traducción es mía, no figura en la guía): crucial, fundamental, clave, pivotal, vital, panorama, ecosistema, tapiz, testimonio de, destacar, subrayar, resaltar, fomentar, potenciar, sumergirse, adentrarse, intrincado, meticuloso, robusto, vibrante, valioso, duradero, "Además," al empezar una oración, experiencia única, soluciones integrales, de la mano de, en el mundo de hoy. Según la guía, los modelos de mediados de 2026 en adelante cambiaron de palabras: desafío, claro, confiable, multifacético, práctico, priorizar, aprovechar (leverage), importa, silenciosamente, constante, universalmente. Una palabra marcada no implica que sus sinónimos también lo estén, y hay que mirar el contexto. Si una palabra podría ir en cualquier sitio web de cualquier rubro, cambiala por una específica.

Evitar el verbo simple. La guía registra que los modelos esquivan "es" y "tiene" y escriben "sirve como", "se erige como", "representa", "marca", "ofrece", "cuenta con", "presenta", y que abren definiciones con "refiere a" como si el tema fuera la palabra. Escribí "es", "tiene", "hay", "usó", "intentó".

Paralelismos negativos. Prohibido "no solo X sino también Y" y "no es X, es Y", incluidas las series de negaciones ("sin filas, sin esperas, sin vueltas"). Afirmá directamente lo que es. La guía suma dos variantes: "no hay X, no hay Y, solo Z" y la invertida "Y en lugar de X", que describe como frecuente en modelos recientes.

Tríadas automáticas. Tres adjetivos o tres beneficios por reflejo ("rápido, simple y seguro"). Poné los que sean ciertos y verificables, aunque sean uno o dos, y a veces cuatro.

Sinónimos rotados. Si la app se llama Mi Turno, se llama Mi Turno en toda la app, no "la plataforma", "la herramienta", "la solución". Un botón que dice "Pedido" no se llama "Orden" tres pantallas después.

Falsos rangos. "Desde pañales hasta productos de limpieza" cuando no hay escala real entre los extremos. Listá lo que hay.

Pasiva y oraciones impersonales apiladas ("Se procederá a realizar la validación"). Usá sujeto: "Revisamos tus datos".

### Estilo y formato

- Títulos en minúscula tipo oración: "Tus pedidos", no "Tus Pedidos" ni "TUS PEDIDOS" salvo que el diseño lo imponga por CSS.
- Sin emojis en títulos, botones, listas ni mensajes del sistema. Si el negocio los usa en su WhatsApp y los quiere en la app, uno por mensaje como máximo y nunca como viñeta.
- Sin negritas decorativas. La negrita es para el dato que la persona busca con la vista (un precio, un horario), no para frases de marketing.
- Sin listas con encabezado en negrita seguido de dos puntos y una frase ("**Rapidez:** ..."). Si hay beneficios, van en oraciones o en una lista de cosas concretas.
- Pocas rayas largas. Se usa coma, punto o paréntesis. En interfaz casi nunca hace falta.
- Largo de frase variado. Según la guía, los modelos nuevos evitan las rayas y llenan el texto de comas y puntos, con oraciones parejas de 8 a 20 palabras, y eso ya es otra señal. En una interfaz conviven la frase de dos palabras ("Pedido enviado") y alguna de veinte.
- Cierres de resumen ("En resumen", "En conclusión", "En definitiva") al final de un bloque: se sacan.
- Pantallas de perfil con "¡Bienvenido!", "Sobre mí", "Conectemos": se reemplazan por los datos de la persona.
- Comillas rectas o angulares «así» de manera consistente. No mezclar rectas y curvas en el mismo producto.
- Sin signos de exclamación en cadena. Una exclamación en un mensaje de éxito está bien, en todos los mensajes no.

### Comunicación (restos de chatbot)

- Nada de "¡Claro!", "Por supuesto", "Espero que te sirva", "Como modelo de lenguaje", "¿Querés que...?" dentro de la app. Si la app tiene un asistente conversacional, sus respuestas siguen estas mismas reglas.
- Nada de avisos de fecha de corte ni de que "la información puede no estar actualizada" salvo que sea un dato real del producto.
- Tampoco "Aquí tenés", "avisame si necesitás algo más" ni "verificá esto antes de publicar". Nada de texto de relleno tipo "Lorem ipsum" ni de marcas de plantilla (`[Nombre del negocio]`) que lleguen a producción. Revisá el archivo final con una búsqueda de corchetes, `TODO`, `lorem` y `{{`.

### Restos técnicos de la herramienta

La guía los cuenta entre los indicadores más claros. Antes de entregar, buscá en los archivos de la web y en `strings.xml`:

- Markdown filtrado: asteriscos dobles, numerales al comienzo de línea, `---`, triples acentos graves, enlaces `[texto](url)` dentro de HTML o de strings.
- Fugas de la herramienta de búsqueda: `contentReference`, `oaicite`, el símbolo ↩, notas `[1]` sin destino.
- Parámetros de rastreo en los enlaces: `utm_source=openai`, `utm_source=chatgpt.com`, `utm_source=copilot.com`, `referrer=grok.com`. Se borran de todas las URL.
- Marcadores sin completar: `[Nombre]`, `(Agregá la URL acá)`, `(si corresponde)`, `example.com`, fechas tipo `2026-xx-xx`, `INSERT_URL_HERE`.
- Enlaces externos rotos o inventados: cada URL externa se prueba, y si no abre no va.
- Comentarios dirigidos a quien pidió el trabajo ("reemplazá esto antes de publicar") dentro del HTML visible o de los textos.

## Textos de interfaz por tipo

Botones. Verbo en voseo y objeto: "Pedir turno", "Guardar cambios", "Ver mi carrito". Entre una y tres palabras. Nada de "Haz clic aquí" ni "Continuar" cuando se puede decir qué viene después.

Errores. Tres datos: qué pasó, por qué si se sabe, y qué puede hacer la persona. "No pudimos guardar el pedido porque no hay internet. Probá de nuevo cuando vuelva la señal." Sin "¡Ups!", sin "Algo salió mal" a secas, sin culpar al usuario ("Ingresaste mal").

Pantalla vacía. Qué falta y cómo se llena. "Todavía no cargaste ningún cliente. Tocá Agregar cliente para empezar."

Confirmaciones. Decir qué se hizo. "Pedido enviado. Te avisamos cuando esté listo." Para acciones destructivas, nombrar lo que se pierde: "Vas a borrar 14 pedidos. No se pueden recuperar."

Formularios. La etiqueta dice qué dato va ("Teléfono"), el texto de ayuda dice el formato ("Con característica, sin 0 ni 15"). El placeholder no reemplaza a la etiqueta.

Onboarding. Máximo tres pantallas y cada una explica una acción real de la app, con una captura o un ejemplo. Si una pantalla no enseña nada concreto, se saca.

Notificaciones. Título de hasta unos 40 caracteres, cuerpo con el dato útil primero: "Tu pedido #231 salió. Llega entre las 16 y las 18 hs."

Menús y navegación. Sustantivos cortos y estables: Inicio, Pedidos, Clientes, Ajustes. Mismo nombre en la web y en la app.

Landing y página de inicio. Primero qué es y para quién, con el nombre del negocio y la localidad en las primeras líneas. Después precios o forma de contacto. Sin frase de "misión y visión" salvo que el dueño la tenga escrita por su cuenta.

FAQ. Las preguntas salen de consultas reales del negocio, escritas como las diría el cliente ("¿Hacen envíos a Hualfín?"). Si no hay consultas reales, se dejan marcadores.

Meta y accesibilidad. `<title>` con nombre y rubro y localidad, `meta description` de una oración con un dato concreto, `alt` que describe lo que se ve ("Estantería con bidones de lavandina de 5 litros"), `contentDescription` en Android con acción y objeto.

## Notas técnicas para Android

- Todo texto visible va en `strings.xml` (`res/values-es-rAR/strings.xml`). Ninguno escrito a mano en el layout ni en el código.
- Nombres de clave descriptivos: `pedido_enviado_ok`, `error_sin_conexion`. No `string_1`.
- Variables con placeholders posicionales: `%1$s`, `%2$d`. No se arman frases concatenando.
- Cantidades con `<plurals>`: "1 pedido", "3 pedidos".
- Los apóstrofes se escapan (`\'`) y las comillas dobles dentro del texto también.
- Botones y pestañas deben entrar en pantallas chicas sin cortarse. Si un texto no entra, se acorta, no se reduce la fuente.
- Los mismos textos de la web y de la app que digan lo mismo se escriben igual.

## Lista de control antes de entregar

1. Cada texto tiene al menos un dato concreto del negocio o una instrucción concreta.
2. No quedan datos inventados ni marcadores sin resolver, y los pendientes están listados en la respuesta.
3. Voseo en todos lados, formatos argentinos de dinero, fecha y hora.
4. Ninguna palabra de la lista de vocabulario de IA.
5. Ningún "no solo... sino también", "no es X, es Y", serie de negaciones ni tríada por reflejo.
6. Un solo nombre para cada cosa en toda la app.
7. Sin emojis, sin negritas decorativas, sin listas con encabezado en negrita, títulos en minúscula tipo oración.
8. Regionalismos: uno o dos por pantalla como máximo, ninguno en pagos, errores graves o datos sensibles.
9. Los errores dicen qué pasó y qué hacer.
10. Sin restos de Markdown, marcadores, parámetros `utm_` ni enlaces que no abren.
11. Frases de largo variado, sin ritmo parejo.
12. Leído en voz alta, suena a alguien de la zona hablando con un cliente. Si suena a folleto, se reescribe.

Más ejemplos de antes y después, con cada rasgo corregido, en `references/ejemplos-antes-despues.md`. Leelo cuando tengas dudas sobre cómo reescribir un texto concreto.