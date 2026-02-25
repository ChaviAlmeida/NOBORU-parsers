MangaSee2 = Parser:new("MangaSee", "https://mangasee123.com", "ENG", "MANGASEE2", 2)

local function fetchString(url)
    local t = {}
    Threads.insertTask(t, {
        Type = "StringRequest",
        Link = url,
        Table = t,
        Index = "string"
    })
    while Threads.check(t) do
        coroutine.yield(false)
    end
    return t.string or ""
end

local function decodeHtml(s)
    if not s then return "" end
    return s:gsub("&#(%d+);", function(n) return u8c and u8c(tonumber(n)) or "" end)
              :gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">")
              :gsub("&quot;", '"'):gsub("&#039;", "'")
end

-- MangaSee uses an internal chapter number format: XNNNNND
-- where X is volume hint, NNNNN is chapter*10 padded, D is subchapter
local function chapterDisplay(chapterStr)
    if not chapterStr or chapterStr == "" then return "1" end
    local n = tonumber(chapterStr)
    if not n then return chapterStr end
    local s = tostring(n)
    while #s < 6 do s = "0" .. s end
    local major = tonumber(s:sub(2, 5)) or 0
    local minor = tonumber(s:sub(6, 6)) or 0
    if minor > 0 then
        return major .. "." .. minor
    end
    return tostring(major)
end

local function chapterUrl(indexName, chapter)
    local s = tostring(tonumber(chapter) or 100010)
    while #s < 6 do s = "0" .. s end
    local prefix = s:sub(1, 1)
    local index = ""
    if prefix ~= "1" then
        index = "-index-" .. prefix
    end
    local major = s:sub(2, 5):gsub("^0+", "")
    if major == "" then major = "0" end
    local minor = tonumber(s:sub(6, 6)) or 0
    local suffix = ""
    if minor > 0 then
        suffix = "." .. minor
    end
    return "/read-online/" .. indexName .. "-chapter-" .. major .. suffix .. index .. ".html"
end

function MangaSee2:getPopularManga(page, Manga)
    if page > 1 then
        Manga.NoPages = true
        return
    end
    local html = fetchString(self.Link)
    -- Extract hot update manga from embedded JSON
    local hotJson = html:match("vm%.HotUpdateJSON%s*=%s*(%[.-%]);")
    if hotJson then
        for indexName, name in hotJson:gmatch('"IndexName"%s*:%s*"([^"]-)".-"SeriesName"%s*:%s*"([^"]-)"') do
            local cover = "https://temp.compsci88.com/cover/" .. indexName .. ".jpg"
            local m = CreateManga(decodeHtml(name), indexName, cover, self.ID, self.Link .. "/manga/" .. indexName)
            if m then
                Manga[#Manga + 1] = m
            end
            coroutine.yield(false)
        end
    end
    Manga.NoPages = true
end

function MangaSee2:getLatestManga(page, Manga)
    if page > 1 then
        Manga.NoPages = true
        return
    end
    local html = fetchString(self.Link)
    local latestJson = html:match("vm%.LatestJSON%s*=%s*(%[.-%]);")
    if latestJson then
        for indexName, name in latestJson:gmatch('"IndexName"%s*:%s*"([^"]-)".-"SeriesName"%s*:%s*"([^"]-)"') do
            local cover = "https://temp.compsci88.com/cover/" .. indexName .. ".jpg"
            local m = CreateManga(decodeHtml(name), indexName, cover, self.ID, self.Link .. "/manga/" .. indexName)
            if m then
                Manga[#Manga + 1] = m
            end
            coroutine.yield(false)
        end
    end
    Manga.NoPages = true
end

function MangaSee2:searchManga(search, page, Manga)
    if page > 1 then
        Manga.NoPages = true
        return
    end
    -- MangaSee has a directory JSON we can search through
    local html = fetchString(self.Link .. "/search/?name=" .. search)
    -- The search page embeds vm.Directory JSON
    local dirJson = html:match("vm%.Directory%s*=%s*(%[.-%]);")
    if dirJson then
        local searchLower = search:lower()
        local count = 0
        for indexName, name in dirJson:gmatch('"i"%s*:%s*"([^"]-)".-"s"%s*:%s*"([^"]-)"') do
            if name:lower():find(searchLower, 1, true) then
                local cover = "https://temp.compsci88.com/cover/" .. indexName .. ".jpg"
                local m = CreateManga(decodeHtml(name), indexName, cover, self.ID, self.Link .. "/manga/" .. indexName)
                if m then
                    Manga[#Manga + 1] = m
                    count = count + 1
                    if count >= 30 then break end
                end
                coroutine.yield(false)
            end
        end
    end
    Manga.NoPages = true
end

function MangaSee2:getChapters(manga, Chapters)
    local html = fetchString(self.Link .. "/manga/" .. manga.Path)
    -- Chapters are in vm.Chapters JSON
    local chapJson = html:match("vm%.Chapters%s*=%s*(%[.-%]);")
    if chapJson then
        for chapter, chType, date in chapJson:gmatch('"Chapter"%s*:%s*"([^"]-)".-"Type"%s*:%s*"([^"]-)".-"Date"%s*:%s*"([^"]-)"') do
            local displayNum = chapterDisplay(chapter)
            local name = chType .. " " .. displayNum
            local link = chapterUrl(manga.Path, chapter)
            local c = CreateChapter(name, link, self.ID, self.Link .. link)
            if c then
                Chapters[#Chapters + 1] = c
            end
            coroutine.yield(false)
        end
    end
end

function MangaSee2:prepareChapter(chapter, Table)
    local html = fetchString(self.Link .. chapter.Path)
    -- Extract chapter details from vm.CurChapter and vm.CurPathName
    local pathName = html:match('vm%.CurPathName%s*=%s*"([^"]-)"') or ""
    local curChapter = html:match('vm%.CurChapter%s*=%s*({.-});') or ""
    local chapterNum = curChapter:match('"Chapter"%s*:%s*"([^"]-)"') or "100010"
    local numPages = tonumber(curChapter:match('"Page"%s*:%s*"(%d+)"')) or 1
    local directory = curChapter:match('"Directory"%s*:%s*"([^"]-)"') or ""

    local s = tostring(tonumber(chapterNum) or 100010)
    while #s < 6 do s = "0" .. s end
    local prefix = s:sub(1, 1)
    local major = s:sub(2, 5)
    local minor = tonumber(s:sub(6, 6)) or 0
    local chapterPart = major
    if minor > 0 then
        chapterPart = major .. "." .. minor
    end

    local dirPart = ""
    if directory ~= "" then
        dirPart = directory .. "/"
    end

    for i = 1, numPages do
        local pageStr = tostring(i)
        while #pageStr < 3 do pageStr = "0" .. pageStr end
        local imgUrl = "https://official.lowee.us/manga/" .. pathName .. "/" .. dirPart .. chapterPart .. "-" .. pageStr .. ".png"
        Table[i] = {Link = imgUrl, Page = i}
        coroutine.yield(false)
    end
end

function MangaSee2:loadChapterPage(link, Table)
    Table.Link = link.Link
end
