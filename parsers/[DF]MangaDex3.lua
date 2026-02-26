if u8c then
    MangaDex3 = Parser:new("MangaDex", "https://mangadex.org", "DIF", "MANGADEX3", 3)
    MangaDex3.Filters = {
        {
            Name = "Sort By",
            Type = "radio",
            Tags = {
                "Best Match", "Latest Upload", "Oldest Upload",
                "Title Ascending", "Title Descending",
                "Recently Added", "Oldest Added",
                "Most Follows", "Fewest Follows",
                "Year Ascending", "Year Descending"
            }
        },
        {
            Name = "Original Language",
            Type = "radio",
            Tags = {
                "All languages", "Japanese", "Korean",
                "Chinese (Simplified)", "Chinese (Traditional)",
                "English", "Spanish", "Spanish (LATAM)",
                "French", "German", "Italian",
                "Portuguese", "Portuguese (Br)", "Russian",
                "Polish", "Arabic", "Thai",
                "Vietnamese", "Indonesian", "Filipino"
            }
        },
        {
            Name = "Demographic",
            Type = "check",
            Tags = {"Shounen", "Shoujo", "Seinen", "Josei", "None"}
        },
        {
            Name = "Content Rating",
            Type = "check",
            Tags = {"Safe", "Suggestive", "Erotica"},
            Default = {"Safe", "Suggestive"}
        },
        {
            Name = "Publication Status",
            Type = "check",
            Tags = {"Ongoing", "Completed", "Hiatus", "Cancelled"}
        },
        {
            Name = "Genre",
            Type = "checkcross",
            Tags = {
                "Action", "Adventure", "Comedy", "Crime", "Drama",
                "Fantasy", "Historical", "Horror", "Isekai",
                "Magical Girls", "Mecha", "Medical", "Mystery",
                "Philosophical", "Psychological", "Romance",
                "Sci-Fi", "Slice of Life", "Sports", "Superhero",
                "Thriller", "Tragedy", "Wuxia",
                "Boys' Love", "Girls' Love"
            }
        },
        {
            Name = "Theme",
            Type = "checkcross",
            Tags = {
                "Aliens", "Animals", "Cooking", "Crossdressing",
                "Delinquents", "Demons", "Genderswap", "Ghosts",
                "Gyaru", "Harem", "Loli", "Mafia", "Magic",
                "Martial Arts", "Military", "Monster Girls",
                "Monsters", "Music", "Ninja", "Office Workers",
                "Police", "Post-Apocalyptic", "Reincarnation",
                "Reverse Harem", "Samurai", "School Life", "Shota",
                "Supernatural", "Survival", "Time Travel",
                "Traditional Games", "Vampires", "Video Games",
                "Virtual Reality", "Zombies"
            }
        }
    }

    local API = "https://api.mangadex.org"

    local OrderKeys = {
        ["Best Match"] = "relevance&order[relevance]=desc",
        ["Latest Upload"] = "latestUploadedChapter&order[latestUploadedChapter]=desc",
        ["Oldest Upload"] = "latestUploadedChapter&order[latestUploadedChapter]=asc",
        ["Title Ascending"] = "title&order[title]=asc",
        ["Title Descending"] = "title&order[title]=desc",
        ["Recently Added"] = "createdAt&order[createdAt]=desc",
        ["Oldest Added"] = "createdAt&order[createdAt]=asc",
        ["Most Follows"] = "followedCount&order[followedCount]=desc",
        ["Fewest Follows"] = "followedCount&order[followedCount]=asc",
        ["Year Ascending"] = "year&order[year]=asc",
        ["Year Descending"] = "year&order[year]=desc"
    }

    local LangCodes = {
        ["All languages"] = "",
        ["Japanese"] = "ja", ["Korean"] = "ko",
        ["Chinese (Simplified)"] = "zh", ["Chinese (Traditional)"] = "zh-hk",
        ["English"] = "en", ["Spanish"] = "es", ["Spanish (LATAM)"] = "es-la",
        ["French"] = "fr", ["German"] = "de", ["Italian"] = "it",
        ["Portuguese"] = "pt", ["Portuguese (Br)"] = "pt-br", ["Russian"] = "ru",
        ["Polish"] = "pl", ["Arabic"] = "ar", ["Thai"] = "th",
        ["Vietnamese"] = "vi", ["Indonesian"] = "id", ["Filipino"] = "tl"
    }

    local DemographicKeys = {
        ["Shounen"] = "shounen", ["Shoujo"] = "shoujo",
        ["Seinen"] = "seinen", ["Josei"] = "josei", ["None"] = "none"
    }

    local StatusKeys = {
        ["Ongoing"] = "ongoing", ["Completed"] = "completed",
        ["Hiatus"] = "hiatus", ["Cancelled"] = "cancelled"
    }

    local ContentRatingKeys = {
        ["Safe"] = "safe", ["Suggestive"] = "suggestive",
        ["Erotica"] = "erotica", ["Pornographic"] = "pornographic"
    }

    -- UUID-based tag mapping for MangaDex API
    local TagUUIDs = {}
    local tagsLoaded = false

    local function loadTags()
        if tagsLoaded then return end
        local t = {}
        Threads.insertTask(t, {
            Type = "StringRequest",
            Link = API .. "/manga/tag",
            Table = t,
            Index = "string"
        })
        while Threads.check(t) do
            coroutine.yield(false)
        end
        local response = t.string or ""
        for id, name in response:gmatch('"id"%s*:%s*"([^"]+)".-"en"%s*:%s*"([^"]+)"') do
            TagUUIDs[name] = id
        end
        tagsLoaded = true
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

    local function getCoverUrl(mangaId, coverFileName)
        if coverFileName and coverFileName ~= "" then
            return "https://uploads.mangadex.org/covers/" .. mangaId .. "/" .. coverFileName .. ".256.jpg"
        end
        return ""
    end

    local function parseMangaList(response, Manga, self)
        -- Parse each manga entry from the JSON response
        for mangaBlock in response:gmatch('"id"%s*:%s*"([^"]-)".-"type"%s*:%s*"manga"') do
            -- We need a more robust approach: find the block around each manga
        end
        -- Better approach: split by manga entries
        local offset = 1
        while true do
            local idStart, idEnd = response:find('"type"%s*:%s*"manga"', offset)
            if not idStart then break end

            -- Find the manga id before this type marker
            local blockStart = response:sub(1, idStart)
            local mangaId = blockStart:match('.*"id"%s*:%s*"([^"]-)"')
            if not mangaId then
                offset = idEnd + 1
                break
            end

            -- Find the next manga entry or end to delimit this block
            local nextEntry = response:find('"type"%s*:%s*"manga"', idEnd + 1) or #response
            local block = response:sub(idStart, nextEntry)

            -- Extract title (prefer English, fallback to first available)
            local title = block:match('"en"%s*:%s*"([^"]-)"')
            if not title then
                title = block:match('"title"%s*:%s*{[^}]-"[^"]-"%s*:%s*"([^"]-)"')
            end
            if not title then
                title = block:match('"ja%-ro"%s*:%s*"([^"]-)"') or
                        block:match('"ja"%s*:%s*"([^"]-)"') or "Unknown"
            end

            -- Extract cover filename from relationships
            local coverFile = block:match('"type"%s*:%s*"cover_art".-"fileName"%s*:%s*"([^"]-)"')

            local coverUrl = getCoverUrl(mangaId, coverFile)

            local m = CreateManga(title, mangaId, coverUrl, self.ID, self.Link .. "/title/" .. mangaId)
            if m then
                Manga[#Manga + 1] = m
            end
            coroutine.yield(false)
            offset = idEnd + 1
        end
    end

    local LIMIT = 20

    local function buildFilterParams(filter)
        local params = ""
        if filter then
            -- Content Rating (filter index 4)
            local ratings = filter[4] or filter["Content Rating"]
            if ratings and #ratings > 0 then
                for _, r in ipairs(ratings) do
                    local key = ContentRatingKeys[r]
                    if key then params = params .. "&contentRating[]=" .. key end
                end
            else
                params = params .. "&contentRating[]=safe&contentRating[]=suggestive"
            end

            -- Demographic (filter index 3)
            local demos = filter[3] or filter["Demographic"]
            if demos and #demos > 0 then
                for _, d in ipairs(demos) do
                    local key = DemographicKeys[d]
                    if key then params = params .. "&publicationDemographic[]=" .. key end
                end
            end

            -- Publication Status (filter index 5)
            local statuses = filter[5] or filter["Publication Status"]
            if statuses and #statuses > 0 then
                for _, s in ipairs(statuses) do
                    local key = StatusKeys[s]
                    if key then params = params .. "&status[]=" .. key end
                end
            end

            -- Original Language (filter index 2)
            local lang = filter[2] or filter["Original Language"] or "All languages"
            if type(lang) == "string" then
                local code = LangCodes[lang]
                if code and code ~= "" then
                    params = params .. "&originalLanguage[]=" .. code
                end
            end

            -- Sort (filter index 1)
            local sort = filter[1] or filter["Sort By"] or "Latest Upload"
            if type(sort) == "string" then
                local orderParam = OrderKeys[sort]
                if orderParam then
                    -- We handle ordering separately since it replaces the default
                end
            end

            -- Genre include/exclude (filter index 6)
            local genres = filter[6] or filter["Genre"]
            if genres then
                loadTags()
                if genres.include then
                    for _, g in ipairs(genres.include) do
                        local uuid = TagUUIDs[g]
                        if uuid then params = params .. "&includedTags[]=" .. uuid end
                    end
                end
                if genres.exclude then
                    for _, g in ipairs(genres.exclude) do
                        local uuid = TagUUIDs[g]
                        if uuid then params = params .. "&excludedTags[]=" .. uuid end
                    end
                end
            end

            -- Theme include/exclude (filter index 7)
            local themes = filter[7] or filter["Theme"]
            if themes then
                loadTags()
                if themes.include then
                    for _, t in ipairs(themes.include) do
                        local uuid = TagUUIDs[t]
                        if uuid then params = params .. "&includedTags[]=" .. uuid end
                    end
                end
                if themes.exclude then
                    for _, t in ipairs(themes.exclude) do
                        local uuid = TagUUIDs[t]
                        if uuid then params = params .. "&excludedTags[]=" .. uuid end
                    end
                end
            end
        else
            params = params .. "&contentRating[]=safe&contentRating[]=suggestive"
        end
        return params
    end

    function MangaDex3:getPopularManga(page, Manga)
        local offset = (page - 1) * LIMIT
        local url = API .. "/manga?limit=" .. LIMIT .. "&offset=" .. offset ..
            "&includes[]=cover_art&order[followedCount]=desc" ..
            "&contentRating[]=safe&contentRating[]=suggestive" ..
            "&hasAvailableChapters=true"
        local response = fetchString(url)
        parseMangaList(response, Manga, self)
        local total = tonumber(response:match('"total"%s*:%s*(%d+)')) or 0
        Manga.NoPages = (offset + LIMIT) >= total
    end

    function MangaDex3:getLatestManga(page, Manga)
        local offset = (page - 1) * LIMIT
        local url = API .. "/manga?limit=" .. LIMIT .. "&offset=" .. offset ..
            "&includes[]=cover_art&order[latestUploadedChapter]=desc" ..
            "&contentRating[]=safe&contentRating[]=suggestive" ..
            "&hasAvailableChapters=true"
        local response = fetchString(url)
        parseMangaList(response, Manga, self)
        local total = tonumber(response:match('"total"%s*:%s*(%d+)')) or 0
        Manga.NoPages = (offset + LIMIT) >= total
    end

    function MangaDex3:searchManga(search, page, Manga, filter)
        local offset = (page - 1) * LIMIT
        local sortParam = "latestUploadedChapter&order[latestUploadedChapter]=desc"
        if filter then
            local sort = filter[1] or filter["Sort By"]
            if type(sort) == "string" and OrderKeys[sort] then
                sortParam = OrderKeys[sort]
            end
        end
        local url = API .. "/manga?limit=" .. LIMIT .. "&offset=" .. offset ..
            "&includes[]=cover_art&hasAvailableChapters=true" ..
            "&title=" .. search ..
            buildFilterParams(filter)
        local response = fetchString(url)
        parseMangaList(response, Manga, self)
        local total = tonumber(response:match('"total"%s*:%s*(%d+)')) or 0
        Manga.NoPages = (offset + LIMIT) >= total
    end

    function MangaDex3:getChapters(manga, Chapters)
        local mangaId = manga.Path
        local offset = 0
        local total = 1
        while offset < total do
            local url = API .. "/manga/" .. mangaId .. "/feed?limit=100&offset=" .. offset ..
                "&translatedLanguage[]=en&translatedLanguage[]=es&translatedLanguage[]=es-la" ..
                "&translatedLanguage[]=fr&translatedLanguage[]=pt-br&translatedLanguage[]=ja" ..
                "&order[volume]=desc&order[chapter]=desc" ..
                "&includes[]=scanlation_group" ..
                "&contentRating[]=safe&contentRating[]=suggestive&contentRating[]=erotica"
            local response = fetchString(url)
            total = tonumber(response:match('"total"%s*:%s*(%d+)')) or 0

            for chapterId, block in response:gmatch('"id"%s*:%s*"([^"]-)"(.-)"type"%s*:%s*"chapter"') do
                local vol = block:match('"volume"%s*:%s*"([^"]-)"') or ""
                local ch = block:match('"chapter"%s*:%s*"([^"]-)"') or ""
                local title = block:match('"title"%s*:%s*"([^"]-)"') or ""
                local lang = block:match('"translatedLanguage"%s*:%s*"([^"]-)"') or "en"
                local group = block:match('"type"%s*:%s*"scanlation_group".-"name"%s*:%s*"([^"]-)"') or ""

                local chapterName = ""
                if vol ~= "" then chapterName = "Vol." .. vol .. " " end
                if ch ~= "" then
                    chapterName = chapterName .. "Ch." .. ch
                end
                if title ~= "" then
                    chapterName = chapterName .. (chapterName ~= "" and " - " or "") .. title
                end
                if group ~= "" then
                    chapterName = chapterName .. " [" .. group .. "]"
                end
                if lang ~= "en" then
                    chapterName = chapterName .. " (" .. lang .. ")"
                end
                if chapterName == "" then
                    chapterName = "Chapter " .. chapterId:sub(1, 8)
                end

                local c = CreateChapter(chapterName, chapterId, self.ID, self.Link .. "/chapter/" .. chapterId)
                if c then
                    Chapters[#Chapters + 1] = c
                end
                coroutine.yield(false)
            end
            offset = offset + 100
        end
    end

    function MangaDex3:prepareChapter(chapter, Table)
        local chapterId = chapter.Path
        local url = API .. "/at-home/server/" .. chapterId
        local response = fetchString(url)

        local baseUrl = response:match('"baseUrl"%s*:%s*"([^"]-)"') or ""
        local hash = response:match('"hash"%s*:%s*"([^"]-)"') or ""

        -- Use data-saver for Vita's limited bandwidth
        local index = 1
        for filename in response:gmatch('"dataSaver"%s*:%s*%[(.-)%]') do
            for file in filename:gmatch('"([^"]-)"') do
                Table[index] = {
                    Link = baseUrl .. "/data-saver/" .. hash .. "/" .. file,
                    Page = index
                }
                index = index + 1
                coroutine.yield(false)
            end
        end
    end

    function MangaDex3:loadChapterPage(link, Table)
        Table.Link = link.Link
    end
end
