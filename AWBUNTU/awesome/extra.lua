imgpath = awful.util.getdir("config")..'/imgs/'
confdir = awful.util.getdir("config")..'/'
--}}}
--{{{ Utilidades/Funciones
function escape(text)
    if text then
        return awful.util.escape(text or 'UNKNOWN')
    end
end
-- Bold
function bold(text)
    return '<b>' .. text .. '</b>'
end
-- Italic
function italic(text)
    return '<i>' .. text .. '</i>'
end

-- Foreground color
function fgc(text,color)
    if not color then color = 'white' end
    return '<span color="'..color..'">'..text..'</span>'
end

-- process_read (io.popen)
function pread(cmd)
    if cmd and cmd ~= '' then
        local f, err = io.popen(cmd, 'r')
        if f then
            local s = f:read('*all')
            f:close()
            return s
        else
            print(err)
        end
    end
end

-- file_read (io.open)
function fread(cmd)
    if cmd and cmd ~= '' then
        local f, err = io.open(cmd, 'r')
        if f then
            local s = f:read('*all')
            f:close()
            return s
        else
            print(err)
        end
    end
end

--{{{ Separadores (img)
--------------------------------------------------------------------------------
separator = widget({ type = 'imagebox'
                   , name = 'separator'
                   })
separator.image = image(awful.util.getdir("config").."/imgs/separador2.png")
separator.resize = false
--}}}
--{{{ MPC (imagebox+textbox) requiere mpc/mpd
--------------------------------------------------------------------------------

-- Converts bytes to human-readable units, returns value (number) and unit (string)
function bytestoh(bytes)
    local tUnits={"K","M","G","T","P"} -- MUST be enough. :D
    local v,u
    for k=table.getn(tUnits),1,-1 do
        if math.fmod(bytes,1024^k) ~= bytes then v=bytes/(1024^k); u=tUnits[k] break end
    end
    return v or bytes,u or "B"
end

-- menos bloat creando iconos
function createIco(widget,file,click)
    if not widget or not file or not click then return nil end
    widget.image = image(imgpath..'/'..file)
    widget.resize = false
    awful.widget.layout.margins[widget] = { top = 1, bottom = 1, left = 1, right = 1 }
    widget:buttons(awful.util.table.join(
        awful.button({ }, 1, function ()
            awful.util.spawn(click,false)
        end)
    ))
end

--}}}
--{{{ Net (imagebox+textbox)
--------------------------------------------------------------------------------
-- Devuelve el tráfico de la interface de red usada como default GW.
function net_info()
    if not old_rx or not old_tx or not old_time then
        old_rx,old_tx,old_time = 0,0,1
    end
    local iface,cur_rx,cur_tx,rx,rxu,tx,txu
    local file = fread("/proc/net/route")
    if file then
        iface = file:match('(%S+)%s+00000000%s+%w+%s+0003%s+')
        if not iface or iface == '' then
            return '' --fgc('No Def GW', 'red')
        end
    else
        return "Err: /proc/net/route."
    end
    --Sacamos cur_rx y cur_tx de /proc/net/dev
    file = fread("/proc/net/dev")
    if file then
       cur_rx,cur_tx = file:match(iface..':%s*(%d+)%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+(%d+)%s+')
    else
        return "Err: /proc/net/dev"
    end
    cur_time = os.time()
    interval = cur_time - old_time -- diferencia entre mediciones
-- rx = ( cur_rx - old_rx ) / 1024 / interval -- resultado en kb
-- tx = ( cur_tx - old_tx ) / 1024 / interval
    if tonumber(interval) > 0 then -- porsia
        rx,rxu = bytestoh( ( cur_rx - old_rx ) / interval )
        tx,txu = bytestoh( ( cur_tx - old_tx ) / interval )
        old_rx,old_tx,old_time = cur_rx,cur_tx,cur_time
    else
        rx,tx,rxu,txu = "0","0","B","B"
    end
    return iface..fgc(bold('|'), 'green')..string.format("%04d%2s",rx,rxu)..fgc(bold('|'), 'red')..string.format("%04d%2s",tx,txu)
end
-- imagebox
net_ico = widget({ type = "imagebox" })
createIco(net_ico,'net-wired.png', terminal..' -e screen -S awesome watch -n5 "lsof -ni"')
-- textbox
netwidget = widget({ type = 'textbox'
                   , name = 'netwidget'
                   })
-- primera llamada a la función
netwidget.text = net_info()
-- mouse_enter
netwidget:add_signal("mouse::enter", function()
    naughty.destroy(pop)
    local listen = pread("netstat -patun 2>&1 | awk '/ESTABLISHED/{ if ($4 !~ /127.0.0.1|localhost/) print \"(\"$7\")\t\"$5}'")
    pop = naughty.notify({ title = fgc('Established\n')
                         , text = listen
                         , icon = imgpath..'net-wired.png'
                         , icon_size = 32
                         , timeout = 0
                         , position = "bottom_right"
                         , bg = beautiful.bg_focus
                         })
end)
-- mouse_leave
netwidget:add_signal("mouse::leave", function() naughty.destroy(pop) end)
--}}}
--{{{ Load (magebox+textbox)


-- Devuelve el load average
function avg_load()
    local n = fread('/proc/loadavg')
    local pos = n:find(' ', n:find(' ', n:find(' ')+1)+1)
    return n:sub(1,pos-1)
end
-- imagebox
load_ico = widget({ type = "imagebox" })
createIco(load_ico,'load.png', terminal..' -e htop')
-- textbox
loadwidget = widget({ type = 'textbox'
                    , name = 'loadwidget'
                    })
-- llamada inicial a la función
loadwidget.text = avg_load()
-- mouse_enter
loadwidget:add_signal("mouse::enter", function()
    naughty.destroy(pop)
    local text = pread("uptime; echo; who")
    pop = naughty.notify({ title = fgc('Uptime\n')
                         , text = text
                         , icon = imgpath..'load.png'
                         , icon_size = 32
                         , timeout = 0
                         , position = "bottom_right"
                         , bg = beautiful.bg_focus
                         })
end)
-- mouse_leave
loadwidget:add_signal("mouse::leave", function() naughty.destroy(pop) end)

--{{{ Cpu (imagebox+textbox+graph)
--------------------------------------------------------------------------------
-- Devuelve el % de uso de cada CPU y actualiza la gráfica con la media.
-- user + nice + system + idle = 100/second
-- so diffs of: $2+$3+$4 / all-together * 100 = %
-- or: 100 - ( $5 / all-together) * 100 = %
-- or: 100 - 100 * ( $5 / all-together)= %
function cpu_info()
    if not cpu then
        cpu={}
    end
    local s = 0
    local info = fread("/proc/stat")
    if not info then
        return "Error leyendo /proc/stat"
    end
    for user,nice,system,idle in info:gmatch("cpu.-%s(%d+)%s+(%d+)%s+(%d+)%s+(%d+)") do
        if not cpu[s] then
            cpu[s]={}
            cpu[s].sum = 0
            cpu[s].res = 0
            cpu[s].idle = 0
        end
        local new_sum = user + nice + system + idle
        local diff = new_sum - cpu[s].sum
        cpu[s].res = 100
        if diff > 0 then -- siempre devería cumplirse, excepto cargas elevadas.
            cpu[s].res = 100 - 100 * (idle - cpu[s].idle) / diff
        end
        cpu[s].sum = new_sum
        cpu[s].idle = idle
        s = s + 1
    end
    -- next(cpu) devuelve nil si la tabla cpu está vacía
    if not next(cpu) then
        return "No hay cpus en /proc/stat"
    end
    if cpugraphwidget and cpu[0].res then
        cpugraphwidget:add_value(cpu[0].res)
    end
    info = ''
    for s = 0, #cpu do
        if cpu[s].res > 99 then
            info = info..fgc('C'..s..':')..fgc('LOL', 'red')
        else
            info = info..fgc('C'..s..':')..string.format("%02d",cpu[s].res)..'%'
        end
        if s ~= #cpu then
            info = info..' '
        end
    end
    return info
end
-- imagebox
cpu_ico = widget({ type = "imagebox" })
createIco(cpu_ico,'cpu.png', terminal..' -e htop')
-- textbox
cpuwidget = widget({ type = 'textbox'
                   , name = 'cpuwidget'
                   })
-- graph
cpugraphwidget = awful.widget.graph()
cpugraphwidget:set_width(40)
cpugraphwidget:set_height(13)
cpugraphwidget:set_max_value(100)
cpugraphwidget:set_background_color('black')
cpugraphwidget:set_border_color('white')
cpugraphwidget:set_gradient_angle(0)
cpugraphwidget:set_gradient_colors({'white', 'green'})
awful.widget.layout.margins[cpugraphwidget.widget] = { top = 1, bottom = 1 }
-- primera llamada a la función
cpuwidget.text = cpu_info()
-- mouse_enter
cpuwidget:add_signal("mouse::enter", function()
    naughty.destroy(pop)
    local text = pread("ps -eo %cpu,%mem,ruser,pid,comm --sort -%cpu | head -20")
    pop = naughty.notify({ title = fgc('Processes\n')
                         , text = text
                         , icon = imgpath..'cpu.png'
                         , icon_size = 28
                         , timeout = 0
                         , position = "bottom_right"
                         , bg = beautiful.bg_focus
                         })
end)

--{{{ Memory (imagebox+textbox+progressbar)
--------------------------------------------------------------------------------
-- Devuelve la ram usada en MB(%). Tb actualiza la progressbar
function activeram()
    local total,free,buffers,cached,active,used,percent
    for line in io.lines('/proc/meminfo') do
        for key, value in string.gmatch(line, "(%w+):\ +(%d+).+") do
            if key == "MemTotal" then
                total = tonumber(value)
                if total <= 0 then --wtf
                    return ''
                end
            elseif key == "MemFree" then
                free = tonumber(value)
            elseif key == "Buffers" then
                buffers = tonumber(value)
            elseif key == "Cached" then
                cached = tonumber(value)
            end
        end
    end
    active = total-(free+buffers+cached)
    used = string.format("%.0fMB",(active/1024))
    percent = string.format("%.0f",(active/total)*100)
    if membarwidget then
        membarwidget:set_value(percent/100)
    end
    return fgc(used, theme.font_key)..fgc('('..percent..'%)', theme.font_value)
end
-- imagebox
mem_ico = widget({ type = "imagebox" })
createIco(mem_ico,'mem.png', terminal..' -e htop')
-- textbox
memwidget = widget({ type = 'textbox'
                   , name = 'memwidget'
                   })
-- progressbar
membarwidget = awful.widget.progressbar()
membarwidget:set_width(40)
membarwidget:set_height(13)
membarwidget:set_background_color('black')
membarwidget:set_border_color('white')
membarwidget:set_gradient_colors({'green', 'white'})
awful.widget.layout.margins[membarwidget.widget] = { top = 1, bottom = 1 }
-- Llamada inicial a la función
memwidget.text = activeram()
-- mouse_enter
memwidget:add_signal("mouse::enter", function()
    naughty.destroy(pop)
    local text = pread("free -tm")
    pop = naughty.notify({ title = fgc('Free\n')
                         , text = text
                         , icon = imgpath..'mem.png'
                         , icon_size = 32
                         , timeout = 0
                         , position = "bottom_right"
                         , bg = beautiful.bg_focus
                         })
    end)
-- mouse_leave
memwidget:add_signal("mouse::leave", function() naughty.destroy(pop) end)
---}}}

--{{{ Timers
--------------------------------------------------------------------------------
-- Hook every sec
timer1 = timer { timeout = 1 }
timer1:add_signal("timeout", function()
    cpuwidget.text = cpu_info()
    loadwidget.text = avg_load()
    netwidget.text = net_info()
    memwidget.text = activeram()
end)
timer1:start()
-- Hook called every 5 secs
timer5 = timer { timeout = 5 }
timer5:add_signal("timeout", function()
    memwidget.text = activeram()
end)
--timer5:start()
--------------------------------------------------------------------------------
--{{{ Wibox
--------------------------------------------------------------------------------
 for s = 1, screen.count() do
     -- Defino la barra
     statusbar = {}
     -- La creo
     statusbar[s] = awful.wibox({ position = "bottom"
                                , fg = beautiful.fg_normal
                                , bg = beautiful.bg_normal
                                , border_color = beautiful.border_normal
                                , height = 15
                                , border_width = 0
                                })
     -- Le enchufo los widgets
     statusbar[s].widgets = { { vol_ico
                               , volwidget
                                , volwidget and separator or nil
                                , mpd_ico
                                , mpcwidget
                                , layout = awful.widget.layout.horizontal.leftright
                           
 			    }
                            , loadwidget                                        
                            , load_ico
 			    , separator
                            , netwidget
                            , net_ico
 		            , separator
                            , cpugraphwidget.widget
                            , cpuwidget
                            , cpu_ico
 			    , separator
                            , membarwidget.widget
                            , memwidget
                            , mem_ico
 			   , separator
                            , layout = awful.widget.layout.horizontal.rightleft
                            }
     -- La asigno.
     statusbar[s].screen = s
 end

