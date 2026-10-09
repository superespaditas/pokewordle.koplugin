# PokéWordle para KOReader

Adivina el nombre de un Pokémon de la Generación I (151 Pokémon) en 5 intentos. Es un plugin para KOReader pensado para lectores e-ink, como los Kindle, con una interfaz de texto, sin animaciones ni audio.

Es un port en Lua de la versión web de PokéWordle, con la misma lógica de juego.

## Características

- Los 151 Pokémon de la Generación I, sin repetir hasta agotar el pool.
- Pistas por intento con marcas de texto que se leen bien en blanco y negro:
  - `[A]` letra correcta en su lugar
  - `(A)` la letra está en el nombre, pero en otro lugar
  - ` A ` la letra no está en el nombre
- Resumen de letras por estado: en su lugar, en la palabra y descartadas.
- Progreso guardado automáticamente en el dispositivo.
- Estadísticas: partidas jugadas, atrapados, porcentaje de éxito, racha actual, mejor racha, avance de la Pokédex y tiempo de juego.
- Entrenador con nombre y personaje elegido.

## Instalación

1. Descarga la última release del repositorio o clónalo.
2. Copia la carpeta `pokewordle.koplugin` dentro de la carpeta `koreader/plugins/` de tu dispositivo.
3. Reinicia KOReader.
4. Entra en **Tools → PokéWordle**.

El nombre de la carpeta debe terminar en `.koplugin` y contener `_meta.lua` y `main.lua`.

## Uso

1. Crea un entrenador con **Nuevo entrenador** o desde el primer ingreso.
2. Elige **Nueva partida**.
3. Pulsa **Escribir intento**, escribe el nombre en letras A a Z y confirma.
4. Lee las marcas del tablero y ajusta tu siguiente intento.
5. Al terminar, verás el número y el nombre del Pokémon.

Puedes salir al menú en cualquier momento. La partida queda guardada y se retoma con **Continuar partida**.

## Estructura del repositorio

```
pokewordle/
├── README.md
└── pokewordle.koplugin/
    ├── _meta.lua
    └── main.lua
```

## Diferencias con la versión web

- No hay sprites ni silueta del Pokémon. Se revela su número y nombre al final de la partida.
- No hay teclado virtual. Se escribe el intento en un cuadro de texto.
- No hay animaciones ni sonidos.
- Los personajes de entrenador se identifican solo con texto, sin imágenes.

## Limitaciones

- Los nombres de Pokémon son marcas de Nintendo, Game Freak y The Pokémon Company. Este proyecto es un fan project sin relación con ellas.
- La lista de Pokémon es fija (Generación I). No incluye Pokémon posteriores.
- Hay que probarlo en un dispositivo real, porque la versión de KOReader puede afectar la interfaz.

## Créditos

Desarrollo original. Adapta esta sección con tu nombre.

## Licencia

Pendiente. Define una licencia (por ejemplo MIT) antes de publicar.
