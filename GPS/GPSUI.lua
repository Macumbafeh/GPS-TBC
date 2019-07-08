local GPSUIData = {}
local GPSUISearchBuffer = {}
local GPSUIFunData = {}

-- global for xml
GPSUIClicked = false
GPSUIMouseover = true
GPSUIHighlighted = nil

local BUTTON_NUMBER = 22
local BUTTON_HEIGHT = 16

local BUTTON_COLOR  = {1, 1.0, 1.0, 1.0}
local BUTTON_HCOLOR = {1, 0.8, 0.8, 0.8}


local function GetButton(number)
    return _G['GPSUIEntry'..number]
end

local function SubsequenceSearch(text, what)
    if not what or what == '' then
        return true
    end

    local t_len = string.len(text)
    local w_len = string.len(what)

    if t_len < w_len then
        return false
    end

    text, what = text:lower(), what:lower()
    j = 1

    for i=1, t_len do
        if j == w_len then
            return true
        end

        if text:sub(i, i) == what:sub(j, j) then
            j = j + 1
        end
    end

    return false
end

local function AttachHighlight(frame)
    GPSUIHighlightFrame:ClearAllPoints()
    GPSUIHighlightFrame:SetPoint('TOPLEFT', frame, 'TOPLEFT')
    GPSUIHighlightFrame:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT')
    GPSUIHighlightFrame:Show()
end

function GPSUIOnLoad()
    for i=1, BUTTON_NUMBER do
        local button = GetButton(i)
        local font = button:CreateFontString()

        font:SetFont('Fonts/FRIZQT__.TTF', 12)
        font:SetPoint('TOPLEFT', button, 'TOPLEFT', 7, -3)

        button:SetFontString(font)
        button:SetTextColor(unpack(BUTTON_HCOLOR))
        button:SetScript('OnEnter', function(self)
            self:SetTextColor(unpack(BUTTON_COLOR))

            if GPSUIMouseover then
                SetItemRef(GPSUISearchBuffer[GPSUIFunData[i]].link, nil, 'LeftButton')
                GPSUIHighlightFrame:Hide()
            end
        end)
        button:SetScript('OnClick', function(self, button)
            GPSUIClicked = true

            GPSUIHighlighted = GPSUIFunData[i]
            AttachHighlight(self)

            if not GPSUIMouseover then
                SetItemRef(GPSUISearchBuffer[GPSUIFunData[i]].link, nil, button)
            end

            if button == 'RightButton' then
                GPSUIMouseover = false
            end

            if IsShiftKeyDown() then
                PlaySoundFile('Sound/Interface/Iuiinterfacebuttona.Ogg')

                local num = self:GetName():match('%d+') + FauxScrollFrame_GetOffset(GPSUIScrollBar)
                ChatEdit_InsertLink(GPSUISearchBuffer[num].link)
            end
        end)
    end
end

function GPSUILoadData(data, profession_name, name)
    GPSUIData = data
    GPSUISearchBuffer = data
    GPSUIHighlighted = nil
    GPSUIHeaderText:SetText(profession_name .. ' (' .. name .. ')')

    GPSUIScrollBarUpdate()
end

function GPSOnSearch(text)
    -- default search bar value
    if text == 'search' then return end

    GPSUISearchBuffer = {}
    for _, v in ipairs(GPSUIData) do
        if SubsequenceSearch(v.name, text) then
            GPSUISearchBuffer[#GPSUISearchBuffer+1] = v
        end
    end

    GPSUIScrollBarUpdate()
end

function GPSUIScrollBarUpdate()
    FauxScrollFrame_Update(GPSUIScrollBar, #GPSUISearchBuffer, BUTTON_NUMBER, BUTTON_HEIGHT)

    GPSUIHighlightFrame:Hide()

    for line=1, BUTTON_NUMBER do
        local lineplusoffset = line + FauxScrollFrame_GetOffset(GPSUIScrollBar)
        local button = GetButton(line)

        if lineplusoffset <= #GPSUISearchBuffer then
            if line ~= 1 then
                button:SetPoint('TOPLEFT', GetButton(line-1), 'BOTTOMLEFT', 0, 0)
            end

            if GPSUIHighlighted == lineplusoffset then
                AttachHighlight(button)
            end

            GPSUIFunData[line] = lineplusoffset
            button:SetText(GPSUISearchBuffer[lineplusoffset].name)
            button:Show()
        else
            button:Hide()
        end
    end
end
