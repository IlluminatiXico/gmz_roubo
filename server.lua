local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")
vRPclient = Tunnel.getInterface("vRP")

func = {}
Tunnel.bindInterface("gmz_roubo",func)

local ultimoAssaltoHora = {}
local recompensa = {}
local assalto = {}
local tempoAssalto = {}

local policias = nil

function func.checkRobbery(v, setup)
    local source = source
    local user_id = vRP.getUserId(source)
    if user_id then

        for k,c in pairs(setup) do
            if k == v.type then
                policias = vRP.getUsersByPermissionInService("policia.permissao")
                if #policias < c.lspd then
                    TriggerClientEvent("TequilaNotify",source,"padrao", "Aviso","Número insuficiente de policiais ("..c.lspd..") no momento para iniciar o roubo.")
                else
                    if isEnabledToRob(k, c.tempoEspera) then
                        if hasNecessaryItemsToRob(user_id, c) then
                            print('Iniciou o roubo no banco: '.. v.id)
					        vRP.log2("roubo", "Assalto Iniciado", "O jogador "..user_id.." iniciou o assalto em "..v.type, user_id)

                            assalto[k] = true
                            ultimoAssaltoHora[k] = os.time()
                            recompensa[user_id] = c
                            tempoAssalto[user_id] = c.tempo
    
                            for n,i in pairs(recompensa[user_id].items) do
                                i.receber = parseInt(math.random(i.min, i.max) / c.tempo)
                                print('Recompensa: '..i.receber)
                            end
    
                            SetTimeout(c.tempo * 1000,function()
                                assalto[k] = false
                            end)
    
                            vRPclient._playAnim(source,false,{{"anim@heists@ornate_bank@grab_cash_heels","grab"}},true)
                            TriggerClientEvent("iniciandoroubo", source, v.x, v.y, v.z, c.tempo, v.h)
                            avisarPolicia("Roubo em Andamento", "Tentativa de assalto a "..v.type..", verifique o ocorrido.", v.x, v.y, v.z, v.type)
    
                        end
                    else
                        local tempoRestante = getRemaningTime(k, c.tempoEspera)
                        TriggerClientEvent("TequilaNotify",source,"padrao", "Aviso","Você ainda deve aguardar "..tempoRestante.." segundos para realizar a ação.")
                    end
                end
            end
        end
    end
end

function func.cancelRobbery()
    local source = source
    local user_id = vRP.getUserId(source)
    if user_id then
        tempoAssalto[user_id] = nil
        recompensa[user_id] = nil
        local policia = vRP.getUsersByPermissionInService("policia.permissao")
		for l,w in pairs(policia) do
			local player = vRP.getUserSource(parseInt(w))
			local playerId = vRP.getUserId(player)
			if player then
				async(function()
					TriggerClientEvent('blip:remover:assalto',player)
					TriggerClientEvent('chatMessage',player,"911",{65,130,255},"O assaltante saiu correndo. ("..user_id..")")
					vRP.log2("roubo", "Assalto Cancelado", "O jogador "..user_id.." cancelou o assalto.", user_id)
				end)
			end
		end
    end
end

function getRemaningTime(k, tempoEspera)
    local t = ((os.time() - ultimoAssaltoHora[k]) - tempoEspera * 60) * -1
    return t
end

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(1000)
        for k,v in pairs(assalto) do
            if assalto[k] then
                for p,l in pairs(recompensa) do
                    if tempoAssalto[p] then
                        if tempoAssalto[p] > 0 then

                            for n,i in pairs(recompensa[p].items) do
                                vRP.giveInventoryItem(p, n, i.receber)
                                vRP.log2("roubo", "Assalto Cancelado", "O jogador "..p.." recebeu "..i.receber.." pelo assalto.", p)
                            end
    
                            tempoAssalto[p] = tempoAssalto[p] - 1
                            if tempoAssalto[p] == 0 then
                                recompensa[p] = nil
                                tempoAssalto[p] = nil
                            end
                        end
                    end
                end
            end
        end
	end
end)

function isEnabledToRob(k, tempoEspera)

    if ultimoAssaltoHora[k] then
        if (os.time() - ultimoAssaltoHora[k]) < tempoEspera * 60 then
            return false
        else
            return true
        end
    end
    return true
end

function hasNecessaryItemsToRob(user_id, c)
    if c.itemsNecessarios then
        local itensNecessarios = #c.itemsNecessarios
        local count = 0
        local data = vRP.getUserDataTable(user_id)
        if data and data.inventory then
            for k,v in pairs(c.itemsNecessarios) do
                if data.inventory[k] then
                    if data.inventory[k].amount >= v.qtd then

                    else
                        TriggerClientEvent("TequilaNotify",source,"padrao", "Aviso","Você precisa de "..v.qtd.."x "..vRP.getItemName(k).." para iniciar")
                        return false
                    end
                else
                    TriggerClientEvent("TequilaNotify",source,"padrao", "Aviso","Você precisa de "..v.qtd.."x "..vRP.getItemName(k).." para iniciar.")
                    return false
                end
            end
            for k,v in pairs(c.itemsNecessarios) do
                if k == "masterpick" then

                else
                    vRP.tryGetInventoryItem(user_id, k, v.qtd)
                end
            end
        end
    end
    return true
end

function avisarPolicia(titulo, msg, x, y, z, name)
	for l,w in pairs(policias) do
		local player = vRP.getUserSource(parseInt(w))
		if player then
			async(function()
				TriggerClientEvent('blip:criar:assalto',player,x,y,z, name)
				vRPclient.playSound(player,"Oneshot_Final","MP_MISSION_COUNTDOWN_SOUNDSET")
				TriggerClientEvent("TequilaNotify",player,"padrao", titulo, msg)
			end)
		end
    end
    local admins = vRP.getUsersByPermission("moderador.permissao")
    for l,w in pairs(admins) do
		local player = vRP.getUserSource(parseInt(w))
		if player then
			async(function()
				TriggerClientEvent('blip:criar:assalto',player,x,y,z, name)
				vRPclient.playSound(player,"Oneshot_Final","MP_MISSION_COUNTDOWN_SOUNDSET")
				TriggerClientEvent("TequilaNotify",player, "padrao", "Admin", msg)
			end)
		end
    end
    
end