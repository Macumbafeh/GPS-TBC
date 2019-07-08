GPS = CreateFrame('Frame')

-- Event registration
GPS.events = {
    ['ADDON_LOADED']        = 'OnLoad',
    ['CHAT_MSG_ADDON']      = 'ChatMsgAddon',
    ['TRADE_SKILL_SHOW']    = 'TradeSkillShow',
    ['CRAFT_SHOW']          = 'CraftShow',
}

GPS.local_cache = {}
GPS.request_timeout = {}
GPS.receive_cache = {}

local DEBUG          = false
local MAGIC_START    = 'GPSS'
local MAGIC_CONTINUE = 'GPSC'
local MAGIC_REQUEST  = 'GPSR'
local END_CONTINUE   = 'EC'
local END_END        = 'EE'
local PROFID_TO_NAME =  {
    a = 'Alchemy',
    t = 'Tailoring',
    h = 'Herbalism',
    m = 'Mining', -- XXX(MarWit): Change this to smelting
    b = 'Blacksmithing',
    e = 'Engineering',
    E = 'Enchanting',
    j = 'Jewelcrafting',
    l = 'Leatherworking',
    f = 'First Aid',
    c = 'Cooking',
}
local NAME_TO_PROFID =  {
    Alchemy        = 'a',
    Tailoring      = 't',
    Herbalism      = 'h',
    Mining         = 'm',
    Blacksmithing  = 'b',
    Engineering    = 'e',
    Enchanting     = 'E',
    Jewelcrafting  = 'j',
    Leatherworking = 'l',
    Cooking        = 'c',
    ['First Aid']  = 'f',
}

local player_name = UnitName('player')

-- Utils
function chunks(tab, size)
    if not size then
        size = 1
    end

    return function(state, nth)
        local a, size = unpack(state)
        local len = #a

        if nth * size <= len then
            local output = {}
            local max = size*(nth+1)
            if max > len then
                max = len
            end

            for i=size*nth+1, max do
                table.insert(output, a[i])
            end

            return nth + 1, output
        end
    end, {tab, size}, 0
end

-- Functions
function GPS:Print(fmt, ...)
    DEFAULT_CHAT_FRAME:AddMessage('|cffff69b4[GPS]|r ' .. fmt:format(...))
end

function GPS:DPrint(...)
    if DEBUG then
        self:Print(...)
    end
end

function GPS:HandleReceive(sender, profid, data, show)
    local key = ('%s-%s'):format(sender, profid)
    self.receive_cache[key].timeout = time() + 1.0  -- TODO(MarWit): Change this to constant

    for i=1,#data do
        table.insert(self.receive_cache[key], data[i])
    end

    if #data > 500 then                             -- TODO(MarWit): Change this to constant (maximum amount recipes)
        self.recive_cache[key] = nil
    end

    if show then
        local profession_name = PROFID_TO_NAME[profid] or 'Unknown'
        local data = {}

        for _, v in ipairs(self.receive_cache[key]) do
            local name = GetSpellInfo(v) or 'Unknown'
            table.insert(data, {link = ('|cffffd000|Henchant:%d|h[%s: %s]|h|r'):format(v, profession_name, name), v, name = name})
        end

        self.receive_cache[key] = nil

        GPSUILoadData(data, profession_name, sender)
        GPSUI:Show()
    end
end

function GPS:AddLinkButton(frame)
    local button = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate')

    button:SetPoint('TOP', frame, 'TOP', -95, -15)
    button:SetWidth(50)
    button:SetHeight(18)
    button:SetText('Share')
    button:Enable()

    button:SetScript('OnClick', function()
        GPS:LinkButtonPressed(frame)
    end)
end

function GPS:LinkButtonPressed(frame)
    local data, profid = {}
    local num, GetInfo, GetRecipeLink

    if frame == TradeSkillFrame then
        num = GetNumTradeSkills()
        GetInfo = GetTradeSkillInfo
        GetRecipeLink = GetTradeSkillRecipeLink
    else
        num = GetNumCrafts()
        GetInfo = GetCraftInfo
        GetRecipeLink = GetCraftRecipeLink
        profid = 'E' -- the only craft profession is Enchanting
    end

    for i=1,num do
       local name, type_ = GetInfo(i)
       if name and type_ ~= 'header' then
            local enchant_string, recipe_name = GetRecipeLink(i):match('^|%x+|H(.+)|h%[(.+)%]')
            data[#data+1] = tonumber(enchant_string:match('%d+'))

            if not profid then
                local profession_name = recipe_name:match('(.+):')
                profid = NAME_TO_PROFID[profession_name]
            end
       end
    end

    if profid then
        self.local_cache[profid] = data
    else
        return
    end

    local profession_name = PROFID_TO_NAME[profid]
    local profession_id = tonumber(GetSpellLink(profession_name):match('|Hspell:(%d+)') or 0)
    ChatEdit_InsertLink(
        ('|cff71d5ff|Hspell:%d|h[%s :: %s]|h|r'):format(profession_id, profession_name, player_name)
    )
end

function GPS:SendProfessionData(profid, receiver)
    if not self.local_cache[profid] then
        return
    end

    local max_per_message = math.floor((0xff - (
                string.len(MAGIC_START) +
                1 + -- '\t' symbol
                1 + -- profession symbol
                2 + -- length of data (int16 == 2 bytes)
                string.len(END_END))) / 2)

    local data = {}
    for _, v in ipairs(self.local_cache[profid]) do
        data[#data+1] = {v, 'int16'}
    end

    local chunks_num = math.ceil(#data / max_per_message)
    for i, v in chunks(data, max_per_message) do
        v[#v+1] = (i == chunks_num) and END_END or END_CONTINUE

        local message = GPS_Serializer:serialize(profid, {#v - 1, 'int16'}, unpack(v))
        SendAddonMessage((i > 1) and MAGIC_CONTINUE or MAGIC_START, message, 'WHISPER', receiver)
    end
end

-- Events
function GPS:OnLoad(name)
    if name == 'GPS' then
        self:UnregisterEvent('ADDON_LOADED')

        -- Rest of addon initialization
        self:Print('Loaded!')
        self:SetScript('OnUpdate', self.OnUpdate)
    end
end

function GPS:TradeSkillShow()
    self:AddLinkButton(TradeSkillFrame)
    self:UnregisterEvent('TRADE_SKILL_SHOW')
end

function GPS:CraftShow()
    self:AddLinkButton(CraftFrame)
    self:UnregisterEvent('CRAFT_SHOW')

end

function GPS:ChatMsgAddon(prefix, message, type_, sender)
    if player_name == sender or type_ ~= 'WHISPER' then return end
    if prefix == MAGIC_START then
        local profid, len, tail = GPS_Serializer:deserialize(message, 'char', 'int16')

        local ids = {GPS_Serializer:deserialize(tail, {'int16', len})}
        local end_ = ids[#ids]
        ids[#ids] = nil

        if end_ ~= END_END and end_ ~= END_CONTINUE then
            return
        end

        self.receive_cache[('%s-%s'):format(sender, profid)] = {}
        self:HandleReceive(sender, profid, ids, end_ == END_END)
    end
    if prefix == MAGIC_CONTINUE then
        local profid, len, tail = GPS_Serializer:deserialize(message, 'char', 'int16')
        if not self.receive_cache[('%s-%s'):format(sender, profid)] then
            return
        end

        local ids = {GPS_Serializer:deserialize(tail, {'int16', len})}
        local end_ = ids[#ids]
        ids[#ids] = nil

        if end_ ~= END_END and end_ ~= END_CONTINUE then
            return
        end

        self:HandleReceive(sender, profid, ids, end_ == END_END)
    end
    if prefix == MAGIC_REQUEST then
        if self.request_timeout[sender] then
            return
        end

        self.request_timeout[sender] = time() + 1.0 -- TODO(MarWit): Change this to constant

        local profid = GPS_Serializer:deserialize(message, 'char', END_END)
        local profession_name = PROFID_TO_NAME[profid] or 'Unknown'

        self:DPrint('Got request for %s (profid: %s) from %s!', profession_name, profid, sender)
        self:SendProfessionData(profid, sender)
    end
end

-- Hooks
local origChatFrame_OnHyperlinkShow = ChatFrame_OnHyperlinkShow
function ChatFrame_OnHyperlinkShow(...)
    local label = select(2, ...)
    local profession_name, player = label:match('%[(.+) :: (.+)%]')

    if player ~= nil then
        if IsModifiedClick('CHATLINK') then
            ChatEdit_InsertLink(label)
            return
        end

        if player == player_name then
            return
        end

        local profid = NAME_TO_PROFID[profession_name]

        -- TODO(MarWit): Check if player is connected
        -- NOTE(MarWit): UnitIsConnected doesn't work
        if profid then
            GPS:DPrint('Requested %s (profid: %s) from %s!',
                profession_name, profid, player)

            local message = GPS_Serializer:serialize(profid, END_END)
            SendAddonMessage(MAGIC_REQUEST, message, 'WHISPER', player);
        end

        return
    end

    return origChatFrame_OnHyperlinkShow(...)
end

-- SetScript functions
function GPS:OnEvent(event, ...)
    self[self.events[event]](self, ...)
end

function GPS:OnUpdate(elapsed)
    if not self.__last_update then
        self.__last_update = 0
    end

    self.__last_update = self.__last_update + elapsed
    if self.__last_update < 1.0 then -- TODO(MarWit): Change this to constant
        return
    end

    self.__last_update = 0

    local timestamp = time()
    for k, v in pairs(self.request_timeout) do
        if v < timestamp then
            self.request_timeout[k] = nil
        end
    end

    for k, v in pairs(self.receive_cache) do
        if v.timeout < timestamp then
            self.receive_cache[k] = nil
        end
    end
end

-- Now we're ready to go!
GPS:SetScript('OnEvent', GPS.OnEvent)
for ev, _ in pairs(GPS.events) do
    GPS:RegisterEvent(ev)
end
