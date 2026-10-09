-- PokéWordle para KOReader (e-ink)
-- Port de game.js: misma lógica (scoreGuess, pool sin repetir, racha, pokédex),
-- con interfaz de texto y diálogos. Sin sprites, sin animaciones, sin audio.

local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ButtonDialog = require("ui/widget/buttondialog")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local TextViewer = require("ui/widget/textviewer")
local UIManager = require("ui/uimanager")
local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local _ = require("gettext")

local PokeWordle = WidgetContainer:extend{
    name = "pokewordle",
    is_doc_only = false,
}

local MAX_GUESSES = 5

-- Generación I, en orden de Pokédex (#1 a #151)
local POKEMON = {}
do
    local list = [[
BULBASAUR IVYSAUR VENUSAUR CHARMANDER CHARMELEON CHARIZARD SQUIRTLE WARTORTLE BLASTOISE
CATERPIE METAPOD BUTTERFREE WEEDLE KAKUNA BEEDRILL PIDGEY PIDGEOTTO PIDGEOT RATTATA RATICATE
SPEAROW FEAROW EKANS ARBOK PIKACHU RAICHU SANDSHREW SANDSLASH NIDORANF NIDORINA NIDOQUEEN
NIDORANM NIDORINO NIDOKING CLEFAIRY CLEFABLE VULPIX NINETALES JIGGLYPUFF WIGGLYTUFF ZUBAT
GOLBAT ODDISH GLOOM VILEPLUME PARAS PARASECT VENONAT VENOMOTH DIGLETT DUGTRIO MEOWTH PERSIAN
PSYDUCK GOLDUCK MANKEY PRIMEAPE GROWLITHE ARCANINE POLIWAG POLIWHIRL POLIWRATH ABRA KADABRA
ALAKAZAM MACHOP MACHOKE MACHAMP BELLSPROUT WEEPINBELL VICTREEBEL TENTACOOL TENTACRUEL GEODUDE
GRAVELER GOLEM PONYTA RAPIDASH SLOWPOKE SLOWBRO MAGNEMITE MAGNETON FARFETCHD DODUO DODRIO SEEL
DEWGONG GRIMER MUK SHELLDER CLOYSTER GASTLY HAUNTER GENGAR ONIX DROWZEE HYPNO KRABBY KINGLER
VOLTORB ELECTRODE EXEGGCUTE EXEGGUTOR CUBONE MAROWAK HITMONLEE HITMONCHAN LICKITUNG KOFFING
WEEZING RHYHORN RHYDON CHANSEY TANGELA KANGASKHAN HORSEA SEADRA GOLDEEN SEAKING STARYU STARMIE
MRMIME SCYTHER JYNX ELECTABUZZ MAGMAR PINSIR TAUROS MAGIKARP GYARADOS LAPRAS DITTO EEVEE
VAPOREON JOLTEON FLAREON PORYGON OMANYTE OMASTAR KABUTO KABUTOPS AERODACTYL SNORLAX ARTICUNO
ZAPDOS MOLTRES DRATINI DRAGONAIR DRAGONITE MEWTWO MEW
]]
    for w in list:gmatch("%S+") do
        POKEMON[#POKEMON + 1] = { num = #POKEMON + 1, name = w }
    end
end

local SKINS = {
    { id = "paleta", label = "Entrenador · Pueblo Paleta" },
    { id = "celeste", label = "Entrenadora · Ciudad Celeste" },
}

local KB_PRIORITY = { correct = 3, present = 2, absent = 1 }

---------------------------------------------------------------------------
-- Lógica (equivalente a scoreGuess de game.js)
---------------------------------------------------------------------------

local function scoreGuess(guess, answer)
    local n = #answer
    local res, ans, g = {}, {}, {}
    for i = 1, n do
        res[i] = "absent"
        ans[i] = answer:sub(i, i)
        g[i] = guess:sub(i, i)
    end
    -- 1º: correctas
    for i = 1, n do
        if g[i] == ans[i] then
            res[i] = "correct"
            ans[i] = false
            g[i] = false
        end
    end
    -- 2º: presentes
    for i = 1, n do
        if g[i] then
            for j = 1, n do
                if ans[j] and ans[j] == g[i] then
                    res[i] = "present"
                    ans[j] = false
                    break
                end
            end
        end
    end
    return res
end

local function createGame(stats)
    local available = {}
    for _, p in ipairs(POKEMON) do
        local used = false
        for _, u in ipairs(stats.usedNums) do
            if u == p.num then used = true break end
        end
        if not used then available[#available + 1] = p end
    end
    if #available == 0 then
        stats.usedNums = {}
        available = POKEMON
    end
    local pok = available[math.random(#available)]
    stats.usedNums[#stats.usedNums + 1] = pok.num
    return {
        answer = pok.name,
        answerNum = pok.num,
        wordLen = #pok.name,
        guesses = {},  -- { guess = "...", result = {...} }
        keys = {},     -- letra -> estado (correct / present / absent)
        gameOver = false,
        won = false,
    }
end

local function newStats()
    return {
        played = 0, wonCount = 0, streak = 0, bestStreak = 0,
        caughtNums = {}, usedNums = {}, playSec = 0,
    }
end

local function contains(list, value)
    for _, v in ipairs(list) do if v == value then return true end end
    return false
end

---------------------------------------------------------------------------
-- Texto para e-ink
-- correcto  -> [A]   presente -> (A)   ausente -> " A "
---------------------------------------------------------------------------

local function cellText(letter, status)
    if status == "correct" then return "[" .. letter .. "]" end
    if status == "present" then return "(" .. letter .. ")" end
    return " " .. letter .. " "
end

local function emptyRow(n)
    local t = {}
    for i = 1, n do t[i] = " _ " end
    return table.concat(t, " ")
end

local function keysLine(keys, status)
    local out = {}
    for _, letter in ipairs({ "A","B","C","D","E","F","G","H","I","J","K","L","M",
                              "N","O","P","Q","R","S","T","U","V","W","X","Y","Z" }) do
        if keys[letter] == status then out[#out + 1] = letter end
    end
    return #out > 0 and table.concat(out, " ") or "—"
end

---------------------------------------------------------------------------
-- Ciclo de vida del plugin
---------------------------------------------------------------------------

function PokeWordle:init()
    self.settings = LuaSettings:open(DataStorage:getSettingsDir() .. "/pokewordle.lua")
    local saved = self.settings:readSetting("pw") or {}
    self.trainer = saved.trainer
    self.stats = saved.stats or newStats()
    self.game = saved.game
    self.sessionStart = nil
    math.randomseed(os.time())
    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
end

function PokeWordle:addToMainMenu(menu_items)
    menu_items.pokewordle = {
        text = _("PokéWordle"),
        sorting_hint = "tools",
        sub_item_table = {
            { text = _("Jugar"), callback = function() self:menu() end },
            { text = _("Estadísticas"), callback = function() self:showStats() end },
            { text = _("Tutorial"), callback = function() self:showTutorial() end },
            { text = _("Borrar datos"), callback = function() self:resetAll() end },
        },
    }
end

function PokeWordle:save()
    self.settings:saveSetting("pw", {
        trainer = self.trainer,
        stats = self.stats,
        game = self.game,
    })
    self.settings:flush()
end

function PokeWordle:dlg(title, rows)
    if self.dialog then UIManager:close(self.dialog) end
    local btns = {}
    for _, r in ipairs(rows) do
        btns[#btns + 1] = { { text = r[1], callback = r[2] } }
    end
    self.dialog = ButtonDialog:new{ title = title, buttons = btns }
    UIManager:show(self.dialog)
end

function PokeWordle:msg(text)
    UIManager:show(InfoMessage:new{ text = text })
end

---------------------------------------------------------------------------
-- Menú principal
---------------------------------------------------------------------------

function PokeWordle:menu()
    if not self.trainer then
        return self:newTrainer()
    end
    local rows = {}
    if self.game and not self.game.gameOver then
        rows[#rows + 1] = { "▶ Continuar partida", function() self:play() end }
        rows[#rows + 1] = { "↺ Nueva partida (descarta la actual)", function() self:newGame() end }
    else
        rows[#rows + 1] = { "▶ Nueva partida", function() self:newGame() end }
    end
    rows[#rows + 1] = { "📊 Estadísticas", function() self:showStats() end }
    rows[#rows + 1] = { "📖 Tutorial", function() self:showTutorial() end }
    rows[#rows + 1] = { "👤 Nuevo entrenador", function() self:newTrainer() end }
    rows[#rows + 1] = { "Cerrar", function() UIManager:close(self.dialog) end }
    self:dlg(string.format("POKéWORDLE · Entrenador: %s", self.trainer.name), rows)
end

---------------------------------------------------------------------------
-- Entrenador
---------------------------------------------------------------------------

function PokeWordle:newTrainer()
    self.input = InputDialog:new{
        title = _("¿Cuál es tu nombre, entrenador?"),
        input = "",
        input_hint = _("Máx. 12 letras"),
        buttons = {{
            { text = _("Cancelar"), id = "close", callback = function() UIManager:close(self.input) end },
            { text = _("Siguiente"), is_enter_default = true, callback = function()
                local name = self.input:getInputText() or ""
                name = name:gsub("^%s+", ""):gsub("%s+$", ""):sub(1, 12):upper()
                UIManager:close(self.input)
                if #name < 2 then
                    self:msg(_("El nombre debe tener al menos 2 caracteres."))
                    return
                end
                self:pickSkin(name)
            end },
        }},
    }
    UIManager:show(self.input)
    self.input:onShowKeyboard()
end

function PokeWordle:pickSkin(name)
    local rows = {}
    for _, s in ipairs(SKINS) do
        rows[#rows + 1] = { s.label, function()
            self.trainer = { name = name, skin = s.id }
            self.stats = newStats()
            self.game = nil
            self:save()
            self:newGame()
        end }
    end
    self:dlg("Elegí tu personaje:", rows)
end

function PokeWordle:resetAll()
    self.trainer = nil
    self.stats = newStats()
    self.game = nil
    self:save()
    self:msg(_("Datos borrados."))
end

---------------------------------------------------------------------------
-- Partida
---------------------------------------------------------------------------

function PokeWordle:newGame()
    self.game = createGame(self.stats)
    self:save()
    self:play()
end

function PokeWordle:boardText()
    local g = self.game
    local lines = {}
    lines[#lines + 1] = string.format("Intentos %d/%d · %d letras", #g.guesses, MAX_GUESSES, g.wordLen)
    lines[#lines + 1] = ""
    for r = 1, MAX_GUESSES do
        local prev = g.guesses[r]
        if prev then
            local cells = {}
            for i = 1, g.wordLen do
                cells[i] = cellText(prev.guess:sub(i, i), prev.result[i])
            end
            lines[#lines + 1] = table.concat(cells, " ")
        else
            lines[#lines + 1] = emptyRow(g.wordLen)
        end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "[A] = en su lugar   (A) = está en otro lugar   A = no está"
    lines[#lines + 1] = ""
    lines[#lines + 1] = "En su lugar: " .. keysLine(g.keys, "correct")
    lines[#lines + 1] = "En la palabra: " .. keysLine(g.keys, "present")
    lines[#lines + 1] = "Descartadas: " .. keysLine(g.keys, "absent")
    return table.concat(lines, "\n")
end

function PokeWordle:play()
    if not self.game then return self:newGame() end
    if not self.sessionStart then self.sessionStart = os.time() end
    local g = self.game
    if g.gameOver then
        return self:endScreen()
    end
    self:dlg(self:boardText(), {
        { "✎ Escribir intento", function() self:askGuess() end },
        { "⌂ Volver al menú (la partida queda guardada)", function()
            self:leaveSession()
            self:menu()
          end },
    })
end

function PokeWordle:leaveSession()
    if self.sessionStart then
        self.stats.playSec = (self.stats.playSec or 0) + (os.time() - self.sessionStart)
        self.sessionStart = nil
    end
    self:save()
end

function PokeWordle:askGuess()
    local g = self.game
    self.input = InputDialog:new{
        title = string.format("Intento %d de %d · %d letras (solo A-Z)", #g.guesses + 1, MAX_GUESSES, g.wordLen),
        input = "",
        buttons = {{
            { text = _("Cancelar"), id = "close", callback = function()
                UIManager:close(self.input)
                self:play()
              end },
            { text = _("Enviar"), is_enter_default = true, callback = function()
                local raw = self.input:getInputText() or ""
                UIManager:close(self.input)
                self:submit(raw)
              end },
        }},
    }
    UIManager:show(self.input)
    self.input:onShowKeyboard()
end

function PokeWordle:submit(raw)
    local g = self.game
    local guess = raw:gsub("%s", ""):upper()
    if not guess:match("^%u+$") then
        self:msg(_("Solo letras de la A a la Z."))
        return self:askGuess()
    end
    if #guess ~= g.wordLen then
        self:msg(string.format(_("Necesitás %d letras."), g.wordLen))
        return self:askGuess()
    end

    local result = scoreGuess(guess, g.answer)
    g.guesses[#g.guesses + 1] = { guess = guess, result = result }

    for i = 1, #guess do
        local letter = guess:sub(i, i)
        local status = result[i]
        local cur = g.keys[letter]
        if not cur or KB_PRIORITY[status] > KB_PRIORITY[cur] then
            g.keys[letter] = status
        end
    end

    local won = true
    for _, s in ipairs(result) do
        if s ~= "correct" then won = false break end
    end
    local lost = not won and #g.guesses >= MAX_GUESSES

    if won or lost then
        g.gameOver = true
        g.won = won
        self.stats.played = self.stats.played + 1
        if won then
            self.stats.wonCount = self.stats.wonCount + 1
            self.stats.streak = self.stats.streak + 1
            if self.stats.streak > self.stats.bestStreak then
                self.stats.bestStreak = self.stats.streak
            end
            if not contains(self.stats.caughtNums, g.answerNum) then
                self.stats.caughtNums[#self.stats.caughtNums + 1] = g.answerNum
            end
        else
            self.stats.streak = 0
        end
        self:save()
        return self:endScreen()
    end

    self:save()
    self:play()
end

function PokeWordle:endScreen()
    local g = self.game
    local pok = POKEMON[g.answerNum]
    local pct = self.stats.played > 0 and math.floor(self.stats.wonCount * 100 / self.stats.played + 0.5) or 0
    local title = string.format(
        "%s\n\n#%03d  %s\n\nJugados %d · Atrapados %d · Éxito %d%%",
        g.won and "¡ATRAPADO!" or "SE ESCAPÓ",
        pok.num, pok.name,
        self.stats.played, self.stats.wonCount, pct
    )
    self:dlg(title, {
        { "▶ Siguiente Pokémon", function() self:newGame() end },
        { "⌂ Volver al menú", function() self:menu() end },
    })
end

---------------------------------------------------------------------------
-- Estadísticas y tutorial
---------------------------------------------------------------------------

function PokeWordle:showStats()
    if not self.trainer then
        return self:msg(_("Creá un entrenador primero."))
    end
    local s = self.stats
    local pct = s.played > 0 and math.floor(s.wonCount * 100 / s.played + 0.5) or 0
    local caught = #s.caughtNums
    local secs = (s.playSec or 0)
    if self.sessionStart then secs = secs + (os.time() - self.sessionStart) end
    local text = table.concat({
        "ESTADÍSTICAS · " .. self.trainer.name,
        "",
        "Partidas jugadas: " .. s.played,
        "Atrapados: " .. s.wonCount,
        "Escapados: " .. (s.played - s.wonCount),
        "% de éxito: " .. pct .. "%",
        "Racha actual: " .. s.streak,
        "Mejor racha: " .. s.bestStreak,
        "",
        string.format("Pokédex: %d / 151 (%d%%)", caught, math.floor(caught * 100 / 151 + 0.5)),
        "Pokémon restantes: " .. (151 - caught),
        "",
        string.format("Tiempo de juego: %dh %dm", math.floor(secs / 3600), math.floor((secs % 3600) / 60)),
    }, "\n")
    UIManager:show(TextViewer:new{ title = _("PokéWordle"), text = text })
end

function PokeWordle:showTutorial()
    local text = table.concat({
        "CÓMO JUGAR",
        "",
        "Adivinás el nombre de un Pokémon de la Generación I (151 Pokémon).",
        "Tenés " .. MAX_GUESSES .. " intentos. Cada intento debe tener el mismo largo que la palabra.",
        "",
        "Marcas en el tablero:",
        "  [A]  letra correcta en el lugar correcto",
        "  (A)  la letra está en el nombre, pero en otro lugar",
        "   A   la letra no está en el nombre",
        "",
        "Escribí el intento con \"Escribir intento\". Solo se aceptan letras A a Z.",
        "",
        "Al terminar la partida ves el número y nombre del Pokémon.",
        "Tu progreso se guarda automáticamente en el dispositivo.",
    }, "\n")
    UIManager:show(TextViewer:new{ title = _("Tutorial"), text = text })
end

return PokeWordle

