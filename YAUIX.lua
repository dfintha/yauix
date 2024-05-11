-- Globals

local YAUIX_CurrentItemBagIndex = nil;
local YAUIX_CurrentItemSlotIndex = nil;
local YAUIX_InMerchantFrame = false;

-- Utility Functions

local function YAUIX_AbbreviateNumber(number)
    if number > 1000000 then
        return string.format("%.01fM", number / 1000000);
    elseif number > 1000 then
        return string.format("%.01fK", number / 1000);
    end
    return string.format("%d", number);
end

local function YAUIX_MakeFontStringInvisible(element)
    if element then
        element:SetFont("Fonts\\FRIZQT__.TTF", 0.1, "");
    end
end

local function YAUIX_InitializeBarOverlay(overlay, parent, anchor, font, size)
    overlay:SetParent(parent);
    overlay:SetFont(font, size, "OUTLINE");
    overlay:SetTextColor(1, 1, 1, 1);
    overlay:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0);
    overlay:SetWidth(anchor:GetWidth());
    overlay:SetHeight(anchor:GetHeight());
    overlay:SetJustifyH("CENTER");
    overlay:SetJustifyV("CENTER");
end

-- Callbacks

local function YAUIX_DisplayRequiredKillCountToLevelUp(text)
    if UnitLevel("player") == 60 then
        return;
    end
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

local function YAUIX_UpdateUnitTooltip(tooltip)
    local unit = select(2, tooltip:GetUnit());

    local guid = UnitGUID(unit);
    if string.sub(guid, 1, 9) == "Creature-" then
        local regex = "-%d+-%d+-%d+-%d+-(%d+)-%d+";
        local id = select(3, string.find(guid, regex));
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
    end

    local family = UnitCreatureFamily(unit);
    if family then
        GameTooltip:AddLine("Creature Family: " .. family, 1, 1, 1);
    end
    GameTooltip:Show();
end

local function YAUIX_UpdateItemTooltip(tooltip)
    if YAUIX_InMerchantFrame then
        return;
    end

    local link = select(2, tooltip:GetItem());
    local _, _, _, level, _, type, _, _, slot, _, price = GetItemInfo(link);

    if select(1, tooltip:GetItem()) == "" then
        return;
    end

    local id = string.sub(link, 18, string.len(link));
    id = string.sub(id, 1, string.find(id, ":") - 1);
    for i = 1, select("#", tooltip:GetRegions()) do
        local region = select(i, tooltip:GetRegions());
        if region and region:GetObjectType() == "FontString" then
            local tag = "[" .. id .. "]";
            local text = region:GetText();
            if text and not string.find(text, tag) then
                region:SetText(text .. " " .. tag);
            end
            break;
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
    local recipe = type == "Recipe";
    if (unequippable and unsellable) or recipe then
        return
    end

    GameTooltip:AddLine(" ", 1, 1, 1);

    -- Sell Price
    if not unsellable then
        local text = "Sell Price: ";
        text = text .. GetCoinTextureString(price);
        if count > 1 then
            price = price * count;
            text = text .. " (x" .. count .. ": " ..
                   GetCoinTextureString(price) .. ")";
        end
        GameTooltip:AddLine(text, 1, 1, 1);
    end

    -- Item Level
    if not unequippable then
        GameTooltip:AddLine("Item Level: " .. level, 1, 1, 1);
    end

    GameTooltip:Show();
end

local function YAUIX_UpdateQuestTracker()
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
                local text = _G["QuestWatchLine" .. line];
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
                local done = select(3, GetQuestLogLeaderBoard(j, index));
                local text = _G["QuestWatchLine" .. line];
                text:SetFont("Fonts\\FRIZQT__.TTF", 13, "");
                text:SetText("   " .. string.sub(text:GetText(), 3));
                if done and done == true then
                    text:SetTextColor(1, 1, 1, 1);
                else
                    text:SetTextColor(0.75, 0.75, 0.75, 1);
                end
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

local function YAUIX_SetCurrentItem(self)
    YAUIX_CurrentItemBagIndex = self:GetParent():GetID();
    YAUIX_CurrentItemSlotIndex = self:GetID();
end

local function YAUIX_ClearCurrentItem(self)
    YAUIX_CurrentItemBagIndex = nil;
    YAUIX_CurrentItemSlotIndex = nil;
end

local function YAUIX_FormatHealthBar(unit, parent, short, size)
    if not parent.HealthOverlay then
        parent.HealthOverlay =
            parent:CreateFontString(
                "HealthOverlayFontString",
                "OVERLAY"
            );
        YAUIX_InitializeBarOverlay(
            parent.HealthOverlay,
            parent,
            parent,
            "Fonts\\FRIZQT__.TTF",
            size
        );
    end

    if not UnitGUID(unit) then
        return;
    end

    local current = UnitHealth(unit);
    local total = UnitHealthMax(unit);
    local percent = math.floor(current / total * 100);

    local text = "";
    local player = UnitIsPlayer(unit) and
                   (UnitGUID(unit) ~= UnitGUID("player"));
    local pet = string.sub(UnitGUID(unit), 1, 4) == "Pet-" and
                (UnitGUID(unit) ~= UnitGUID("playerpet"));

    if current == 0 then
        text = "";
    elseif player or pet then
        text = percent .. "%";
    else
        text = YAUIX_AbbreviateNumber(current);
        if not short then
            text = text .. "/" .. YAUIX_AbbreviateNumber(total);
        end
        text = text .. " (" .. percent .. "%)";
    end

    parent.HealthOverlay:SetText(text);
end

local function YAUIX_FormatResourceBar(unit, parent, short, size)
    if not parent.ResourceOverlay then
        parent.ResourceOverlay =
            parent:CreateFontString(
                "ResourceOverlayFontString",
                "OVERLAY"
            );
        YAUIX_InitializeBarOverlay(
            parent.ResourceOverlay,
            parent,
            parent,
            "Fonts\\FRIZQT__.TTF",
            size
        );
    end

    if not UnitGUID(unit) then
        return;
    end

    local type = select(2, UnitPowerType(unit));
    local current = UnitPower(unit);
    local total = UnitPowerMax(unit);
    local percent = math.floor(current / total * 100);

    local text = YAUIX_AbbreviateNumber(current);
    if not short then
        text = text .. "/" .. YAUIX_AbbreviateNumber(total);
    end

    if total == 0 then
        text = "";
    elseif (type == "MANA") then
        text = text .. " (" .. percent .. "%)";
    end

    parent.ResourceOverlay:SetText(text);
end

local function YAUIX_UpdateTargetFrame(self)
    YAUIX_FormatHealthBar("target", TargetFrameHealthBar, false, 9.5);
    YAUIX_FormatResourceBar("target", TargetFrameManaBar, false, 9.5);
end

local function YAUIX_UpdateQuestLog()
    if UnitLevel("player") == 60 then
        return;
    end

    local parent = QuestLogDetailScrollChildFrame;
    if not parent.ExperienceRewardFontString then
        parent.ExperienceRewardFontString = parent:CreateFontString(
            "ExperienceRewardFontString",
            "BACKGROUND"
        );
    end

    local id = GetQuestLogSelection();
    local choice = GetNumQuestLogChoices(id);
    local fixed = GetNumQuestLogRewards();
    local money = GetQuestLogRewardMoney();

    local anchor = QuestLogQuestDescription;
    if QuestLogSpellLearnText:IsVisible() then
        for i = 1, 9 do
            local attempt = _G["QuestLogItem" .. i .. "IconTexture"];
            if attempt and attempt:IsVisible() then
                anchor = _G["QuestLogItem" .. i .. "IconTexture"];
            end
        end
    elseif fixed > 0 then
        local index = fixed;
        if (index % 2 == 0) then
            index = index - 1;
        end
        anchor = _G["QuestLogItem" .. (index) .. "IconTexture"];
    elseif choice == 0 and money > 0 then
        anchor = QuestLogItemReceiveText;
    elseif choice > 0 and money == 0 then
        local index = fixed + choice;
        if (choice % 2 == 0) then
            index = index - 1;
        end
        anchor = _G["QuestLogItem" .. index .. "IconTexture"];
    elseif money > 0 then
        anchor = QuestLogItemReceiveText;
    end

    if not anchor then
        return;
    end

    local experience = GetQuestLogRewardXP();
    local text = parent.ExperienceRewardFontString;
    text:SetParent(parent);
    text:SetFont(QuestLogQuestDescription:GetFont());
    text:SetText("You will receive " .. experience .. " experience.");
    text:SetTextColor(0.40, 0.0, 0.35, 1);
    text:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10);
    text:SetWidth(QuestLogQuestDescription:GetWidth());
    text:SetHeight(30);
    text:SetJustifyH("LEFT");
    text:SetJustifyV("TOP");
end

local function YAUIX_UpdateCoordinateFontString()
    if not YAUIX_CoordinateFontString then
        YAUIX_CoordinateFontString = UIParent:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontHighlight"
        );
        YAUIX_CoordinateFontString:SetPoint("BOTTOMRIGHT", -10, 12);
        YAUIX_CoordinateFontString:SetFont("Fonts\\FRIZQT__.TTF", 12.5, "OUTLINE");
        YAUIX_CoordinateFontString:SetTextColor(1, 1, 1, 1);
    end

    local map = C_Map.GetBestMapForUnit("player");
    if not map then
        YAUIX_CoordinateFontString:Hide();
        return;
    end

    local position = C_Map.GetPlayerMapPosition(map, "player");
    local x, y = position:GetXY();
    local text = string.format("%.01f, %.01f", x * 100, y * 100);
    YAUIX_CoordinateFontString:SetText(text);
    YAUIX_CoordinateFontString:Show();
end

local function YAUIX_ReplaceXPBarText()
    if UnitLevel("player") == 60 then
        return;
    end

    local bar = MainMenuExpBar;
    if not bar.DetailsFontString then
        bar.DetailsFontString = bar:CreateFontString("DetailsFontString");
        YAUIX_InitializeBarOverlay(
            bar.DetailsFontString,
            MainMenuBarOverlayFrame,
            MainMenuExpBar,
            "Fonts\\ARIALN.ttf",
            12.5
        );
    end

    local current = UnitXP("player");
    local required = UnitXPMax("player");
    local percent = string.format("%.1f", (current / required) * 100);

    local rested = select(2, GetRestState());
    if not rested then
        rested = "Normal";
    end

    local text = rested .. ": " .. YAUIX_AbbreviateNumber(current) .. " / " ..
                 YAUIX_AbbreviateNumber(required) .. " (" .. percent .. "%)";
    bar.DetailsFontString:SetText(text);
end

local function YAUIX_ReplaceReputationBarText()
    local bar = ReputationWatchBar;
    if not bar.DetailsFontString then
        bar.DetailsFontString = bar:CreateFontString("DetailsFontString");
        YAUIX_InitializeBarOverlay(
            bar.DetailsFontString,
            bar.OverlayFrame,
            bar.OverlayFrame,
            "Fonts\\ARIALN.ttf",
            12
        );

        bar.DetailsFontString:SetPoint(
            "TOPLEFT",
            bar.OverlayFrame,
            "TOPLEFT",
            0,
            2
        );
    end

    local name, standing, min, max, value = GetWatchedFactionInfo();

    if not name then
        return;
    end;

    local current = value - min;
    local needed = max - min;
    local percent = string.format("%.01f", (current / needed) * 100);

    if standing == 1 then
        standing = "Hated";
    elseif standing == 2 then
        standing = "Hostile";
    elseif standing == 3 then
        standing = "Unfriendly";
    elseif standing == 4 then
        standing = "Neutral";
    elseif standing == 5 then
        standing = "Friendly";
    elseif standing == 6 then
        standing = "Honored";
    elseif standing == 7 then
        standing = "Revered";
    elseif standing == 8 then
        standing = "Exalted";
    else
        standing = "Unknown";
    end

    local text = standing .. " with " .. name .. ": " .. current .. " / " ..
                 needed .. " (" .. percent .. "%)";
    bar.DetailsFontString:SetText(text);
end

local function YAUIX_ShowOrHideBarOverlays()
    local visible = WorldMapFrame:IsVisible();
    local maximized = WorldMapFrame:IsMaximized();

    if visible and maximized then
        if ReputationWatchBar and ReputationWatchBar.DetailsFontString then
            ReputationWatchBar.DetailsFontString:Hide();
        end
        if MainMenuExpBar and MainMenuExpBar.DetailsFontString then
            MainMenuExpBar.DetailsFontString:Hide();
        end
    else
        if ReputationWatchBar and ReputationWatchBar.DetailsFontString then
            ReputationWatchBar.DetailsFontString:Show();
        end
        if MainMenuExpBar and MainMenuExpBar.DetailsFontString then
            MainMenuExpBar.DetailsFontString:Show();
        end
    end
end

local function YAUIX_UpdateNameplates(token, driver)
    local nameplates = C_NamePlate.GetNamePlates(true);
    local count = table.getn(nameplates);
    if count == 0 then
        return;
    end

    for _, nameplate in pairs(nameplates) do
        local unit = nameplate.UnitFrame.displayedUnit;
        local level = UnitLevel(unit);
        local classification = UnitClassification(unit);

        local parent = nameplate.UnitFrame;
        local text = parent.ClassificationText;
        if not text then
            text = parent:CreateFontString("ClassificationText", "OVERLAY");
            if not text then
                return;
            end
            parent.ClassificationText = text;
        end

        text:SetParent(nameplate.UnitFrame);
        text:SetWidth(parent:GetWidth());
        text:SetHeight(parent.name:GetHeight());
        text:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, parent.name:GetHeight() - 2);
        text:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE");
        text:SetJustifyH("CENTER");
        text:SetJustifyV("TOP");

        if (classification == "worldboss") then
            text:SetTextColor(1, 1, 0, 1);
            text:SetText("(Boss)");
        elseif (classification == "elite") then
            text:SetTextColor(1, 1, 0, 1);
            text:SetText("(Elite)");
        elseif (classification == "rareelite") then
            text:SetTextColor(0.5, 0.5, 0.5, 1);
            text:SetText("(Rare Elite)");
        elseif (classification == "rare") then
            text:SetTextColor(0.5, 0.5, 0.5, 1);
            text:SetText("(Rare)");
        else
            text:SetTextColor(1, 1, 1, 1);
            text:SetText("");
        end
    end
end

-- Entry Point and Event Dispatch

local function YAUIX_InitializeUIElements()
    YAUIX_MakeFontStringInvisible(PlayerFrameHealthBar.LeftText);
    YAUIX_MakeFontStringInvisible(PlayerFrameHealthBar.RightText);
    YAUIX_MakeFontStringInvisible(PlayerFrameHealthBarText);
    YAUIX_FormatHealthBar("player", PlayerFrameHealthBar, false, 9.5);

    YAUIX_MakeFontStringInvisible(PlayerFrameManaBar.LeftText);
    YAUIX_MakeFontStringInvisible(PlayerFrameManaBar.RightText);
    YAUIX_MakeFontStringInvisible(PlayerFrameManaBarText);
    YAUIX_FormatResourceBar("player", PlayerFrameManaBar, false, 9.5);

    YAUIX_MakeFontStringInvisible(PetFrameHealthBarTextLeft);
    YAUIX_MakeFontStringInvisible(PetFrameHealthBarTextRight);
    YAUIX_MakeFontStringInvisible(PetFrameHealthBarText);
    YAUIX_FormatHealthBar("playerpet", PetFrameHealthBar, true, 8);
    PetFrameHealthBar.HealthOverlay:SetParent(PetFrameHealthBarText:GetParent());

    YAUIX_MakeFontStringInvisible(PetFrameManaBarTextLeft);
    YAUIX_MakeFontStringInvisible(PetFrameManaBarTextRight);
    YAUIX_MakeFontStringInvisible(PetFrameManaBarText);
    YAUIX_FormatResourceBar("playerpet", PetFrameManaBar, true, 8);
    PetFrameManaBar.ResourceOverlay:SetParent(PetFrameManaBarText:GetParent());

    YAUIX_MakeFontStringInvisible(MainMenuBarExpText);
    YAUIX_MakeFontStringInvisible(ReputationWatchBar.OverlayFrame.Text);
end

function YAUIX_Initialize(self)
    self:RegisterEvent("UNIT_HEALTH_FREQUENT");
    self:RegisterEvent("UNIT_POWER_FREQUENT");
    self:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN");
    self:RegisterEvent("PLAYER_ENTERING_WORLD");
    self:RegisterEvent("MERCHANT_SHOW");
    self:RegisterEvent("MERCHANT_CLOSED");

    self:SetScript("OnUpdate", YAUIX_UpdateCoordinateFontString);

    hooksecurefunc("QuestWatch_Update", YAUIX_UpdateQuestTracker);
    hooksecurefunc("ContainerFrameItemButton_OnEnter", YAUIX_SetCurrentItem);
    hooksecurefunc("ContainerFrameItemButton_OnLeave", YAUIX_ClearCurrentItem);
    hooksecurefunc("TargetFrame_Update", YAUIX_UpdateTargetFrame);
    hooksecurefunc("QuestLog_UpdateQuestDetails", YAUIX_UpdateQuestLog);
    hooksecurefunc("ExpBar_Update", YAUIX_ReplaceXPBarText);
    hooksecurefunc("ExpBar_Update", YAUIX_ReplaceReputationBarText);
    hooksecurefunc("ToggleWorldMap", YAUIX_ShowOrHideBarOverlays);
    hooksecurefunc("OpenWorldMap", YAUIX_ShowOrHideBarOverlays);
    hooksecurefunc(WorldMapFrame, "Maximize", YAUIX_ShowOrHideBarOverlays);
    hooksecurefunc(WorldMapFrame, "Minimize", YAUIX_ShowOrHideBarOverlays);

    WorldMapFrame:HookScript("OnHide", YAUIX_ShowOrHideBarOverlays);

    GameTooltip:HookScript("OnTooltipSetUnit", YAUIX_UpdateUnitTooltip);
    GameTooltip:HookScript("OnTooltipSetItem", YAUIX_UpdateItemTooltip);

    WorldFrame:HookScript("OnUpdate", YAUIX_UpdateNameplates);

    YAUIX_InitializeUIElements();
end

function YAUIX_HandleIncomingEvent(self, event, ...)
    local arg1, arg2, arg3, arg4, arg5, arg6 = ...;
    if event == "UNIT_HEALTH_FREQUENT" then
        YAUIX_FormatHealthBar("target", TargetFrameHealthBar, false, 9.5);
        YAUIX_FormatHealthBar("player", PlayerFrameHealthBar, false, 9.5);
        YAUIX_FormatHealthBar("playerpet", PetFrameHealthBar, true, 8);
    elseif event == "UNIT_POWER_FREQUENT" then
        YAUIX_FormatResourceBar("target", TargetFrameManaBar, false, 9.5);
        YAUIX_FormatResourceBar("player", PlayerFrameManaBar, false, 9.5);
        YAUIX_FormatResourceBar("playerpet", PetFrameManaBar, true, 8);
    elseif event == "PLAYER_ENTERING_WORLD" then
        YAUIX_FormatHealthBar("player", PlayerFrameHealthBar, false, 9.5);
        YAUIX_FormatResourceBar("player", PlayerFrameManaBar, false, 9.5);
        YAUIX_FormatHealthBar("playerpet", PetFrameHealthBar, true, 8);
        YAUIX_FormatResourceBar("playerpet", PetFrameManaBar, true, 8);
    elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
        YAUIX_DisplayRequiredKillCountToLevelUp(arg1);
    elseif event == "MERCHANT_SHOW" then
        YAUIX_InMerchantFrame = true;
    elseif event == "MERCHANT_CLOSED" then
        YAUIX_InMerchantFrame = false;
    end
end
