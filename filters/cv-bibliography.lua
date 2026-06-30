-- Quarto shortcode: {{< cv-bibliography CATEGORY >}}
--
-- Parses bibliography/*.bib directly (no biblatex/biber): converts each file
-- to CSL-JSON via `quarto pandoc -f bibtex -t csljson` (Quarto's bundled
-- pandoc can read bibtex without any LaTeX bibliography backend), decodes
-- the JSON with a small self-contained parser (Quarto's bundled JSON
-- decoder chokes on these files), then filters/sorts/formats entries the
-- same way templates/cv.tex used to with `\printbibliography[type=...,
-- keyword=...]`.

-- ---------------------------------------------------------------------
-- minimal JSON decoder (quarto.json.decode fails on some real-world CSL
-- JSON from these bib files, so we parse it ourselves)
-- ---------------------------------------------------------------------
local function jsonSkipWS(s, i)
  while i <= #s do
    local c = s:sub(i, i)
    if c == " " or c == "\t" or c == "\n" or c == "\r" then i = i + 1 else break end
  end
  return i
end

local jsonParseValue

local function jsonParseString(s, i)
  i = i + 1
  local buf = {}
  while true do
    local c = s:sub(i, i)
    if c == "" then error("json: unterminated string") end
    if c == '"' then
      i = i + 1
      break
    elseif c == "\\" then
      local nc = s:sub(i + 1, i + 1)
      if nc == '"' then table.insert(buf, '"'); i = i + 2
      elseif nc == "\\" then table.insert(buf, "\\"); i = i + 2
      elseif nc == "/" then table.insert(buf, "/"); i = i + 2
      elseif nc == "b" then table.insert(buf, "\b"); i = i + 2
      elseif nc == "f" then table.insert(buf, "\f"); i = i + 2
      elseif nc == "n" then table.insert(buf, "\n"); i = i + 2
      elseif nc == "r" then table.insert(buf, "\r"); i = i + 2
      elseif nc == "t" then table.insert(buf, "\t"); i = i + 2
      elseif nc == "u" then
        local cp = tonumber(s:sub(i + 2, i + 5), 16)
        i = i + 6
        if cp >= 0xD800 and cp <= 0xDBFF and s:sub(i, i + 1) == "\\u" then
          local cp2 = tonumber(s:sub(i + 2, i + 5), 16)
          if cp2 and cp2 >= 0xDC00 and cp2 <= 0xDFFF then
            cp = 0x10000 + (cp - 0xD800) * 0x400 + (cp2 - 0xDC00)
            i = i + 6
          end
        end
        table.insert(buf, utf8.char(cp))
      else
        table.insert(buf, nc); i = i + 2
      end
    else
      table.insert(buf, c)
      i = i + 1
    end
  end
  return table.concat(buf), i
end

local function jsonParseNumber(s, i)
  local j = i
  while j <= #s and s:sub(j, j):match("[%d%+%-%.eE]") do j = j + 1 end
  return tonumber(s:sub(i, j - 1)), j
end

local function jsonParseArray(s, i)
  i = jsonSkipWS(s, i + 1)
  local arr = {}
  if s:sub(i, i) == "]" then return arr, i + 1 end
  while true do
    local v
    v, i = jsonParseValue(s, i)
    table.insert(arr, v)
    i = jsonSkipWS(s, i)
    local c = s:sub(i, i)
    if c == "," then i = jsonSkipWS(s, i + 1)
    elseif c == "]" then return arr, i + 1
    else error("json: expected , or ] at " .. i) end
  end
end

local function jsonParseObject(s, i)
  i = jsonSkipWS(s, i + 1)
  local obj = {}
  if s:sub(i, i) == "}" then return obj, i + 1 end
  while true do
    i = jsonSkipWS(s, i)
    if s:sub(i, i) ~= '"' then error("json: expected string key at " .. i) end
    local key
    key, i = jsonParseString(s, i)
    i = jsonSkipWS(s, i)
    if s:sub(i, i) ~= ":" then error("json: expected : at " .. i) end
    i = jsonSkipWS(s, i + 1)
    local v
    v, i = jsonParseValue(s, i)
    obj[key] = v
    i = jsonSkipWS(s, i)
    local c = s:sub(i, i)
    if c == "," then i = jsonSkipWS(s, i + 1)
    elseif c == "}" then return obj, i + 1
    else error("json: expected , or } at " .. i) end
  end
end

jsonParseValue = function(s, i)
  i = jsonSkipWS(s, i)
  local c = s:sub(i, i)
  if c == '"' then return jsonParseString(s, i)
  elseif c == "{" then return jsonParseObject(s, i)
  elseif c == "[" then return jsonParseArray(s, i)
  elseif c == "t" then return true, i + 4
  elseif c == "f" then return false, i + 5
  elseif c == "n" then return nil, i + 4
  else return jsonParseNumber(s, i)
  end
end

local function jsonDecode(s)
  local v = jsonParseValue(s, 1)
  return v
end

-- ---------------------------------------------------------------------
-- Pandoc Inlines helpers
-- ---------------------------------------------------------------------
local function L(text)
  return pandoc.Inlines({pandoc.Str(text)})
end

local function one(el)
  return pandoc.Inlines({el})
end

local function cat(...)
  local out = pandoc.Inlines({})
  for _, part in ipairs({...}) do
    out:extend(part)
  end
  return out
end

-- parse a raw bib-derived string (title, author name, note, ...) as a
-- markdown inline fragment so `$math$`, accents, etc. come through right
local function md(text)
  if text == nil or text == "" then return pandoc.Inlines({}) end
  local doc = pandoc.read(tostring(text), "markdown")
  if #doc.blocks == 0 then return pandoc.Inlines({}) end
  local b = doc.blocks[1]
  if b.t == "Para" or b.t == "Plain" then return b.content end
  return pandoc.utils.blocks_to_inlines(doc.blocks)
end

-- pandoc's bibtex->csljson conversion renders a `note` field's `\emph{}`
-- as literal `<i>...</i>`; turn that into markdown emphasis first
local function cleanNote(text)
  text = text:gsub("</?i>", "*"):gsub("</?em>", "*"):gsub("</?b>", "**")
  return text
end

local function bulletList(items)
  local blocks = {}
  for _, inl in ipairs(items) do
    table.insert(blocks, {pandoc.Plain(inl)})
  end
  return pandoc.BulletList(blocks)
end

-- Numbered citation lists count down from the list length to 1 (items are
-- already sorted most-recent-first) with a bracketed, CornellRed number.
--
-- HTML: the number is a styled inline span (see .cv-num in styles.css);
-- the browser wraps continuation lines back to the <li>'s own left edge,
-- which already lines up under the citation text.
--
-- LaTeX: a Span's `style="color:..."` isn't honored by pandoc's LaTeX
-- writer, and (more importantly) a number prefixed as plain inline text
-- doesn't give enumitem anything to hang-indent against, so wrapped lines
-- don't reliably align under the first line's text. Building a real
-- itemize with `\item[label]` instead lets enumitem's own alignment
-- machinery line up every wrapped line under a fixed-width label column.
local function texInlines(inl)
  return pandoc.write(pandoc.Pandoc({pandoc.Plain(inl)}), "latex")
end

local function numberedListLatex(items)
  local n = #items
  local lines = {"\\begin{itemize}[leftmargin=1.3em, labelsep=0.3em, itemindent=0pt]"}
  for i, it in ipairs(items) do
    local label = "\\textcolor{CornellRed}{[" .. tostring(n - i + 1) .. "]}"
    table.insert(lines, "\\item[" .. label .. "] " .. texInlines(it))
  end
  table.insert(lines, "\\end{itemize}")
  return pandoc.RawBlock("latex", table.concat(lines, "\n"))
end

local function numberedListHtml(items)
  local n = #items
  local out = {}
  for i, it in ipairs(items) do
    local label = one(pandoc.Span(L("[" .. tostring(n - i + 1) .. "]"), pandoc.Attr("", {"cv-num"})))
    table.insert(out, cat(label, L(" "), it))
  end
  return bulletList(out)
end

local function numberedList(items)
  if quarto.doc.is_format("latex") then
    return numberedListLatex(items)
  end
  return numberedListHtml(items)
end

-- ---------------------------------------------------------------------
-- bib loading + entry helpers
-- ---------------------------------------------------------------------
local cache = {}

local function loadBib(path)
  if cache[path] then return cache[path] end
  local jsonText = pandoc.pipe("quarto", {"pandoc", "-f", "bibtex", "-t", "csljson", path}, "")
  local data = jsonDecode(jsonText)
  cache[path] = data
  return data
end

local function entryYear(e)
  if e.issued and e.issued["date-parts"] and e.issued["date-parts"][1] then
    return e.issued["date-parts"][1][1] or 0
  end
  return 0
end

local function initials(given)
  if not given or given == "" then return "" end
  local out = {}
  for word in given:gmatch("%S+") do
    table.insert(out, word:sub(1, 1):upper() .. ".")
  end
  return table.concat(out, " ")
end

local function authorName(a)
  if a.literal then return a.literal end
  local fam = a.family or ""
  local giv = initials(a.given or a.suffix)
  if giv ~= "" then return fam .. ", " .. giv end
  return fam
end

local function isCvOwner(a)
  return a.family == "Srikrishnan" and a.given and a.given:match("^Vivek")
end

local function formatAuthors(authors)
  if not authors or #authors == 0 then return pandoc.Inlines({}) end
  local parts = {}
  local n = #authors
  for idx, a in ipairs(authors) do
    local nameInl = md(authorName(a))
    local inl = isCvOwner(a) and one(pandoc.Strong(nameInl)) or nameInl
    if idx == 1 then
      table.insert(parts, inl)
    elseif idx == n then
      table.insert(parts, L(n == 2 and " and " or ", and "))
      table.insert(parts, inl)
    else
      table.insert(parts, L(", "))
      table.insert(parts, inl)
    end
  end
  return cat(table.unpack(parts))
end

local function formatEntry(e, kind)
  local pieces = {}
  table.insert(pieces, formatAuthors(e.author))
  table.insert(pieces, L(" " .. tostring(entryYear(e)) .. ". "))
  table.insert(pieces, one(pandoc.Quoted("DoubleQuote", cat(md(e.title or ""), L(".")))))

  if kind == "article" then
    if e["container-title"] then
      table.insert(pieces, L(" "))
      table.insert(pieces, one(pandoc.Emph(md(e["container-title"]))))
    end
    if e.volume then
      table.insert(pieces, L(" "))
      table.insert(pieces, one(pandoc.Strong(L(tostring(e.volume)))))
    end
    if e.issue then table.insert(pieces, L(" (" .. tostring(e.issue) .. ")")) end
    if e.page then table.insert(pieces, L(", " .. tostring(e.page))) end
    table.insert(pieces, L("."))
  elseif kind == "conference" then
    if e["container-title"] then
      table.insert(pieces, L(" In: "))
      table.insert(pieces, one(pandoc.Emph(md(e["container-title"]))))
    end
    if e.page then table.insert(pieces, L(", pp. " .. tostring(e.page))) end
    table.insert(pieces, L("."))
  elseif kind == "report" or kind == "book" then
    if e.publisher then
      table.insert(pieces, L(" "))
      table.insert(pieces, md(e.publisher))
      table.insert(pieces, L("."))
    end
  elseif kind == "inpress" then
    if e["container-title"] then
      table.insert(pieces, L(" "))
      table.insert(pieces, one(pandoc.Emph(md(e["container-title"]))))
      table.insert(pieces, L("."))
    end
    if e.publisher then
      table.insert(pieces, L(" "))
      table.insert(pieces, md(e.publisher))
      table.insert(pieces, L("."))
    end
  elseif kind == "talk" or kind == "poster" then
    if e.note then
      table.insert(pieces, L(" "))
      table.insert(pieces, md(cleanNote(tostring(e.note))))
      table.insert(pieces, L("."))
    end
    if e.location then
      table.insert(pieces, L(" "))
      table.insert(pieces, md(e.location))
      table.insert(pieces, L("."))
    end
  end

  if e.DOI then
    local doi = tostring(e.DOI)
    table.insert(pieces, L(" DOI: "))
    table.insert(pieces, one(pandoc.Link(L(doi), "https://doi.org/" .. doi)))
    table.insert(pieces, L("."))
  elseif e.URL then
    table.insert(pieces, L(" "))
    table.insert(pieces, one(pandoc.Link(L(tostring(e.URL)), tostring(e.URL))))
  end

  return cat(table.unpack(pieces))
end

local CATEGORIES = {
  papers      = {file = "bibliography/library.bib",     kind = "article",
                 pred = function(e) return e.type == "article-journal" end},
  inpress     = {file = "bibliography/library.bib",     kind = "inpress",
                 pred = function(e) return e.keyword == "unpublished" end},
  reports     = {file = "bibliography/library.bib",     kind = "report",
                 pred = function(e) return e.type == "report" end},
  books       = {file = "bibliography/library.bib",     kind = "book",
                 pred = function(e) return e.type == "book" end},
  conferences = {file = "bibliography/library.bib",     kind = "conference",
                 pred = function(e) return e.type == "paper-conference" end},
  talks       = {file = "bibliography/conferences.bib", kind = "talk",
                 pred = function(e) return e.keyword == "talk" end},
  posters     = {file = "bibliography/conferences.bib", kind = "poster",
                 pred = function(e) return e.keyword == "poster" end},
}

return {
  ["cv-bibliography"] = function(args, kwargs, meta)
    local name = pandoc.utils.stringify(args[1])
    local cfg = CATEGORIES[name]
    if not cfg then
      quarto.log.output("cv-bibliography: unknown category '" .. name .. "'")
      return pandoc.Blocks({})
    end

    local entries = loadBib(cfg.file)
    local selected = {}
    for _, e in ipairs(entries) do
      if cfg.pred(e) then table.insert(selected, e) end
    end
    table.sort(selected, function(a, b)
      local ay, by = entryYear(a), entryYear(b)
      if ay ~= by then return ay > by end
      return tostring(a.id) < tostring(b.id)
    end)

    local items = {}
    for _, e in ipairs(selected) do
      table.insert(items, formatEntry(e, cfg.kind))
    end
    return pandoc.Blocks({numberedList(items)})
  end
}
