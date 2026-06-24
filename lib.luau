repeat task.wait() until game:IsLoaded()

local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local folder = "zenware_configs"
local fonts = { UI = Enum.Font.Gotham, Mono = Enum.Font.Code }
local accent_objects = { bg = {}, text = {}, gradient = {} }

local function rgba(c, a)
    return Color3.fromRGB(c.R * 255, c.G * 255, c.B * 255), a or 1
end

local function create(class, props)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do
        pcall(function() obj[k] = v end)
    end
    obj.Name = HttpService:GenerateGUID(false):sub(1, 8)
    return obj
end

local function get_text_size(text, size, font)
    return TextService:GetTextSize(text, size, font or fonts.UI, Vector2.new(2000, 2000))
end

local function tween(obj, info, props)
    local t = TweenService:Create(obj, TweenInfo.new(unpack(info)), props)
    t:Play()
    return t
end

local function lerp_color(a, b, t)
    return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

local function darken(c, amt)
    return Color3.new(math.max(c.R - amt, 0), math.max(c.G - amt, 0), math.max(c.B - amt, 0))
end

local function lighten(c, amt)
    return Color3.new(math.min(c.R + amt, 1), math.min(c.G + amt, 1), math.min(c.B + amt, 1))
end

local Theme = {
    BG = Color3.fromRGB(12, 12, 22),
    Surface = Color3.fromRGB(22, 24, 38),
    SurfaceAlt = Color3.fromRGB(30, 32, 48),
    Border = Color3.fromRGB(42, 44, 62),
    BorderLight = Color3.fromRGB(56, 58, 78),
    Text = Color3.fromRGB(200, 200, 215),
    TextDim = Color3.fromRGB(110, 112, 130),
    Accent = Color3.fromRGB(110, 160, 255),
    AccentDim = Color3.fromRGB(80, 120, 200),
    Danger = Color3.fromRGB(220, 80, 80),
    Success = Color3.fromRGB(80, 200, 120),
}

local flags = {}
local library = { flags = flags, theme = Theme, toggled = true }

local function make_visible(obj, visible)
    if visible then
        obj.Visible = true
        for _, d in pairs(obj:GetDescendants()) do
            if not d:IsA("UIBase") then
                local props = {}
                if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                    props.TextTransparency = 0
                    props.TextStrokeTransparency = 0
                end
                if d:IsA("ImageLabel") then
                    props.ImageTransparency = 0
                end
                props.BackgroundTransparency = d:GetAttribute("BaseTransparency") or 0
                if next(props) then tween(d, {0.15}, props) end
            end
        end
    else
        for _, d in pairs(obj:GetDescendants()) do
            if not d:IsA("UIBase") then
                tween(d, {0.12}, { BackgroundTransparency = 1 })
                if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                    tween(d, {0.12}, { TextTransparency = 1, TextStrokeTransparency = 1 })
                end
                if d:IsA("ImageLabel") then
                    tween(d, {0.12}, { ImageTransparency = 1 })
                end
            end
        end
        task.wait(0.12)
        obj.Visible = false
    end
end

local function new_drag(obj, drag_area)
    local dragging, start, obj_start
    drag_area = drag_area or obj
    drag_area.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            start = input.Position
            obj_start = obj.Position
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            obj.Position = UDim2.new(obj_start.X.Scale, obj_start.X.Offset + (input.Position - start).X, obj_start.Y.Scale, obj_start.Y.Offset + (input.Position - start).Y)
        end
    end)
end

local gui = create("ScreenGui", { ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })

function library:ChangeAccent(color)
    Theme.Accent = color
    Theme.AccentDim = darken(color, 0.15)
    for obj, _ in pairs(accent_objects.bg) do
        pcall(function() obj.BackgroundColor3 = color end)
    end
    for obj, _ in pairs(accent_objects.text) do
        pcall(function() obj.TextColor3 = color end)
    end
end

function library:SaveConfig(name, universal)
    local data = {}
    local place = universal and "universal" or game.PlaceId
    for k, v in pairs(flags) do
        if typeof(v) == "EnumItem" then
            data[k] = tostring(v)
        elseif typeof(v) == "Color3" then
            data[k] = { math.floor(v.R * 255), math.floor(v.G * 255), math.floor(v.B * 255) }
        elseif typeof(v) == "ColorSequence" then
            local keys = {}
            for _, kp in pairs(v.Keypoints) do
                table.insert(keys, { kp.Time, math.floor(kp.Value.R * 255), math.floor(kp.Value.G * 255), math.floor(kp.Value.B * 255) })
            end
            data[k] = keys
        else
            data[k] = v
        end
    end
    local json = HttpService:JSONEncode(data)
    local path = string.format("%s/%s", folder, place)
    if not isfolder(path) then makefolder(path) end
    writefile(string.format("%s/%s.json", path, name), json)
end

function library:LoadConfig(name)
    local place = string.format("%s/%s/%s.json", folder, game.PlaceId, name)
    local uni = string.format("%s/universal/%s.json", folder, name)
    local path = isfile(place) and place or (isfile(uni) and uni)
    if not path then return end
    local data = HttpService:JSONDecode(readfile(path))
    for k, v in pairs(data) do
        local fn = flags[k]
        if fn then fn(v) end
    end
end

function library:ListConfigs()
    local list = {}
    local path = string.format("%s/%s", folder, game.PlaceId)
    if isfolder(path) then
        for _, f in pairs(listfiles(path)) do
            table.insert(list, f:gsub(path .. "\\", ""):gsub(".json", ""))
        end
    end
    return list
end

function library:DeleteConfig(name)
    local path = string.format("%s/%s/%s.json", folder, game.PlaceId, name)
    if isfile(path) then delfile(path) end
end

function library:Watermark(opts)
    local items = opts or {}
    local text = table.concat(items, "  |  ")
    local size = get_text_size(text, 13, fonts.Mono).X + 20
    local watermark = create("TextLabel", {
        ZIndex = 100, Size = UDim2.new(0, size, 0, 22),
        Position = UDim2.new(0, 10, 0, 10), BackgroundTransparency = 1,
        Text = text, TextColor3 = Theme.Accent, TextSize = 13,
        Font = fonts.Mono, TextStrokeTransparency = 0.8,
        RichText = true, Parent = gui,
    })
    table.insert(accent_objects.text, watermark)
    local toggled = true; local busy = false
    local obj = {}
    function obj:Update(new_items)
        items = new_items
        local t = table.concat(items, "  |  ")
        local s = get_text_size(t, 13, fonts.Mono).X + 20
        watermark.Size = UDim2.new(0, s, 0, 22)
        watermark.Text = t
    end
    function obj:Toggle()
        if busy then return end
        busy = true
        toggled = not toggled
        make_visible(watermark, toggled)
        busy = false
    end
    function obj:Remove()
        watermark:Destroy()
    end
    return obj
end

function library:Toggle()
    if library._toggling then return end
    library._toggling = true
    library.toggled = not library.toggled
    if library._main_holder then
        make_visible(library._main_holder, library.toggled)
    end
    library._toggling = false
end

local WindowMethods = {}
WindowMethods.__index = WindowMethods

function library:New(opts)
    opts = opts or {}
    local accent = opts.Accent or Theme.Accent
    Theme.Accent = accent
    Theme.AccentDim = darken(accent, 0.15)
    local sizeX = opts.SizeX or 580
    local sizeY = opts.SizeY or 380
    local name = opts.Name or "zenware"
    local border_size = 1
    local header_h = 28
    local tab_h = 24
    local main_holder = create("Frame", {
        Size = UDim2.new(0, sizeX, 0, sizeY),
        Position = UDim2.new(0.5, -sizeX / 2, 0.5, -sizeY / 2),
        BackgroundTransparency = 1, Parent = gui,
    })
    library._main_holder = main_holder

    local shadow = create("ImageLabel", {
        Size = UDim2.new(1, 40, 1, 40), Position = UDim2.new(0, -20, 0, -20),
        Image = "rbxassetid://1316045217", ImageTransparency = 0.7,
        ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(20, 20, 180, 180),
        BackgroundTransparency = 1, ZIndex = 0, Parent = main_holder,
    })

    local border = create("Frame", {
        Size = UDim2.new(1, border_size * 2, 1, border_size * 2),
        Position = UDim2.new(0, -border_size, 0, -border_size),
        BackgroundColor3 = Theme.Border, BorderSizePixel = 0, ZIndex = 1, Parent = main_holder,
    })

    local bg = create("Frame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Theme.BG,
        BorderSizePixel = 0, ZIndex = 2, Parent = main_holder,
    })

    local title_bar = create("Frame", {
        Size = UDim2.new(1, 0, 0, header_h),
        BackgroundColor3 = Theme.Surface, BorderSizePixel = 0,
        ZIndex = 3, Parent = main_holder,
    })

    local title_border = create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = accent, BorderSizePixel = 0, ZIndex = 4, Parent = title_bar,
    })
    table.insert(accent_objects.bg, title_border)

    local title_text = create("TextLabel", {
        Size = UDim2.new(1, -40, 1, 0), Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1, Text = name, TextColor3 = Theme.Text,
        TextSize = 14, Font = fonts.UI, TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 5, Parent = title_bar,
    })

    local close_btn = create("TextButton", {
        Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(1, -28, 0, 1),
        BackgroundTransparency = 1, Text = "x", TextColor3 = Theme.TextDim,
        TextSize = 15, Font = fonts.UI, ZIndex = 5, Parent = title_bar,
    })
    close_btn.MouseButton1Click:Connect(function()
        library:Toggle()
    end)
    close_btn.MouseEnter:Connect(function()
        tween(close_btn, {0.1}, { TextColor3 = Theme.Danger })
    end)
    close_btn.MouseLeave:Connect(function()
        tween(close_btn, {0.1}, { TextColor3 = Theme.TextDim })
    end)

    new_drag(main_holder, title_bar)

    local tab_bar = create("Frame", {
        Size = UDim2.new(1, 0, 0, tab_h),
        Position = UDim2.new(0, 0, 0, header_h),
        BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0, ZIndex = 3, Parent = main_holder,
    })

    local tab_bar_bottom = create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.Border, BorderSizePixel = 0, ZIndex = 4, Parent = tab_bar,
    })

    local tab_list = create("Frame", {
        Size = UDim2.new(1, -8, 1, 0), Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1, ZIndex = 4, Parent = tab_bar,
    })

    local tab_list_layout = create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2), Parent = tab_list,
    })

    local content_area = create("Frame", {
        Size = UDim2.new(1, -12, 1, -(header_h + tab_h + 6)),
        Position = UDim2.new(0, 6, 0, header_h + tab_h),
        BackgroundTransparency = 1, ZIndex = 3, Parent = main_holder,
    })

    local content_clip = create("Frame", {
        Size = UDim2.new(1, 0, 1, 0), ClipsDescendants = true,
        BackgroundTransparency = 1, ZIndex = 3, Parent = content_area,
    })

    local page_holder = create("Frame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Parent = content_clip,
    })

    local window = setmetatable({
        _holder = main_holder,
        _page_holder = page_holder,
        _tab_bar = tab_list,
        _tab_layout = tab_list_layout,
        _pages = {},
        _current_page = nil,
        _accent = accent,
    }, WindowMethods)

    function window:Toggle()
        library:Toggle()
    end

    return window
end

function WindowMethods:Page(opts)
    opts = opts or {}
    local name = opts.Name or "Page"
    local page_obj = {}
    setmetatable(page_obj, { __index = function(t, k)
        if t._last_section and SectionMethods[k] then
            return function(_, ...)
                return t._last_section[k](t._last_section, ...)
            end
        end
    end })
    local is_first = #self._pages == 0
    local page_frame = create("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = is_first,
        Parent = self._page_holder,
    })
    local page_data = { frame = page_frame }

    local text_size = get_text_size(name, 13, fonts.UI)
    local tab_btn = create("TextButton", {
        Size = UDim2.new(0, text_size.X + 20, 1, 0),
        BackgroundTransparency = 1, Text = "", ZIndex = 5, Parent = self._tab_bar,
    })
    local tab_label = create("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        Text = name, TextColor3 = is_first and Theme.Accent or Theme.TextDim,
        TextSize = 13, Font = fonts.UI, ZIndex = 6, Parent = tab_btn,
    })
    if is_first then table.insert(accent_objects.text, tab_label) end

    local tab_active_line = create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = is_first and Theme.Accent or Theme.Border,
        BorderSizePixel = 0, ZIndex = 6, Parent = tab_btn,
    })
    if is_first then
        table.insert(accent_objects.bg, tab_active_line)
        self._current_page = page_frame
    end
    page_data.tab_btn = tab_btn
    page_data.tab_label = tab_label
    page_data.active_line = tab_active_line

    local function switch_to()
        if self._current_page == page_frame then return end
        for _, p in pairs(self._pages) do
            if p._frame ~= page_frame and p._frame.Visible then
                make_visible(p._frame, false)
                p._frame.Visible = false
                p._tab_label.TextColor3 = Theme.TextDim
                if table.find(accent_objects.text, p._tab_label) then
                    table.remove(accent_objects.text, table.find(accent_objects.text, p._tab_label))
                end
                tween(p._active_line, {0.15}, { BackgroundColor3 = Theme.Border })
            end
        end
        page_frame.Visible = true
        make_visible(page_frame, true)
        tab_label.TextColor3 = Theme.Accent
        if not table.find(accent_objects.text, tab_label) then
            table.insert(accent_objects.text, tab_label)
        end
        tween(tab_active_line, {0.15}, { BackgroundColor3 = Theme.Accent })
        if not table.find(accent_objects.bg, tab_active_line) then
            table.insert(accent_objects.bg, tab_active_line)
        end
        self._current_page = page_frame
    end

    tab_btn.MouseButton1Click:Connect(switch_to)

    local SectionMethods = {}
    function SectionMethods:Label(opts)
        opts = opts or {}
        local text = opts.Name or ""
        local txt = create("TextLabel", {
            Size = UDim2.new(1, -4, 0, 16),
            BackgroundTransparency = 1,
            Text = text, TextColor3 = Theme.TextDim,
            TextSize = 13, Font = fonts.UI,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 7, Parent = self._content,
        })
    end

    function SectionMethods:Button(opts)
        opts = opts or {}
        local label = opts.Name or "Button"
        local cb = opts.Callback or opts.callback or function() end
        local btn = create("TextButton", {
            Size = UDim2.new(1, -4, 0, 22),
            BackgroundColor3 = Theme.SurfaceAlt,
            BorderSizePixel = 0, Text = "", ZIndex = 7,
            Parent = self._content,
        })
        local border = create("Frame", {
            Size = UDim2.new(1, 1, 1, 1),
            Position = UDim2.new(0, -1, 0, -1),
            BackgroundColor3 = Theme.Border, BorderSizePixel = 0,
            ZIndex = 6, Parent = btn,
        })
        local txt = create("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = label, TextColor3 = Theme.Text,
            TextSize = 13, Font = fonts.UI, ZIndex = 8, Parent = btn,
        })
        btn.MouseButton1Click:Connect(cb)
        btn.MouseEnter:Connect(function()
            tween(btn, {0.1}, { BackgroundColor3 = Theme.Surface })
        end)
        btn.MouseLeave:Connect(function()
            tween(btn, {0.1}, { BackgroundColor3 = Theme.SurfaceAlt })
        end)
    end

    function SectionMethods:Toggle(opts)
        opts = opts or {}
        local label = opts.Name or "Toggle"
        local default = opts.Default or false
        local cb = opts.Callback or opts.callback or function() end
        local pointer = opts.Pointer
        if pointer then flags[pointer] = default end
        local state = default
        local holder = create("TextButton", {
            Size = UDim2.new(1, -4, 0, 18),
            BackgroundTransparency = 1, Text = "", ZIndex = 7,
            Parent = self._content,
        })
        local toggle_box = create("Frame", {
            Size = UDim2.new(0, 14, 0, 14),
            Position = UDim2.new(0, 0, 0, 2),
            BackgroundColor3 = state and Theme.Accent or Theme.SurfaceAlt,
            BorderSizePixel = 0, ZIndex = 8, Parent = holder,
        })
        local box_border = create("Frame", {
            Size = UDim2.new(1, 1, 1, 1),
            Position = UDim2.new(0, -1, 0, -1),
            BackgroundColor3 = state and Theme.AccentDim or Theme.Border,
            BorderSizePixel = 0, ZIndex = 7, Parent = toggle_box,
        })
        if state then table.insert(accent_objects.bg, toggle_box) end
        local check = create("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "L", TextColor3 = Theme.BG,
            TextSize = 11, Font = fonts.UI,
            Visible = state, ZIndex = 9, Parent = toggle_box,
        })
        local txt = create("TextLabel", {
            Size = UDim2.new(1, -20, 1, 0),
            Position = UDim2.new(0, 20, 0, 0),
            BackgroundTransparency = 1,
            Text = label, TextColor3 = state and Theme.Accent or Theme.Text,
            TextSize = 13, Font = fonts.UI,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = holder,
        })
        if state then table.insert(accent_objects.text, txt) end

        local function set(v)
            state = v
            if pointer then flags[pointer] = state end
            pcall(cb, state)
            toggle_box.BackgroundColor3 = state and Theme.Accent or Theme.SurfaceAlt
            box_border.BackgroundColor3 = state and Theme.AccentDim or Theme.Border
            check.Visible = state
            txt.TextColor3 = state and Theme.Accent or Theme.Text
            if state then
                if not table.find(accent_objects.bg, toggle_box) then table.insert(accent_objects.bg, toggle_box) end
                if not table.find(accent_objects.text, txt) then table.insert(accent_objects.text, txt) end
            else
                local i = table.find(accent_objects.bg, toggle_box)
                if i then table.remove(accent_objects.bg, i) end
                local j = table.find(accent_objects.text, txt)
                if j then table.remove(accent_objects.text, j) end
            end
        end

        holder.MouseButton1Click:Connect(function()
            set(not state)
        end)
        if pointer then flags[pointer] = set end

        local toggle_obj = { _holder = holder, _set = set }
        function toggle_obj:Toggle(v)
            if v ~= nil then set(v) else set(not state) end
        end

        function toggle_obj:Colorpicker(cp_opts)
            cp_opts = cp_opts or {}
            cp_opts._parent_holder = holder
            cp_opts._z_offset = 18
            local cp = build_colorpicker(cp_opts)
            cp._obj.Parent = holder
            return cp
        end

        return toggle_obj
    end

    function SectionMethods:Slider(opts)
        opts = opts or {}
        local label = opts.Name or "Slider"
        local min = opts.Minimum or opts.Min or 0
        local max = opts.Maximum or opts.Max or 100
        local default = opts.Default or min
        local cb = opts.Callback or opts.callback or function() end
        local pointer = opts.Pointer
        local decimals = opts.Decimals or 1
        if pointer then flags[pointer] = default end

        local value = default
        local holder = create("Frame", {
            Size = UDim2.new(1, -4, 0, 30),
            BackgroundTransparency = 1, ZIndex = 7, Parent = self._content,
        })
        local txt = create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 14),
            BackgroundTransparency = 1,
            Text = label, TextColor3 = Theme.Text,
            TextSize = 13, Font = fonts.UI,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = holder,
        })
        local val_txt = create("TextLabel", {
            Size = UDim2.new(0, 40, 0, 14),
            Position = UDim2.new(1, -40, 0, 0),
            BackgroundTransparency = 1,
            Text = tostring(default), TextColor3 = Theme.Accent,
            TextSize = 12, Font = fonts.Mono,
            TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 8, Parent = holder,
        })
        table.insert(accent_objects.text, val_txt)
        local track = create("Frame", {
            Size = UDim2.new(1, 0, 0, 6),
            Position = UDim2.new(0, 0, 1, -6),
            BackgroundColor3 = Theme.SurfaceAlt,
            BorderSizePixel = 0, ZIndex = 8, Parent = holder,
        })
        local track_border = create("Frame", {
            Size = UDim2.new(1, 1, 1, 1),
            Position = UDim2.new(0, -1, 0, -1),
            BackgroundColor3 = Theme.Border, BorderSizePixel = 0, ZIndex = 7, Parent = track,
        })
        local fill = create("Frame", {
            Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0, ZIndex = 9, Parent = track,
        })
        table.insert(accent_objects.bg, fill)
        local sliding = false

        local function update(input)
            local pos = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            local raw = min + pos * (max - min)
            local step = decimals or 1
            local snapped = math.floor(raw / step + 0.5) * step
            snapped = math.clamp(snapped, min, max)
            value = snapped
            fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
            val_txt.Text = tostring(value)
            if pointer then flags[pointer] = value end
            pcall(cb, value)
        end

        if pointer then
            flags[pointer] = function(v)
                v = math.clamp(v, min, max)
                value = v
                fill.Size = UDim2.new((v - min) / (max - min), 0, 1, 0)
                val_txt.Text = tostring(v)
                pcall(cb, v)
            end
        end

        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                sliding = true; update(input)
            end
        end)
        track.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then update(input) end
        end)
    end

    function SectionMethods:Dropdown(opts)
        opts = opts or {}
        local label = opts.Name or "Dropdown"
        local options = opts.Options or {}
        local default = opts.Default or options[1]
        local cb = opts.Callback or opts.callback or function() end
        local pointer = opts.Pointer
        if pointer then flags[pointer] = default end

        local open = false; local selected = default
        local holder = create("Frame", {
            Size = UDim2.new(1, -4, 0, 34),
            BackgroundTransparency = 1, ZIndex = 7, Parent = self._content,
            ClipsDescendants = true,
        })
        local txt = create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 14),
            BackgroundTransparency = 1,
            Text = label, TextColor3 = Theme.Text,
            TextSize = 13, Font = fonts.UI,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = holder,
        })
        local btn = create("TextButton", {
            Size = UDim2.new(1, 0, 0, 18),
            Position = UDim2.new(0, 0, 0, 16),
            BackgroundColor3 = Theme.SurfaceAlt,
            BorderSizePixel = 0, Text = "", ZIndex = 8, Parent = holder,
        })
        local btn_border = create("Frame", {
            Size = UDim2.new(1, 1, 1, 1),
            Position = UDim2.new(0, -1, 0, -1),
            BackgroundColor3 = Theme.Border, BorderSizePixel = 0, ZIndex = 7, Parent = btn,
        })
        local btn_txt = create("TextLabel", {
            Size = UDim2.new(1, -24, 1, 0),
            Position = UDim2.new(0, 6, 0, 0),
            BackgroundTransparency = 1,
            Text = selected or "None", TextColor3 = Theme.Text,
            TextSize = 12, Font = fonts.UI,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9, Parent = btn,
        })
        local arrow = create("TextLabel", {
            Size = UDim2.new(0, 18, 1, 0),
            Position = UDim2.new(1, -18, 0, 0),
            BackgroundTransparency = 1,
            Text = ">", TextColor3 = Theme.TextDim,
            TextSize = 12, Font = fonts.Mono, ZIndex = 9, Parent = btn,
        })
        local list_frame = create("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            Position = UDim2.new(0, 0, 0, 34),
            BackgroundTransparency = 1, Visible = false,
            ZIndex = 10, Parent = holder,
        })

        local function refresh_options()
            for _, c in pairs(list_frame:GetChildren()) do
                if c:IsA("TextButton") then c:Destroy() end
            end
            for _, opt in pairs(options) do
                local o = create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 20),
                    BackgroundColor3 = opt == selected and Theme.SurfaceAlt or Theme.Surface,
                    BorderSizePixel = 0, Text = "", ZIndex = 11, Parent = list_frame,
                })
                local o_border = create("Frame", {
                    Size = UDim2.new(1, 1, 1, 0),
                    Position = UDim2.new(0, -1, 0, 0),
                    BackgroundColor3 = Theme.Border, BorderSizePixel = 0, ZIndex = 10, Parent = o,
                })
                local ot = create("TextLabel", {
                    Size = UDim2.new(1, -10, 1, 0),
                    Position = UDim2.new(0, 6, 0, 0),
                    BackgroundTransparency = 1,
                    Text = opt, TextColor3 = opt == selected and Theme.Accent or Theme.Text,
                    TextSize = 12, Font = fonts.UI,
                    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, Parent = o,
                })
                o.MouseButton1Click:Connect(function()
                    selected = opt
                    btn_txt.Text = opt
                    if pointer then flags[pointer] = opt end
                    pcall(cb, opt)
                    toggle_open()
                    refresh_options()
                end)
                o.MouseEnter:Connect(function()
                    tween(o, {0.08}, { BackgroundColor3 = Theme.SurfaceAlt })
                end)
                o.MouseLeave:Connect(function()
                    if opt ~= selected then
                        tween(o, {0.08}, { BackgroundColor3 = Theme.Surface })
                    end
                end)
            end
        end

        local function toggle_open()
            open = not open
            arrow.Text = open and "v" or ">"
            list_frame.Visible = open
            if open then
                refresh_options()
                local count = #options
                local list_h = count * 20
                list_frame.Size = UDim2.new(1, 0, 0, list_h)
                holder.Size = UDim2.new(1, -4, 0, 34 + list_h)
                holder.ClipsDescendants = false
            else
                holder.Size = UDim2.new(1, -4, 0, 34)
                task.delay(0.1, function()
                    if not open then holder.ClipsDescendants = true end
                end)
            end
        end

        btn.MouseButton1Click:Connect(toggle_open)
        btn.MouseEnter:Connect(function()
            tween(btn, {0.08}, { BackgroundColor3 = Theme.Surface })
        end)
        btn.MouseLeave:Connect(function()
            tween(btn, {0.08}, { BackgroundColor3 = Theme.SurfaceAlt })
        end)

        if pointer then
            flags[pointer] = function(v)
                selected = v
                btn_txt.Text = v
                pcall(cb, v)
                refresh_options()
            end
        end

        refresh_options()
    end

    function SectionMethods:MultiDropdown(opts)
        opts = opts or {}
        local label = opts.Name or "MultiSelect"
        local options = opts.Options or {}
        local default = opts.Default or {}
        local cb = opts.Callback or opts.callback or function() end
        local pointer = opts.Pointer
        local selected_set = {}
        for _, v in pairs(default) do selected_set[v] = true end
        if pointer then flags[pointer] = default end

        local open = false
        local holder = create("Frame", {
            Size = UDim2.new(1, -4, 0, 34),
            BackgroundTransparency = 1, ZIndex = 7, Parent = self._content,
            ClipsDescendants = true,
        })
        local txt = create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 14),
            BackgroundTransparency = 1,
            Text = label, TextColor3 = Theme.Text,
            TextSize = 13, Font = fonts.UI,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = holder,
        })
        local btn = create("TextButton", {
            Size = UDim2.new(1, 0, 0, 18),
            Position = UDim2.new(0, 0, 0, 16),
            BackgroundColor3 = Theme.SurfaceAlt,
            BorderSizePixel = 0, Text = "", ZIndex = 8, Parent = holder,
        })
        local btn_border = create("Frame", {
            Size = UDim2.new(1, 1, 1, 1),
            Position = UDim2.new(0, -1, 0, -1),
            BackgroundColor3 = Theme.Border, BorderSizePixel = 0, ZIndex = 7, Parent = btn,
        })

        local function count_selected()
            local n = 0; for _, _ in pairs(selected_set) do n += 1 end
            return n
        end

        local btn_txt = create("TextLabel", {
            Size = UDim2.new(1, -24, 1, 0),
            Position = UDim2.new(0, 6, 0, 0),
            BackgroundTransparency = 1,
            Text = count_selected() > 0 and string.format("%d selected", count_selected()) or "None",
            TextColor3 = Theme.Text, TextSize = 12, Font = fonts.UI,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9, Parent = btn,
        })
        local arrow = create("TextLabel", {
            Size = UDim2.new(0, 18, 1, 0),
            Position = UDim2.new(1, -18, 0, 0),
            BackgroundTransparency = 1,
            Text = ">", TextColor3 = Theme.TextDim,
            TextSize = 12, Font = fonts.Mono, ZIndex = 9, Parent = btn,
        })
        local list_frame = create("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            Position = UDim2.new(0, 0, 0, 34),
            BackgroundTransparency = 1, Visible = false,
            ZIndex = 10, Parent = holder,
        })

        local function refresh()
            for _, c in pairs(list_frame:GetChildren()) do
                if c:IsA("TextButton") then c:Destroy() end
            end
            for _, opt in pairs(options) do
                local sel = selected_set[opt] or false
                local o = create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 20),
                    BackgroundColor3 = sel and Theme.SurfaceAlt or Theme.Surface,
                    BorderSizePixel = 0, Text = "", ZIndex = 11, Parent = list_frame,
                })
                local o_border = create("Frame", {
                    Size = UDim2.new(1, 1, 1, 0),
                    Position = UDim2.new(0, -1, 0, 0),
                    BackgroundColor3 = Theme.Border, BorderSizePixel = 0, ZIndex = 10, Parent = o,
                })
                local cb_box = create("Frame", {
                    Size = UDim2.new(0, 10, 0, 10),
                    Position = UDim2.new(0, 6, 0, 5),
                    BackgroundColor3 = sel and Theme.Accent or Theme.SurfaceAlt,
                    BorderSizePixel = 0, ZIndex = 12, Parent = o,
                })
                local cb_border = create("Frame", {
                    Size = UDim2.new(1, 1, 1, 1),
                    Position = UDim2.new(0, -1, 0, -1),
                    BackgroundColor3 = sel and Theme.AccentDim or Theme.Border,
                    BorderSizePixel = 0, ZIndex = 11, Parent = cb_box,
                })
                local check = create("TextLabel", {
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    Text = "L", TextColor3 = Theme.BG,
                    TextSize = 9, Font = fonts.UI,
                    Visible = sel, ZIndex = 13, Parent = cb_box,
                })
                local ot = create("TextLabel", {
                    Size = UDim2.new(1, -22, 1, 0),
                    Position = UDim2.new(0, 22, 0, 0),
                    BackgroundTransparency = 1,
                    Text = opt, TextColor3 = Theme.Text,
                    TextSize = 12, Font = fonts.UI,
                    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, Parent = o,
                })
                o.MouseButton1Click:Connect(function()
                    if selected_set[opt] then
                        selected_set[opt] = nil
                    else
                        selected_set[opt] = true
                    end
                    local result = {}
                    for k, _ in pairs(selected_set) do table.insert(result, k) end
                    btn_txt.Text = #result > 0 and string.format("%d selected", #result) or "None"
                    if pointer then flags[pointer] = result end
                    pcall(cb, result)
                    refresh()
                end)
            end
        end

        local function toggle_open()
            open = not open
            arrow.Text = open and "v" or ">"
            list_frame.Visible = open
            if open then
                refresh()
                local count = #options; local list_h = count * 20
                list_frame.Size = UDim2.new(1, 0, 0, list_h)
                holder.Size = UDim2.new(1, -4, 0, 34 + list_h)
                holder.ClipsDescendants = false
            else
                holder.Size = UDim2.new(1, -4, 0, 34)
                task.delay(0.1, function()
                    if not open then holder.ClipsDescendants = true end
                end)
            end
        end

        btn.MouseButton1Click:Connect(toggle_open)
        refresh()

        if pointer then
            flags[pointer] = function(v)
                selected_set = {}
                for _, k in pairs(v or {}) do selected_set[k] = true end
                local result = {}
                for k, _ in pairs(selected_set) do table.insert(result, k) end
                btn_txt.Text = #result > 0 and string.format("%d selected", #result) or "None"
                pcall(cb, result)
                refresh()
            end
        end
    end

    function SectionMethods:Radio(opts)
        opts = opts or {}
        local label = opts.Name or "Radio"
        local options = opts.Options or {}
        local default = opts.Default or options[1]
        local cb = opts.Callback or opts.callback or function() end
        local pointer = opts.Pointer
        local selected = default
        if pointer then flags[pointer] = selected end

        local holder = create("Frame", {
            Size = UDim2.new(1, -4, 0, 16 + #options * 20),
            BackgroundTransparency = 1, ZIndex = 7, Parent = self._content,
        })
        local title = create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 14),
            BackgroundTransparency = 1,
            Text = label, TextColor3 = Theme.Text,
            TextSize = 13, Font = fonts.UI,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = holder,
        })
        local function build_radios()
            for i, opt in pairs(options) do
                local sel = opt == selected
                local o = create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 18),
                    Position = UDim2.new(0, 0, 0, 14 + (i - 1) * 20),
                    BackgroundTransparency = 1, Text = "", ZIndex = 8, Parent = holder,
                })
                local circle = create("Frame", {
                    Size = UDim2.new(0, 12, 0, 12),
                    Position = UDim2.new(0, 2, 0, 3),
                    BackgroundColor3 = sel and Theme.Accent or Theme.SurfaceAlt,
                    BorderSizePixel = 0, ZIndex = 9, Parent = o,
                })
                local circ_border = create("Frame", {
                    Size = UDim2.new(1, 1, 1, 1),
                    Position = UDim2.new(0, -1, 0, -1),
                    BackgroundColor3 = sel and Theme.AccentDim or Theme.Border,
                    BorderSizePixel = 0, ZIndex = 8, Parent = circle,
                })
                local dot = create("Frame", {
                    Size = UDim2.new(0, 6, 0, 6),
                    Position = UDim2.new(0, 3, 0, 3),
                    BackgroundColor3 = Theme.BG,
                    BorderSizePixel = 0,
                    Visible = sel, ZIndex = 10, Parent = circle,
                })
                local ot = create("TextLabel", {
                    Size = UDim2.new(1, -20, 1, 0),
                    Position = UDim2.new(0, 20, 0, 0),
                    BackgroundTransparency = 1,
                    Text = opt, TextColor3 = Theme.Text,
                    TextSize = 13, Font = fonts.UI,
                    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9, Parent = o,
                })
                o.MouseButton1Click:Connect(function()
                    if selected == opt then return end
                    selected = opt
                    for _, child in pairs(holder:GetChildren()) do
                        if child:IsA("TextButton") then
                            local c = child:FindFirstChildOfClass("Frame")
                            if c then
                                c.BackgroundColor3 = Theme.SurfaceAlt
                                local b = c:FindFirstChild("Frame")
                                if b then b.Visible = false end
                                local bo = c:FindFirstChild("Frame")
                                if bo then
                                    local parent = bo.Parent
                                    if parent then
                                        local brd = parent:FindFirstChild("Frame")
                                        if brd then brd.BackgroundColor3 = Theme.Border end
                                    end
                                end
                            end
                        end
                    end
                    circle.BackgroundColor3 = Theme.Accent
                    circ_border.BackgroundColor3 = Theme.AccentDim
                    dot.Visible = true
                    if pointer then flags[pointer] = opt end
                    pcall(cb, opt)
                end)
            end
        end
        build_radios()
        if pointer then
            flags[pointer] = function(v)
                selected = v
                for _, child in pairs(holder:GetChildren()) do
                    if child:IsA("TextButton") then
                        local txt = child:FindFirstChild("TextLabel")
                        if txt then
                            local circle = child:FindFirstChildOfClass("Frame")
                            if circle then
                                local match = txt.Text == v
                                circle.BackgroundColor3 = match and Theme.Accent or Theme.SurfaceAlt
                                local dot = circle:FindFirstChild("Frame")
                                if dot then dot.Visible = match end
                            end
                        end
                    end
                end
                pcall(cb, v)
            end
        end
    end

    function SectionMethods:Keybind(opts)
        opts = opts or {}
        local label = opts.Name or "Keybind"
        local default = opts.Default or Enum.KeyCode.F
        local cb = opts.Callback or opts.callback or function() end
        local pointer = opts.Pointer
        local listening = false
        local current = default
        if pointer then flags[pointer] = current end

        local holder = create("Frame", {
            Size = UDim2.new(1, -4, 0, 20),
            BackgroundTransparency = 1, ZIndex = 7, Parent = self._content,
        })
        local txt = create("TextLabel", {
            Size = UDim2.new(1, -80, 1, 0),
            BackgroundTransparency = 1,
            Text = label, TextColor3 = Theme.Text,
            TextSize = 13, Font = fonts.UI,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = holder,
        })
        local btn = create("TextButton", {
            Size = UDim2.new(0, 72, 1, -4),
            Position = UDim2.new(1, -72, 0, 2),
            BackgroundColor3 = Theme.SurfaceAlt,
            BorderSizePixel = 0, Text = "", ZIndex = 8, Parent = holder,
        })
        local btn_border = create("Frame", {
            Size = UDim2.new(1, 1, 1, 1),
            Position = UDim2.new(0, -1, 0, -1),
            BackgroundColor3 = Theme.Border, BorderSizePixel = 0, ZIndex = 7, Parent = btn,
        })
        local btn_txt = create("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = default.Name, TextColor3 = Theme.Text,
            TextSize = 12, Font = fonts.Mono, ZIndex = 9, Parent = btn,
        })

        local function update_key(input)
            local key = input.KeyCode
            if key == Enum.KeyCode.Unknown then
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    current = Enum.UserInputType.MouseButton1
                elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
                    current = Enum.UserInputType.MouseButton2
                elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
                    current = Enum.UserInputType.MouseButton3
                end
            else
                current = key
            end
            btn_txt.Text = current.Name
            listening = false
            UserInputService.InputBegan:Unlink()
            if pointer then flags[pointer] = current end
            pcall(cb, current)
            btn.BackgroundColor3 = Theme.SurfaceAlt
        end

        btn.MouseButton1Click:Connect(function()
            listening = not listening
            if listening then
                btn_txt.Text = "..."
                btn.BackgroundColor3 = Theme.Surface
                local conn
                conn = UserInputService.InputBegan:Connect(function(input, processed)
                    if processed then return end
                    conn:Disconnect()
                    update_key(input)
                end)
                task.delay(5, function()
                    if listening then
                        listening = false
                        btn_txt.Text = current.Name
                        btn.BackgroundColor3 = Theme.SurfaceAlt
                    end
                end)
            end
        end)

        if pointer then
            flags[pointer] = function(v)
                if typeof(v) == "string" then
                    current = Enum.KeyCode[v] or v
                else
                    current = v
                end
                btn_txt.Text = current.Name
                pcall(cb, current)
            end
        end
    end

    function SectionMethods:Box(opts)
        opts = opts or {}
        local label = opts.Name or ""
        local placeholder = opts.Placeholder or ""
        local default = opts.Default or ""
        local cb = opts.Callback or opts.callback or function() end
        local pointer = opts.Pointer

        local holder = create("Frame", {
            Size = UDim2.new(1, -4, 0, 36),
            BackgroundTransparency = 1, ZIndex = 7, Parent = self._content,
        })
        if label ~= "" then
            local txt = create("TextLabel", {
                Size = UDim2.new(1, 0, 0, 14),
                BackgroundTransparency = 1,
                Text = label, TextColor3 = Theme.Text,
                TextSize = 13, Font = fonts.UI,
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = holder,
            })
        end
        local box = create("TextBox", {
            Size = UDim2.new(1, 0, 0, 20),
            Position = UDim2.new(0, 0, 0, label ~= "" and 16 or 0),
            BackgroundColor3 = Theme.SurfaceAlt,
            BorderSizePixel = 0, Text = "",
            PlaceholderText = placeholder,
            PlaceholderColor3 = Theme.TextDim,
            TextColor3 = Theme.Text,
            TextSize = 12, Font = fonts.Mono,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            ZIndex = 8, Parent = holder,
        })
        local box_border = create("Frame", {
            Size = UDim2.new(1, 1, 1, 1),
            Position = UDim2.new(0, -1, 0, -1),
            BackgroundColor3 = Theme.Border, BorderSizePixel = 0, ZIndex = 7, Parent = box,
        })
        if default ~= "" then box.Text = default end
        box.FocusLost:Connect(function()
            local val = box.Text
            if pointer then flags[pointer] = val end
            pcall(cb, val)
        end)
        if pointer then
            flags[pointer] = function(v)
                box.Text = tostring(v)
                pcall(cb, v)
            end
        end
    end

    function SectionMethods:ColorPicker(opts)
        opts = opts or {}
        opts._parent_holder = nil
        local cp = build_colorpicker(opts)
        cp._obj.Parent = self._content
        return cp
    end

    function SectionMethods:ColorPickerAlpha(opts)
        opts = opts or {}
        opts._parent_holder = nil
        opts._alpha = true
        local cp = build_colorpicker(opts)
        cp._obj.Parent = self._content
        return cp
    end

    function SectionMethods:Separator()
        local sep = create("Frame", {
            Size = UDim2.new(1, -4, 0, 1),
            BackgroundColor3 = Theme.Border,
            BorderSizePixel = 0, ZIndex = 6, Parent = self._content,
        })
    end

    function page_obj:Section(opts)
        opts = opts or {}
        local name = opts.Name or "Section"
        local side = opts.Side or "Left"
        local max = opts.Max or math.huge
        local section_obj = {}
        local holder = create("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            ZIndex = 5, Parent = page_frame,
        })
        local title = create("TextLabel", {
            Size = UDim2.new(1, -4, 0, 18),
            BackgroundTransparency = 1,
            Text = name, TextColor3 = Theme.Accent,
            TextSize = 13, Font = fonts.UI,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 7, Parent = holder,
        })
        table.insert(accent_objects.text, title)
        local accent_line = create("Frame", {
            Size = UDim2.new(1, -4, 0, 1),
            Position = UDim2.new(0, 0, 0, 17),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0, ZIndex = 7, Parent = holder,
        })
        table.insert(accent_objects.bg, accent_line)
        local content = create("ScrollingFrame", {
            Size = UDim2.new(1, -4, 1, -22),
            Position = UDim2.new(0, 2, 0, 20),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Border,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            CanvasSize = UDim2.new(0, 0, 0, 1),
            ZIndex = 6, Parent = holder,
        })
        local list = create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 4),
            Parent = content,
        })
        list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            content.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 4)
            holder.Size = UDim2.new(1, 0, 0, list.AbsoluteContentSize.Y + 24)
        end)
        section_obj._content = content
        section_obj._holder = holder
        for k, v in pairs(SectionMethods) do
            section_obj[k] = v
        end

        local col_holder = page_data["col_" .. side]
        if not col_holder then
            col_holder = create("ScrollingFrame", {
                Size = UDim2.new(0.5, -4, 1, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ScrollBarThickness = 0,
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                CanvasSize = UDim2.new(0, 0, 0, 1),
                ZIndex = 5, Parent = page_frame,
            })
            local col_list = create("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 8),
                Parent = col_holder,
            })
            col_list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                col_holder.CanvasSize = UDim2.new(0, 0, 0, col_list.AbsoluteContentSize.Y + 4)
            end)
            if side == "Left" then
                col_holder.Position = UDim2.new(0, 0, 0, 0)
            else
                col_holder.Position = UDim2.new(0.5, 4, 0, 0)
            end
            page_data["col_" .. side] = col_holder
        end

        holder.Parent = col_holder
        table.insert(self._pages or {}, { _frame = page_frame, _sections = { section_obj } })
        setmetatable(section_obj, { __index = SectionMethods })
        self._last_section = section_obj
        return section_obj
    end

    table.insert(self._pages, page_data)
    return page_obj
end

function build_colorpicker(opts)
    opts = opts or {}
    local label = opts.Name or "Color"
    local default = opts.Default or Color3.fromRGB(255, 255, 255)
    local has_alpha = opts._alpha or opts.Alpha ~= nil
    local default_alpha = opts.Alpha or 1
    local cb = opts.Callback or opts.callback or function() end
    local pointer = opts.Pointer
    local parent_holder = opts._parent_holder
    local z_offset = opts._z_offset or 0

    local open = false; local current = default; local alpha = default_alpha

    local holder = create("Frame", {
        Size = UDim2.new(1, -4, 0, 20),
        BackgroundTransparency = 1, ZIndex = 7,
    })
    if parent_holder then
        holder.Parent = parent_holder
    end
    local txt = create("TextLabel", {
        Size = UDim2.new(1, -30, 1, 0),
        BackgroundTransparency = 1,
        Text = label, TextColor3 = Theme.Text,
        TextSize = 13, Font = fonts.UI,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = holder,
    })
    local swatch = create("TextButton", {
        Size = UDim2.new(0, 22, 0, 14),
        Position = UDim2.new(1, -22, 0, 3),
        BackgroundColor3 = default,
        BorderSizePixel = 0, Text = "", ZIndex = 8, Parent = holder,
    })
    local swatch_border = create("Frame", {
        Size = UDim2.new(1, 1, 1, 1),
        Position = UDim2.new(0, -1, 0, -1),
        BackgroundColor3 = Theme.Border, BorderSizePixel = 0, ZIndex = 7, Parent = swatch,
    })

    local popup = create("Frame", {
        Size = UDim2.new(0, 200, 0, has_alpha and 230 or 210),
        Position = UDim2.new(1, 4, has_alpha and -190 or -170, 0),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0, Visible = false, ZIndex = 50,
    })
    local popup_border = create("Frame", {
        Size = UDim2.new(1, 1, 1, 1),
        Position = UDim2.new(0, -1, 0, -1),
        BackgroundColor3 = Theme.Border, BorderSizePixel = 0, ZIndex = 49, Parent = popup,
    })
    local sat_val = create("ImageLabel", {
        Size = UDim2.new(0, 186, 0, 140),
        Position = UDim2.new(0, 7, 0, 7),
        BackgroundColor3 = Color3.fromHSV(1, 1, 1),
        Image = "rbxassetid://8630797271",
        BorderSizePixel = 0, ZIndex = 51, Parent = popup,
    })
    local sat_border = create("Frame", {
        Size = UDim2.new(1, 1, 1, 1),
        Position = UDim2.new(0, -1, 0, -1),
        BackgroundColor3 = Theme.Border, BorderSizePixel = 0, ZIndex = 50, Parent = sat_val,
    })
    local sat_picker = create("Frame", {
        Size = UDim2.new(0, 4, 0, 4),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderColor3 = Color3.new(0, 0, 0), ZIndex = 52, Parent = sat_val,
    })

    local hue_bar = create("ImageLabel", {
        Size = UDim2.new(0, 16, 0, 140),
        Position = UDim2.new(1, -25, 0, 7),
        BackgroundColor3 = Color3.new(1, 1, 1),
        Image = "rbxassetid://8630799159",
        BorderSizePixel = 0, ScaleType = Enum.ScaleType.Crop, ZIndex = 51, Parent = popup,
    })
    local hue_border = create("Frame", {
        Size = UDim2.new(1, 1, 1, 1),
        Position = UDim2.new(0, -1, 0, -1),
        BackgroundColor3 = Theme.Border, BorderSizePixel = 0, ZIndex = 50, Parent = hue_bar,
    })
    local hue_picker = create("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0, ZIndex = 52, Parent = hue_bar,
    })

    local preview = create("Frame", {
        Size = UDim2.new(0, 50, 0, 16),
        Position = UDim2.new(0, 7, 0, 154),
        BackgroundColor3 = current,
        BorderSizePixel = 0, ZIndex = 51, Parent = popup,
    })
    local preview_border = create("Frame", {
        Size = UDim2.new(1, 1, 1, 1),
        Position = UDim2.new(0, -1, 0, -1),
        BackgroundColor3 = Theme.Border, BorderSizePixel = 0, ZIndex = 50, Parent = preview,
    })

    if has_alpha then
        local alpha_txt = create("TextLabel", {
            Size = UDim2.new(0, 30, 0, 16),
            Position = UDim2.new(0, 62, 0, 154),
            BackgroundTransparency = 1,
            Text = "A:", TextColor3 = Theme.TextDim,
            TextSize = 11, Font = fonts.UI,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 51, Parent = popup,
        })
        local alpha_bg = create("Frame", {
            Size = UDim2.new(0, 108, 0, 8),
            Position = UDim2.new(0, 85, 0, 158),
            BackgroundColor3 = Theme.SurfaceAlt,
            BorderSizePixel = 0, ZIndex = 51, Parent = popup,
        })
        local alpha_bg_border = create("Frame", {
            Size = UDim2.new(1, 1, 1, 1),
            Position = UDim2.new(0, -1, 0, -1),
            BackgroundColor3 = Theme.Border, BorderSizePixel = 0, ZIndex = 50, Parent = alpha_bg,
        })
        local alpha_fill = create("Frame", {
            Size = UDim2.new(alpha, 0, 1, 0),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0, ZIndex = 52, Parent = alpha_bg,
        })
        local alpha_picker = create("Frame", {
            Size = UDim2.new(0, 4, 1, 2),
            Position = UDim2.new(alpha, -2, 0, -1),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderColor3 = Color3.new(0, 0, 0), ZIndex = 53, Parent = alpha_bg,
        })
        local sliding_alpha = false
        alpha_bg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                sliding_alpha = true
                local pos = math.clamp((input.Position.X - alpha_bg.AbsolutePosition.X) / alpha_bg.AbsoluteSize.X, 0, 1)
                alpha = pos
                alpha_fill.Size = UDim2.new(alpha, 0, 1, 0)
                alpha_picker.Position = UDim2.new(alpha, -2, 0, -1)
                preview.BackgroundTransparency = 1 - alpha
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if sliding_alpha and input.UserInputType == Enum.UserInputType.MouseMovement then
                local pos = math.clamp((input.Position.X - alpha_bg.AbsolutePosition.X) / alpha_bg.AbsoluteSize.X, 0, 1)
                alpha = pos
                alpha_fill.Size = UDim2.new(alpha, 0, 1, 0)
                alpha_picker.Position = UDim2.new(alpha, -2, 0, -1)
                preview.BackgroundTransparency = 1 - alpha
            end
        end)
        alpha_bg.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then sliding_alpha = false end
        end)
    end

    local function set_color(c, a)
        current = c or current
        alpha = a or alpha
        swatch.BackgroundColor3 = current
        preview.BackgroundColor3 = current
        preview.BackgroundTransparency = 1 - alpha
        sat_val.BackgroundColor3 = Color3.fromHSV(Color3.toHSV(current))
        local h, s, v = Color3.toHSV(current)
        sat_picker.Position = UDim2.new(s, -2, 1 - v, -2)
        hue_picker.Position = UDim2.new(0, 0, 0, (1 - h) * 138)
        if pointer then
            if has_alpha then
                flags[pointer] = { math.floor(current.R * 255), math.floor(current.G * 255), math.floor(current.B * 255), alpha }
            else
                flags[pointer] = { math.floor(current.R * 255), math.floor(current.G * 255), math.floor(current.B * 255) }
            end
        end
        if has_alpha then
            pcall(cb, current, alpha)
        else
            pcall(cb, current)
        end
    end

    local function open_popup()
        open = true
        popup.Visible = true
        popup.Parent = gui
        local pos = holder.AbsolutePosition
        popup.Position = UDim2.new(0, pos.X + holder.AbsoluteSize.X + 4, 0, math.max(pos.Y - 50, 10))
        set_color(current, alpha)
        local conn
        conn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                task.wait()
                if popup.Visible then
                    local m = input.Position
                    local ap = popup.AbsolutePosition
                    local as = popup.AbsoluteSize
                    if m.X < ap.X or m.X > ap.X + as.X or m.Y < ap.Y or m.Y > ap.Y + as.Y then
                        if not (m.X >= holder.AbsolutePosition.X and m.X <= holder.AbsolutePosition.X + holder.AbsoluteSize.X and m.Y >= holder.AbsolutePosition.Y and m.Y <= holder.AbsolutePosition.Y + holder.AbsoluteSize.Y) then
                            open = false
                            popup.Visible = false
                            popup.Parent = holder
                            conn:Disconnect()
                        end
                    end
                end
            end
        end)
    end

    swatch.MouseButton1Click:Connect(open_popup)

    local sliding_hue = false
    local sliding_sat = false

    sat_val.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding_sat = true
            local x = math.clamp((input.Position.X - sat_val.AbsolutePosition.X) / sat_val.AbsoluteSize.X, 0, 1)
            local y = math.clamp((input.Position.Y - sat_val.AbsolutePosition.Y) / sat_val.AbsoluteSize.Y, 0, 1)
            local h = 1 - (hue_picker.AbsolutePosition.Y - hue_bar.AbsolutePosition.Y) / hue_bar.AbsoluteSize.Y
            local c = Color3.fromHSV(h, x, 1 - y)
            set_color(c, alpha)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliding_sat and input.UserInputType == Enum.UserInputType.MouseMovement then
            local x = math.clamp((input.Position.X - sat_val.AbsolutePosition.X) / sat_val.AbsoluteSize.X, 0, 1)
            local y = math.clamp((input.Position.Y - sat_val.AbsolutePosition.Y) / sat_val.AbsoluteSize.Y, 0, 1)
            local h = 1 - (hue_picker.AbsolutePosition.Y - hue_bar.AbsolutePosition.Y) / hue_bar.AbsoluteSize.Y
            local c = Color3.fromHSV(h, x, 1 - y)
            set_color(c, alpha)
        end
    end)
    sat_val.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then sliding_sat = false end
    end)

    hue_bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding_hue = true
            local y = math.clamp((input.Position.Y - hue_bar.AbsolutePosition.Y) / hue_bar.AbsoluteSize.Y, 0, 1)
            local h = 1 - y
            local _, s, v = Color3.toHSV(current)
            local c = Color3.fromHSV(h, s, v)
            set_color(c, alpha)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliding_hue and input.UserInputType == Enum.UserInputType.MouseMovement then
            local y = math.clamp((input.Position.Y - hue_bar.AbsolutePosition.Y) / hue_bar.AbsoluteSize.Y, 0, 1)
            local h = 1 - y
            local _, s, v = Color3.toHSV(current)
            local c = Color3.fromHSV(h, s, v)
            set_color(c, alpha)
        end
    end)
    hue_bar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then sliding_hue = false end
    end)

    if pointer then
        if has_alpha then
            flags[pointer] = function(v)
                if type(v) == "table" and #v >= 3 then
                    set_color(Color3.fromRGB(v[1], v[2], v[3]), v[4] or 1)
                end
            end
        else
            flags[pointer] = function(v)
                if type(v) == "table" and #v >= 3 then
                    set_color(Color3.fromRGB(v[1], v[2], v[3]), 1)
                end
            end
        end
    end

    if default then set_color(default, default_alpha) end

    local obj = {}
    obj._obj = holder
    function obj:SetColor(c, a)
        set_color(c, a or alpha)
    end

    return obj
end

task.spawn(function()
    local exists = pcall(function() return CoreGui:FindFirstChild("zenware_ui") end)
    if not exists then
        gui.Name = "zenware_ui"
        gui.Parent = CoreGui
    end
end)

return library
