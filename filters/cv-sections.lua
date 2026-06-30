-- Quarto shortcode: {{< cv-section NAME >}}
--
-- Reads the array merged into document metadata from the matching
-- data/*.yml file (via _quarto.yml's metadata-files) and renders it as a
-- formatted bullet list, mirroring what templates/cv.tex used to do with
-- Jinja for-loops. Metadata string values are already markdown-parsed by
-- Quarto (so `\&`, `$math$`, etc. arrive as real Pandoc Inlines) -- we just
-- assemble them with literal separators.

local function S(x)
  if x == nil then return "" end
  return pandoc.utils.stringify(x)
end

-- coerce an already-parsed metadata value into Inlines
local function I(x)
  if x == nil then return pandoc.Inlines({}) end
  return pandoc.Inlines(x)
end

-- a literal (non-markdown) separator/label
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

local function bulletList(items)
  local blocks = {}
  for _, inl in ipairs(items) do
    table.insert(blocks, {pandoc.Plain(inl)})
  end
  return pandoc.BulletList(blocks)
end

-- Numbered lists (Invited Talks) count down from the list length to 1
-- (items are already sorted most-recent-first) with a bracketed,
-- CornellRed number; each call numbers its own list independently.
--
-- HTML: the number is a styled inline span (see .cv-num in styles.css).
-- LaTeX: a real itemize with `\item[label]` instead of inline text, so
-- enumitem's own alignment machinery lines up wrapped continuation lines
-- under a fixed-width label column instead of drifting based on each
-- label's text width.
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

-- stable sort (table.sort is not stable; this preserves YAML order on ties,
-- matching Python's stable `sorted()` used by the old filters.py)
local function stableSortBy(list, cmp)
  local idx = {}
  for i, v in ipairs(list) do idx[v] = i end
  table.sort(list, function(a, b)
    if cmp(a, b) then return true end
    if cmp(b, a) then return false end
    return idx[a] < idx[b]
  end)
end

-- compares entries by a tuple of string-stringified attributes, matching
-- filters.py's sort_by_attr (which sorts on str(value) tuples)
local function byAttrs(attrs, reverse)
  return function(a, b)
    for _, k in ipairs(attrs) do
      local av, bv = S(a[k]), S(b[k])
      if av ~= bv then
        if reverse then return av > bv else return av < bv end
      end
    end
    return false
  end
end

-- matches filters.py's sort_last_year: sort by the last 4 characters
-- (a 4-digit year) of the attribute, e.g. "Fall 2008, 2010" -> 2010
local function lastYear(v)
  local s = S(v)
  return tonumber(s:sub(-4)) or 0
end

local function byLastYear(attr, reverse)
  return function(a, b)
    local av, bv = lastYear(a[attr]), lastYear(b[attr])
    if reverse then return av > bv else return av < bv end
  end
end

-- mimic Jinja's `capitalize` filter (= Python str.capitalize()): first
-- character upper, the rest lower
local function capitalize(text)
  if text == "" then return text end
  return text:sub(1, 1):upper() .. text:sub(2):lower()
end

local function toList(meta_value)
  local out = {}
  for _, e in ipairs(meta_value or {}) do table.insert(out, e) end
  return out
end

local SECTIONS = {}

SECTIONS["interests"] = function(meta)
  local items = {}
  for _, e in ipairs(meta.interests or {}) do
    table.insert(items, I(e.name))
  end
  return pandoc.Blocks({bulletList(items)})
end

SECTIONS["appointments"] = function(meta)
  local entries = toList(meta.appointments)
  stableSortBy(entries, byAttrs({"start"}, true))
  local items = {}
  for _, e in ipairs(entries) do
    table.insert(items, cat(
      I(e.title), L(", "), I(e.dept), L(", "), I(e.univ), L(", "),
      I(e.start), L("\u{2013}"), I(e["end"])
    ))
  end
  return pandoc.Blocks({bulletList(items)})
end

SECTIONS["education"] = function(meta)
  local entries = toList(meta.degrees)
  stableSortBy(entries, byAttrs({"year"}, true))
  local items = {}
  for _, e in ipairs(entries) do
    table.insert(items, cat(
      I(e.degree), L(", "), I(e.subject), L(", "), I(e.school), L(", "), I(e.year)
    ))
  end
  return pandoc.Blocks({bulletList(items)})
end

SECTIONS["talks"] = function(meta)
  local entries = toList(meta.talks)
  stableSortBy(entries, byAttrs({"year"}, true))
  local items = {}
  for _, e in ipairs(entries) do
    local parts = {one(pandoc.Quoted("DoubleQuote", I(e.title))), L(", ")}
    if e.event then
      table.insert(parts, I(e.event))
      table.insert(parts, L(", "))
    end
    table.insert(parts, I(e.org))
    table.insert(parts, L(". "))
    table.insert(parts, I(e.location))
    table.insert(parts, L(". "))
    table.insert(parts, I(e.month))
    if S(e.month) ~= "May" then
      table.insert(parts, L("."))
    end
    table.insert(parts, L(" "))
    table.insert(parts, I(e.year))
    if e.coauthor then
      table.insert(parts, L(" (with "))
      table.insert(parts, I(e.coauthor))
      table.insert(parts, L(")"))
    end
    table.insert(parts, L("."))
    table.insert(items, cat(table.unpack(parts)))
  end
  return pandoc.Blocks({numberedList(items)})
end

SECTIONS["workshops"] = function(meta)
  local entries = toList(meta.workshops)
  stableSortBy(entries, byLastYear("year", true))
  local items = {}
  for _, e in ipairs(entries) do
    local parts = {I(e.title), L(". "), I(e.location), L(". "), I(e.month)}
    if S(e.month) ~= "May" then table.insert(parts, L(".")) end
    table.insert(parts, L(" "))
    table.insert(parts, I(e.year))
    table.insert(parts, L("."))
    table.insert(items, cat(table.unpack(parts)))
  end
  return pandoc.Blocks({bulletList(items)})
end

SECTIONS["grants"] = function(meta)
  local entries = toList(meta.grants)
  stableSortBy(entries, byAttrs({"start"}, true))
  local items = {}
  for _, e in ipairs(entries) do
    local parts = {I(e.role), L(", "), one(pandoc.Quoted("DoubleQuote", I(e.title))), L(". ")}
    if e.PI then
      table.insert(parts, L("PI: "))
      table.insert(parts, I(e.PI))
      table.insert(parts, L(". "))
    end
    table.insert(parts, I(e.funder))
    table.insert(parts, L(", $"))
    table.insert(parts, I(e.amount))
    if e.total then
      table.insert(parts, L(" (total: $"))
      table.insert(parts, I(e.total))
      table.insert(parts, L(")"))
    end
    table.insert(parts, L(". "))
    table.insert(parts, I(e.start))
    table.insert(parts, L("\u{2013}"))
    table.insert(parts, I(e["end"]))
    table.insert(parts, L("."))
    table.insert(items, cat(table.unpack(parts)))
  end
  return pandoc.Blocks({bulletList(items)})
end

SECTIONS["projects"] = function(meta)
  local entries = toList(meta.projects)
  stableSortBy(entries, byAttrs({"start"}, true))
  local items = {}
  for _, e in ipairs(entries) do
    table.insert(items, cat(
      I(e.title), L(". "), I(e.role), L(". PI: "), I(e.PI), L(". "),
      I(e.funder), L(". "), I(e.start), L("\u{2013}"), I(e["end"]), L(".")
    ))
  end
  return pandoc.Blocks({bulletList(items)})
end

SECTIONS["teaching"] = function(meta)
  local entries = toList(meta.classes)
  local byUniv, univNames = {}, {}
  for _, e in ipairs(entries) do
    local u = S(e.university)
    if not byUniv[u] then
      byUniv[u] = {}
      table.insert(univNames, u)
    end
    table.insert(byUniv[u], e)
  end
  table.sort(univNames)
  local blocks = {}
  for _, u in ipairs(univNames) do
    local group = byUniv[u]
    stableSortBy(group, byLastYear("year", true))
    table.insert(blocks, pandoc.Header(2, L(u), pandoc.Attr("", {"unnumbered"})))
    local items = {}
    for _, e in ipairs(group) do
      table.insert(items, cat(
        I(e.course), L(" \u{2014} "), I(e.title), L(". "), I(e.role), L(". "),
        I(e.semester), L(" "), I(e.year), L(".")
      ))
    end
    table.insert(blocks, bulletList(items))
  end
  return pandoc.Blocks(blocks)
end

local function advisingEntry(e, withDegree)
  local parts = {I(e.name), L(". ")}
  if withDegree then
    table.insert(parts, I(e.degree))
    table.insert(parts, L(", "))
    table.insert(parts, I(e.field))
  else
    table.insert(parts, I(e.field or e.area))
  end
  table.insert(parts, L(". "))
  if e.role then
    table.insert(parts, I(e.role))
    table.insert(parts, L(". "))
  end
  if e.note then
    table.insert(parts, I(e.note))
    table.insert(parts, L(". "))
  end
  table.insert(parts, I(e.start))
  table.insert(parts, L("\u{2013}"))
  table.insert(parts, I(e["end"]))
  table.insert(parts, L(". "))
  if e.thesis then
    table.insert(parts, L('Thesis: "'))
    table.insert(parts, L(capitalize(S(e.thesis))))
    table.insert(parts, L('." '))
  end
  if e.current then
    table.insert(parts, L("Current: "))
    table.insert(parts, I(e.current))
    table.insert(parts, L("."))
  end
  return cat(table.unpack(parts))
end

SECTIONS["advising"] = function(meta)
  local entries = toList(meta.advising)
  local byType = {Postdoctoral = {}, Graduate = {}, Undergraduate = {}}
  for _, e in ipairs(entries) do
    local t = S(e.type)
    if byType[t] then table.insert(byType[t], e) end
  end
  local order = {"Postdoctoral", "Graduate", "Undergraduate"}
  local blocks = {}
  for _, t in ipairs(order) do
    local group = byType[t]
    if #group > 0 then
      table.insert(blocks, pandoc.Header(2, L(t), pandoc.Attr("", {"unnumbered"})))
      local items = {}
      if t == "Postdoctoral" then
        stableSortBy(group, byAttrs({"end", "start"}, true))
        for _, e in ipairs(group) do table.insert(items, advisingEntry(e, false)) end
      elseif t == "Graduate" then
        stableSortBy(group, byAttrs({"degree", "end", "start"}, true))
        for _, e in ipairs(group) do table.insert(items, advisingEntry(e, true)) end
      else
        stableSortBy(group, byAttrs({"end", "start"}, true))
        for _, e in ipairs(group) do table.insert(items, advisingEntry(e, false)) end
      end
      table.insert(blocks, bulletList(items))
    end
  end
  return pandoc.Blocks(blocks)
end

SECTIONS["committee"] = function(meta)
  local entries = toList(meta.member)
  stableSortBy(entries, byAttrs({"year"}, true))
  local items = {}
  for _, e in ipairs(entries) do
    table.insert(items, cat(I(e.name), L(", "), I(e.degree), L(", "), I(e.field), L(". "), I(e.year), L(".")))
  end
  return pandoc.Blocks({bulletList(items)})
end

SECTIONS["awards"] = function(meta)
  local entries = toList(meta.awards)
  stableSortBy(entries, byAttrs({"year"}, true))
  local items = {}
  for _, e in ipairs(entries) do
    table.insert(items, cat(I(e.title), L(", "), I(e.org), L(". "), I(e.year)))
  end
  return pandoc.Blocks({bulletList(items)})
end

SECTIONS["outreach"] = function(meta)
  local entries = toList(meta.outreach)
  stableSortBy(entries, byLastYear("year", true))
  local items = {}
  for _, e in ipairs(entries) do
    local parts = {I(e.activity), L(", ")}
    if e.url then
      table.insert(parts, one(pandoc.Link(I(e.url), S(e.url))))
      table.insert(parts, L(", "))
    end
    table.insert(parts, I(e.org))
    table.insert(parts, L(", "))
    table.insert(parts, I(e.role))
    table.insert(parts, L(". "))
    table.insert(parts, I(e.year))
    table.insert(parts, L("."))
    table.insert(items, cat(table.unpack(parts)))
  end
  return pandoc.Blocks({bulletList(items)})
end

SECTIONS["service"] = function(meta)
  local entries = toList(meta.service)
  local items = {}
  for _, e in ipairs(entries) do
    local parts = {I(e.title), L(",")}
    if e.journal then
      table.insert(parts, L(" "))
      table.insert(parts, one(pandoc.Emph(I(e.journal))))
      table.insert(parts, L("."))
    end
    if e.org then
      table.insert(parts, L(" "))
      table.insert(parts, I(e.org))
      table.insert(parts, L("."))
    end
    if e.start then
      table.insert(parts, L(" "))
      table.insert(parts, I(e.start))
      if e["end"] then
        table.insert(parts, L("\u{2013}"))
        table.insert(parts, I(e["end"]))
      end
      table.insert(parts, L("."))
    end
    table.insert(items, cat(table.unpack(parts)))
  end
  return pandoc.Blocks({bulletList(items)})
end

SECTIONS["experience"] = function(meta)
  local entries = toList(meta.experience)
  stableSortBy(entries, byAttrs({"end", "start"}, true))
  local items = {}
  for _, e in ipairs(entries) do
    table.insert(items, cat(I(e.title), L(", "), I(e.org), L(". "), I(e.start), L("\u{2013}"), I(e["end"])))
  end
  return pandoc.Blocks({bulletList(items)})
end

-- ---------------------------------------------------------------------
-- {{< cv-header >}}: the name/affiliation/contact block at the top of the
-- CV. Built directly in Lua (rather than `{{< meta >}}` shortcodes inside a
-- raw LaTeX/HTML block) because Quarto's meta shortcode does not expand
-- reliably when its `{{<`/`>}}` delimiters sit directly against LaTeX's own
-- braces (e.g. `\href{{{< meta x >}}}`).
-- ---------------------------------------------------------------------

local function raw(parts, format, text)
  table.insert(parts, pandoc.Inlines({pandoc.RawInline(format, text)}))
end

local function headerLatex(meta)
  local p = meta.person
  local addr = p.address
  local parts = {}
  raw(parts, "latex", "\\thispagestyle{fancy}\n\\begin{minipage}[t]{2.8in}\n \\flushright {\\footnotesize\n \\href{")
  table.insert(parts, I(p.affiliation_link))
  raw(parts, "latex", "}{")
  table.insert(parts, I(p.affiliation))
  raw(parts, "latex", "}\\\\ \\vspace{0in}\n ")
  table.insert(parts, I(addr.line1))
  raw(parts, "latex", "\\\\ \\vspace{0in} ")
  table.insert(parts, I(addr.line2))
  raw(parts, "latex", " \\\\ \\vspace{-0.04in} ")
  table.insert(parts, I(addr.postcode))
  raw(parts, "latex", ", ")
  table.insert(parts, I(addr.country))
  raw(parts, "latex", "}\n \\end{minipage}\n \\begin{minipage}[t]{2.5in}\n   \\flushright {\\footnotesize  \\texttt{\\href{mailto:")
  table.insert(parts, I(p.email))
  raw(parts, "latex", "}{")
  table.insert(parts, I(p.email))
  raw(parts, "latex", "}} \\, \\faEnvelope} \\\\ \\vspace{-0.21in}\n   \\flushright {\\footnotesize  \\texttt{\\href{")
  table.insert(parts, I(p.web))
  raw(parts, "latex", "}{")
  table.insert(parts, I(p.web))
  raw(parts, "latex", "}} \\, \\faGlobe} \\\\ \\vspace{-0.195in}\n   \\flushright {\\footnotesize\n   \\texttt{\\href{https://github.com/")
  table.insert(parts, I(p.github))
  raw(parts, "latex", "}{")
  table.insert(parts, I(p.github))
  raw(parts, "latex", "}} \\, \\faGithub} \\\\ \\vspace{-0.2in}\n   \\flushright {\\footnotesize\n   \\texttt{\\href{https://scholar.google.com/citations?user=")
  table.insert(parts, I(p.googlescholar))
  raw(parts, "latex", "}{")
  table.insert(parts, I(p.first_name))
  raw(parts, "latex", " ")
  table.insert(parts, I(p.last_name))
  raw(parts, "latex", "}} \\, \\faGraduationCap}\n \\end{minipage}\n\n \\bigskip\n\n \\noindent{\\LARGE\\bfseries \\textcolor{CornellGray}{")
  table.insert(parts, I(p.first_name))
  raw(parts, "latex", " ")
  table.insert(parts, I(p.last_name))
  raw(parts, "latex", "}}\n \\reversemarginpar\n\n\\bigskip\n")
  return cat(table.unpack(parts))
end

local function headerHtml(meta)
  local p = meta.person
  local addr = p.address
  local parts = {}
  raw(parts, "html", '<div class="cv-header"><div class="cv-contact"><p class="cv-affiliation"><a href="')
  table.insert(parts, I(p.affiliation_link))
  raw(parts, "html", '">')
  table.insert(parts, I(p.affiliation))
  raw(parts, "html", '</a><br>')
  table.insert(parts, I(addr.line1))
  raw(parts, "html", ', ')
  table.insert(parts, I(addr.line2))
  raw(parts, "html", '<br>')
  table.insert(parts, I(addr.postcode))
  raw(parts, "html", ', ')
  table.insert(parts, I(addr.country))
  raw(parts, "html", '</p><p class="cv-links"><a href="mailto:')
  table.insert(parts, I(p.email))
  raw(parts, "html", '"><i class="bi bi-envelope"></i> ')
  table.insert(parts, I(p.email))
  raw(parts, "html", '</a><a href="')
  table.insert(parts, I(p.web))
  raw(parts, "html", '"><i class="bi bi-globe"></i> ')
  table.insert(parts, I(p.web))
  raw(parts, "html", '</a><a href="https://github.com/')
  table.insert(parts, I(p.github))
  raw(parts, "html", '"><i class="bi bi-github"></i> ')
  table.insert(parts, I(p.github))
  raw(parts, "html", '</a><a href="https://scholar.google.com/citations?user=')
  table.insert(parts, I(p.googlescholar))
  raw(parts, "html", '"><i class="bi bi-mortarboard"></i> Google Scholar</a></p></div><div class="cv-name">')
  table.insert(parts, I(p.first_name))
  raw(parts, "html", ' ')
  table.insert(parts, I(p.last_name))
  raw(parts, "html", '</div><div class="cv-jobtitle">')
  table.insert(parts, I(p.title))
  raw(parts, "html", ', ')
  table.insert(parts, I(p.affiliation))
  raw(parts, "html", '</div></div>')
  return cat(table.unpack(parts))
end

return {
  ["cv-header"] = function(args, kwargs, meta)
    local builder = quarto.doc.is_format("latex") and headerLatex or headerHtml
    return pandoc.Blocks({pandoc.Plain(builder(meta))})
  end,
  ["cv-section"] = function(args, kwargs, meta)
    local name = pandoc.utils.stringify(args[1])
    local fn = SECTIONS[name]
    if not fn then
      quarto.log.output("cv-section: unknown section '" .. name .. "'")
      return pandoc.Blocks({})
    end
    return fn(meta)
  end
}
