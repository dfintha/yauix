local YAUIX_CurrentItemBagIndex = nil;
local YAUIX_CurrentItemSlotIndex = nil;

local function YAUIX_OnChatMsgCombatXPGain(self, text, ...)
    if not string.find(text, "dies, you gain") then
        return;
    end

    local numbers = {};
    for substring in string.gmatch(text, "%s%d+ experience") do
        for subsubstring in string.gmatch(substring, "%d+") do
            table.insert(numbers, tonumber(subsubstring));
        end
    end

    local gained = numbers[#numbers];
    local current = UnitXP("player");
    local required = UnitXPMax("player");
    local count = math.ceil((required - current) / gained) - 1;

    if count == 1 then
        kills = " kill ";
        are = " is ";
    else
        kills = " kills ";
        are = " are ";
    end

    print(
        "|cFF00FFFFGained " .. gained .. " experience, " .. count .. " more" ..
        kills .. "of this unit" .. are .. "needed to level up."
    );
end

local function YAUIX_OnTooltipSetUnit(tooltip)
    local unit = select(1, tooltip:GetUnit());
    local family = UnitCreatureFamily(unit);
    if family then
        GameTooltip:AddLine("Creature Family: " .. family, 1, 1, 1);
    end
    GameTooltip:Show();
end

local function YAUIX_OnTooltipSetItem(tooltip)
    local link = select(2, tooltip:GetItem())
    local _, _, _, level, _, _, _, _, slot, _, price = GetItemInfo(link);

    local id = string.sub(link, 18, string.len(link));
    id = string.sub(id, 1, string.find(id, ":") - 1);
    for i = 1, select("#", tooltip:GetRegions()) do
        local region = select(i, tooltip:GetRegions());
        if region and region:GetObjectType() == "FontString" then
            local text = region:GetText();
            if text then
                region:SetText(text .. " [" .. id .. "]");
                break;
            end
        end
    end

    local count = 0;
    if YAUIX_CurrentItemBagIndex and YAUIX_CurrentItemSlotIndex then
        local info = C_Container.GetContainerItemInfo(
            YAUIX_CurrentItemBagIndex,
            YAUIX_CurrentItemSlotIndex
        );
        count = info.stackCount;
    else
        count = 1;
    end

    local unsellable = not price or price == 0 or count == 0;
    local unequippable = not level or slot == "INVTYPE_NON_EQUIP_IGNORE";
    if unequippable and unsellable then
        return
    end

    GameTooltip:AddLine(" ", 1, 1, 1);

    -- Item Level
    if slot ~= "INVTYPE_NON_EQUIP_IGNORE" and not unequippable then
        GameTooltip:AddLine("Item Level: " .. level, 1, 1, 1);
    end

    -- Sell Price
    if not unsellable then
        local text = "Sell Price: ";
        text = text .. GetCoinTextureString(price);
        if count > 1 then
            price = price * count;
            text = text .. " (" .. GetCoinTextureString(price) ..
                   " for this stack of " .. count .. ")";
        end
        GameTooltip:AddLine(text, 1, 1, 1);
    end

    GameTooltip:Show();
end

local function YAUIX_QuestWatch_Update()
    local line = 1;
    for i = 1, GetNumQuestWatches() do
        local index = GetQuestIndexForWatch(i);
        if index then
            local objectives = GetNumQuestLeaderBoards(index);
            local _, level, group, _ = GetQuestLogTitle(index);
            local questTextColor = GetQuestDifficultyColor(level);

            local prefix = "[" .. level;
            if group then
                prefix = prefix .. string.sub(group, 1, 1)
            end
            prefix = prefix .. "] ";

            -- Title
            if objectives > 0 then
                text = _G["QuestWatchLine" .. line];
                text:SetFont("Fonts\\FRIZQT__.TTF", 15, "");
                text:SetText(prefix .. text:GetText());
                text:SetTextColor(
                    questTextColor.r,
                    questTextColor.g,
                    questTextColor.b
                );
                if line > 2 then
                    text:SetPoint(
                        "TOPLEFT",
                        "QuestWatchLine" .. (line - 1),
                        "BOTTOMLEFT",
                        0,
                        -12
                    );
                end
                line = line + 1;
            end

            -- Objectives
            for j = 1, objectives do
                text = _G["QuestWatchLine" .. line];
                text:SetFont("Fonts\\FRIZQT__.TTF", 13, "");
                text:SetText("   " .. string.sub(text:GetText(), 3));
                text:SetTextColor(1, 1, 1, 1);
                text:SetPoint(
                    "TOPLEFT",
                    "QuestWatchLine" .. (line - 1),
                    "BOTTOMLEFT",
                    0,
                    -6
                );
                line = line + 1;
            end
        end
    end
end

local function YAUIX_ContainerFrameItemButton_OnEnter(self)
    YAUIX_CurrentItemBagIndex = self:GetParent():GetID();
    YAUIX_CurrentItemSlotIndex = self:GetID();
end

local function YAUIX_ContainerFrameItemButton_OnLeave(self)
    YAUIX_CurrentItemBagIndex = nil;
    YAUIX_CurrentItemSlotIndex = nil;
end

local function YAUIX_AbbreviateNumber(number)
    suffix = "";
    if number > 1000000 then
        number = math.floor(number / 100000) / 10;
        suffix = "M";
    elseif number > 1000 then
        number = math.floor(number / 100) / 10;
        suffix = "K";
    end
    return number .. suffix;
end

local function YAUIX_FormatHealthOrResourceBar(overlay, parent, text)
    overlay:SetParent(parent);
    overlay:SetFont("Fonts\\FRIZQT__.TTF", 9.5, "OUTLINE");
    overlay:SetText(text);
    overlay:SetTextColor(1, 1, 1, 1);
    overlay:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0);
    overlay:SetWidth(parent:GetWidth());
    overlay:SetHeight(parent:GetHeight());
    overlay:SetJustifyH("CENTER");
    overlay:SetJustifyV("CENTER");
end

local function YAUIX_FormatTargetHealthBar()
    if not UnitGUID("target") then
        return;
    end

    if not TargetFrameHealthBar.HealthOverlay then
        TargetFrameHealthBar.HealthOverlay =
            TargetFrameHealthBar:CreateFontString(
                "HealthOverlayFontString",
                "OVERLAY"
            );
    end

    local current = UnitHealth("target");
    local total = UnitHealthMax("target");
    local percent = math.floor(current / total * 100);

    local text = "";
    local player = UnitIsPlayer("target") and
                   (UnitGUID("target") ~= UnitGUID("player"));
    local pet = string.sub(UnitGUID("target"), 1, 4) == "Pet-" and
                (UnitGUID("target") ~= UnitGUID("playerpet"));

    if current == 0 then
        text = "";
    elseif player or pet then
        text = percent .. "%";
    else
        text = YAUIX_AbbreviateNumber(current) .. "/" ..
               YAUIX_AbbreviateNumber(total) .. " (" .. percent .. "%)";
    end

    YAUIX_FormatHealthOrResourceBar(
        TargetFrameHealthBar.HealthOverlay,
        TargetFrameHealthBar,
        text
    );
end

local function YAUIX_FormatTargetResourceBar()
    if not UnitGUID("target") then
        return;
    end

    if not TargetFrameManaBar.ResourceOverlay then
        TargetFrameManaBar.ResourceOverlay =
            TargetFrameManaBar:CreateFontString(
                "ResourceOverlayFontString",
                "OVERLAY"
            );
    end

    local type = select(2, UnitPowerType("target"));
    local current = UnitPower("target");
    local total = UnitPowerMax("target");
    local percent = math.floor(current / total * 100);
    local text = YAUIX_AbbreviateNumber(current) .. "/" ..
                  YAUIX_AbbreviateNumber(total);
    if total == 0 then
        text = "";
    elseif (type == "MANA") then
        text = text .. " (" .. percent .. "%)";
    end

    YAUIX_FormatHealthOrResourceBar(
        TargetFrameManaBar.ResourceOverlay,
        TargetFrameManaBar,
        text
    );
end

local function YAUIX_UpdateTargetFrame(self)
    YAUIX_FormatTargetHealthBar();
    YAUIX_FormatTargetResourceBar();
end

function YAUIX_OnLoad(self)
    self:RegisterEvent("UNIT_HEALTH_FREQUENT");
    self:RegisterEvent("UNIT_POWER_FREQUENT");
    self:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN");

    hooksecurefunc(
        "QuestWatch_Update",
        YAUIX_QuestWatch_Update
    );
    hooksecurefunc(
        "ContainerFrameItemButton_OnEnter",
        YAUIX_ContainerFrameItemButton_OnEnter
    );
    hooksecurefunc(
        "ContainerFrameItemButton_OnLeave",
        YAUIX_ContainerFrameItemButton_OnLeave
    );
    hooksecurefunc(
        "TargetFrame_Update",
        YAUIX_UpdateTargetFrame
    );

    GameTooltip:HookScript("OnTooltipSetUnit", YAUIX_OnTooltipSetUnit);
    GameTooltip:HookScript("OnTooltipSetItem", YAUIX_OnTooltipSetItem);
end

function YAUIX_OnEvent(self, event, ...)
    local arg1, arg2, arg3, arg4, arg5, arg6 = ...;
    if event == "UNIT_HEALTH_FREQUENT" then
        YAUIX_FormatTargetHealthBar();
    elseif event == "UNIT_POWER_FREQUENT" then
        YAUIX_FormatTargetResourceBar();
    elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
        YAUIX_OnChatMsgCombatXPGain(self, arg1);
    end
end
