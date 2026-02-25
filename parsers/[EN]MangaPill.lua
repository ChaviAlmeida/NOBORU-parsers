MangaPill = Parser:new("MangaPill", "https://mangapill.com", "ENG", "MANGAPILL", 1)

MangaPill.Filters = {
    {
        Name = "Type",
        Type = "radio",
        Tags = {"All", "Manga", "Novel", "One-Shot", "Doujinshi", "Manhua", "OEL"},
        Default = "All"
    },
    {
        Name = "Status",
        Type = "radio",
        Tags = {"All", "Publishing", "Finished", "On Hiatus", "Discontinued", "Not Yet Published"},
        Default = "All"
    },
    {
        Name = "Genre",
        Type = "check",
        Tags = {
            "Action", "Adventure", "Comedy", "Demons", "Drama",
            "Ecchi", "Fantasy", "Game", "Harem", "Historical",
            "Horror", "Isekai", "Josei", "Magic", "Martial Arts",
            "Mecha", "Military", "Mystery", "Parody", "Psychological",
            "Romance", "School", "Sci-Fi", "Seinen", "Shoujo",
            "Shounen", "Slice of Life", "Sports", "Super Power",
            "Supernatural", "Thriller", "Tragedy", "Vampire"
        }
    }
}

local TypeKeys = {
    ["All"] = "", ["Manga"] = "manga", ["Novel"] = "novel",
    ["One-Shot"] = "one-shot", ["Doujinshi"] = "doujinshi",
    ["Manhua"] = "manhua", ["OEL"] = "oel"
}

local StatusKeys = {
    ["All"] = "", ["Publishing"] = "publishing", ["Finished"] = "finished",
    ["On Hiatus"] = "on hiatus", ["Discontinued"] = "discontinued",
    ["Not Yet Published"] = "not yet published"
}

local GenreIDs = {
    ["Action"] = 1, ["Adventure"] = 2, ["Comedy"] = 4, ["Demons"] = 6,
    ["Drama"] = 8, ["Ecchi"] = 9, ["Fantasy"] = 10, ["Game"] = 11,
    ["Harem"] = 14, ["Historical"] = 15, ["Horror"] = 16, ["Isekai"] = 45,
    ["Josei"] = 17, ["Magic"] = 18, ["Martial Arts"] = 19,
    ["Mecha"] = 20, ["Military"] = 21, ["Mystery"] = 23,
    ["Parody"] = 24, ["Psychological"] = 26, ["Romance"] = 27,
    ["School"] = 28, ["Sci-Fi"] = 29, ["Seinen"] = 30,
    ["Shoujo"] = 31, ["Shounen"] = 33, ["Slice of Life"] = 34,
    ["Sports"] = 36, ["Super Power"] = 37, ["Supernatural"] = 38,
    ["Thriller"] = 39, ["Tragedy"] = 40, ["Vampire"] = 41
}

local function decodeHtml(s)
    return s:gsub("&#(%d+);", function(n) return u8c and u8c(tonumber(n)) or "" end)
              :gsub("&#x(%x+);", function(n) return u8c and u8c(tonumber(n, 16)) or "" end)
              :gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">")
              :gsub("&quot;", '"'):gsub("&apos;", "'"):gsub("&#039;", "'")
end

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

local function parseMangaList(html, Manga, self)
    -- MangaPill uses <a> tags with manga cards
    for link, img, title in html:gmatch('<a[^>]-href="(/manga/[^"]-)"[^>]->[^<]-<img[^>]-data%-src="([^"]-)"[^>]->[^<]-</a>.-<a[^>]-href="/manga/[^"]-"[^>]->[^<]-([^<]-)</a>') do
        local name = decodeHtml(title:match("^%s*(.-)%s*$") or title)
        local path = link:match("/manga/(%S+)")
        if name ~= "" and path then
            local m = CreateManga(name, path, img, self.ID, self.Link .. link)
            if m then
                Manga[#Manga + 1] = m
            end
            coroutine.yield(false)
        end
    end
    -- Alternate pattern for search results
    if #Manga == 0 then
        for block in html:gmatch('<div[^>]-class="[^"]-manga%-card[^"]-"[^>]->(.-)</div>%s-</div>') do
            local link = block:match('href="(/manga/[^"]-)"')
            local img = block:match('data%-src="([^"]-)"') or block:match('src="([^"]-)"')
            local title = block:match('class="[^"]-card%-title[^"]-"[^>]->[^<]-<[^>]->[^<]-([^<]+)')
            if not title then
                title = block:match('title="([^"]-)"')
            end
            if link and title then
                local name = decodeHtml(title:match("^%s*(.-)%s*$") or title)
                local path = link:match("/manga/(%S+)")
                if name ~= "" and path then
                    local m = CreateManga(name, path, img or "", self.ID, self.Link .. link)
                    if m then
                        Manga[#Manga + 1] = m
                    end
                    coroutine.yield(false)
                end
            end
        end
    end
    -- Check if there's a next page
    Manga.NoPages = not html:match('rel="next"')
end

function MangaPill:getPopularManga(page, Manga)
    local html = fetchString(self.Link .. "/search?page=" .. page .. "&type=&status=")
    parseMangaList(html, Manga, self)
end

function MangaPill:getLatestManga(page, Manga)
    if page > 1 then
        Manga.NoPages = true
        return
    end
    local html = fetchString(self.Link)
    parseMangaList(html, Manga, self)
    Manga.NoPages = true
end

function MangaPill:searchManga(search, page, Manga, filter)
    local typeParam = ""
    local statusParam = ""
    local genreParam = ""

    if filter then
        local t = filter[1] or filter["Type"] or "All"
        if type(t) == "string" and TypeKeys[t] then
            typeParam = TypeKeys[t]
        end
        local s = filter[2] or filter["Status"] or "All"
        if type(s) == "string" and StatusKeys[s] then
            statusParam = StatusKeys[s]
        end
        local genres = filter[3] or filter["Genre"]
        if genres and #genres > 0 then
            for _, g in ipairs(genres) do
                local gid = GenreIDs[g]
                if gid then
                    genreParam = genreParam .. "&genre=" .. gid
                end
            end
        end
    end

    local url = self.Link .. "/search?q=" .. search ..
        "&page=" .. page ..
        "&type=" .. typeParam ..
        "&status=" .. statusParam ..
        genreParam
    local html = fetchString(url)
    parseMangaList(html, Manga, self)
end

function MangaPill:getChapters(manga, Chapters)
    local html = fetchString(self.Link .. "/manga/" .. manga.Path)
    for link, title in html:gmatch('<a[^>]-href="(/chapters/[^"]-)"[^>]->(.-)</a>') do
        local name = decodeHtml(title:gsub("<[^>]->", ""):match("^%s*(.-)%s*$") or title)
        local path = link:match("/chapters/(%S+)")
        if name ~= "" and path then
            local c = CreateChapter(name, path, self.ID, self.Link .. link)
            if c then
                Chapters[#Chapters + 1] = c
            end
            coroutine.yield(false)
        end
    end
    -- Alternate chapter pattern
    if #Chapters == 0 then
        for link, name in html:gmatch('<a[^>]-href="(/chapters/[^"]-)"[^>]-title="([^"]-)"') do
            local cleanName = decodeHtml(name)
            local path = link:match("/chapters/(%S+)")
            if cleanName ~= "" and path then
                local c = CreateChapter(cleanName, path, self.ID, self.Link .. link)
                if c then
                    Chapters[#Chapters + 1] = c
                end
                coroutine.yield(false)
            end
        end
    end
end

function MangaPill:prepareChapter(chapter, Table)
    local html = fetchString(self.Link .. "/chapters/" .. chapter.Path)
    local index = 1
    for img in html:gmatch('chapter%-container.-<img[^>]-data%-src="([^"]-)"') do
        Table[index] = {Link = img, Page = index}
        index = index + 1
        coroutine.yield(false)
    end
    -- Alternate pattern
    if index == 1 then
        for img in html:gmatch('<img[^>]-class="[^"]-js%-page[^"]-"[^>]-data%-src="([^"]-)"') do
            Table[index] = {Link = img, Page = index}
            index = index + 1
            coroutine.yield(false)
        end
    end
end

function MangaPill:loadChapterPage(link, Table)
    Table.Link = link.Link
end
