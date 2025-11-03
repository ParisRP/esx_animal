local ESX = exports["es_extended"]:getSharedObject()
local PlayerData = {}
local CurrentAnimal = nil
local AnimalSpawned = false
local AnimalHunger = 100
local AnimalThirst = 100
local OwnedAnimals = {} -- Liste des animaux achetés
local CurrentAnimalIndex = nil -- Index de l'animal actuel

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
    -- Charger les animaux possédés depuis le serveur
    ESX.TriggerServerCallback('esx_animal:getOwnedAnimals', function(animals)
        OwnedAnimals = animals or {}
        if #OwnedAnimals > 0 and not CurrentAnimalIndex then
            CurrentAnimalIndex = 1
        end
    end)
end)

-- Création du blip de l'animalerie
Citizen.CreateThread(function()
    for k,v in pairs(Config.PetShopLocation) do
        local blip = AddBlipForCoord(v.coords)
        SetBlipSprite(blip, v.blipSprite)
        SetBlipColour(blip, v.blipColor)
        SetBlipScale(blip, v.blipScale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(v.blipName)
        EndTextCommandSetBlipName(blip)
    end
end)

-- Menu principal de l'animalerie
function OpenPetShopMenu()
    local elements = {}
    
    for k,v in pairs(Config.Animals) do
        table.insert(elements, {
            label = v.label .. " - $" .. v.price,
            value = k
        })
    end
    
    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'pet_shop', {
        title    = 'Animalerie',
        align    = 'top-left',
        elements = elements
    }, function(data, menu)
        local animalInfo = Config.Animals[data.current.value]
        ESX.TriggerServerCallback('esx_animal:purchaseAnimal', function(success, animals)
            if success then
                ESX.ShowNotification("Vous avez acheté un " .. animalInfo.label)
                -- Mettre à jour la liste depuis le serveur
                OwnedAnimals = animals or OwnedAnimals
                CurrentAnimalIndex = #OwnedAnimals
                SpawnAnimal(OwnedAnimals[CurrentAnimalIndex].model)
            else
                ESX.ShowNotification("Vous n'avez pas assez d'argent!")
            end
        end, animalInfo.price, animalInfo.model)
    end, function(data, menu)
        menu.close()
    end)
end

-- Spawner l'animal
function SpawnAnimal(model)
    if AnimalSpawned then
        DeleteEntity(CurrentAnimal)
    end

    RequestModel(GetHashKey(model))
    while not HasModelLoaded(GetHashKey(model)) do
        Wait(500)
    end

    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    CurrentAnimal = CreatePed(28, GetHashKey(model), coords.x + 1.0, coords.y + 1.0, coords.z - 1.0, GetEntityHeading(playerPed), true, false)

    SetPedCanRagdoll(CurrentAnimal, false)
    SetEntityAsMissionEntity(CurrentAnimal, true, true)
    AnimalSpawned = true

    -- Commencer le suivi de l'animal
    StartAnimalAI()
end

-- Menu d'actions pour l'animal
function OpenAnimalActionMenu()
    if #OwnedAnimals == 0 then
        ESX.ShowNotification("Vous n'avez pas d'animaux!")
        return
    end

    -- Si un animal est déjà sélectionné mais non spawn, le spawn automatiquement
    if CurrentAnimalIndex and OwnedAnimals[CurrentAnimalIndex] and not AnimalSpawned then
        local sel = OwnedAnimals[CurrentAnimalIndex]
        if sel and sel.model then
            SpawnAnimal(sel.model)
        end
    end

    local elements = {
        {label = '--- Mes Animaux ---', value = nil}
    }
    
    -- Ajouter la liste des animaux possédés
    for i, animal in ipairs(OwnedAnimals) do
        local status = (i == CurrentAnimalIndex) and " [Actif]" or ""
        table.insert(elements, {
            label = animal.label .. status .. " - Faim: " .. animal.hunger .. "% - Soif: " .. animal.thirst .. "%",
            value = 'select_animal',
            index = i
        })
    end
    
    -- Ajouter les actions si un animal est sélectionné
    if CurrentAnimalIndex then
        table.insert(elements, {label = '--- Actions ---', value = nil})
        table.insert(elements, {label = 'Donner à manger', value = 'feed'})
        table.insert(elements, {label = 'Donner à boire', value = 'water'})
        table.insert(elements, {label = 'Faire asseoir/lever', value = 'sitdown'})
        table.insert(elements, {label = 'Faire suivre/arrêter', value = 'follow'})
        table.insert(elements, {label = 'Renommer l\'animal', value = 'rename'})
        table.insert(elements, {label = 'Enregistrer l\'animal', value = 'save'})
    end

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'animal_actions', {
        title    = 'Mes Animaux',
        align    = 'top-left',
        elements = elements
    }, function(data, menu)
            if data.current.value == 'select_animal' then
                if data.current.index ~= CurrentAnimalIndex then
                    CurrentAnimalIndex = data.current.index
                    local selectedAnimal = OwnedAnimals[CurrentAnimalIndex]
                    SpawnAnimal(selectedAnimal.model)
                    menu.close()
                    -- Réouvrir après une petite pause pour afficher les actions du nouvel animal
                    Citizen.Wait(100)
                    OpenAnimalActionMenu()
                end
            elseif data.current.value == 'feed' then
                TriggerServerEvent('esx_animal:useItem', 'pet_food')
                ESX.ShowNotification('Vous nourrissez votre animal')
                menu.close()
            elseif data.current.value == 'water' then
                TriggerServerEvent('esx_animal:useItem', 'pet_water')
                ESX.ShowNotification('Vous donnez à boire à votre animal')
                menu.close()
            elseif data.current.value == 'sitdown' then
                PlayAnimation('sitdown')
                menu.close()
            elseif data.current.value == 'follow' then
                ToggleFollow()
                menu.close()
            elseif data.current.value == 'save' then
                -- Sauvegarde immédiate des animaux sur le serveur
                if #OwnedAnimals > 0 then
                    TriggerServerEvent('esx_animal:saveOwnedAnimals', OwnedAnimals)
                    ESX.ShowNotification('Animaux sauvegardés en base de données')
                else
                    ESX.ShowNotification('Aucun animal à sauvegarder')
                end
                menu.close()
            elseif data.current.value == 'rename' then
            -- Renommer l'animal actif
            if not CurrentAnimalIndex or not OwnedAnimals[CurrentAnimalIndex] then
                ESX.ShowNotification('Aucun animal sélectionné')
                return
            end
            ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'rename_animal', {
                title = 'Entrez le nouveau nom'
            }, function(data2, menu2)
                local newName = tostring(data2.value)
                if newName == nil or newName == '' then
                    ESX.ShowNotification('Nom invalide')
                    return
                end
                OwnedAnimals[CurrentAnimalIndex].label = newName
                TriggerServerEvent('esx_animal:saveOwnedAnimals', OwnedAnimals)
                ESX.ShowNotification('Nom de l\'animal mis à jour: ' .. newName)
                menu2.close()
                menu.close()
                OpenAnimalActionMenu()
            end, function(data2, menu2)
                menu2.close()
            end)
        end
    end, function(data, menu)
        menu.close()
    end)
end

-- Gestion de l'IA de l'animal
function StartAnimalAI()
    Citizen.CreateThread(function()
        while AnimalSpawned do
            Citizen.Wait(1000)
            local playerPed = PlayerPedId()
            local animalCoords = GetEntityCoords(CurrentAnimal)
            local playerCoords = GetEntityCoords(playerPed)
            local distance = #(playerCoords - animalCoords)

            if distance > Config.MaxDistance then
                TaskGoToEntity(CurrentAnimal, playerPed, -1, 2.0, 2.0, 0, 0)
            end

            -- Gestion de la faim et de la soif pour tous les animaux
            Citizen.Wait(60000) -- Attendre 1 minute
            for i, animal in ipairs(OwnedAnimals) do
                animal.hunger = math.max(0, animal.hunger - 1)
                animal.thirst = math.max(0, animal.thirst - 1.5)
                
                if i == CurrentAnimalIndex and (animal.hunger < 20 or animal.thirst < 20) then
                    ESX.ShowNotification("Votre " .. animal.label .. " a faim ou soif!")
                end
            end
        end
    end)
end

-- Animations de l'animal
function PlayAnimation(animType)
    if animType == 'sitdown' then
        if not CurrentAnimalIndex or not OwnedAnimals[CurrentAnimalIndex] then return end
        local model = OwnedAnimals[CurrentAnimalIndex].model
        if model == "a_c_rottweiler" then
            TaskStartScenarioInPlace(CurrentAnimal, "WORLD_DOG_SITTING_ROTTWEILER", 0, true)
        elseif model == "a_c_shepherd" then
            TaskStartScenarioInPlace(CurrentAnimal, "WORLD_DOG_SITTING_RETRIEVER", 0, true)
        elseif model == "a_c_rabbit_01" then
            TaskStartScenarioInPlace(CurrentAnimal, "WORLD_RABBIT_FLEE", 0, true)
        elseif model == "a_c_cat_01" then
            TaskStartScenarioInPlace(CurrentAnimal, "WORLD_CAT_SLEEPING_GROUND", 0, true)
        elseif model == "a_c_poodle" then
            TaskStartScenarioInPlace(CurrentAnimal, "WORLD_DOG_SITTING", 0, true)
        elseif model == "a_c_husky" or model == "a_c_poodle" then
            TaskStartScenarioInPlace(CurrentAnimal, "WORLD_DOG_SITTING", 0, true)
        else
            TaskStartScenarioInPlace(CurrentAnimal, "WORLD_DOG_SITTING", 0, true)
        end
    end
end

-- Toggle le suivi de l'animal
local isFollowing = true
function ToggleFollow()
    isFollowing = not isFollowing
    if isFollowing then
        TaskFollowToOffsetOfEntity(CurrentAnimal, PlayerPedId(), 0.5, 0.0, 0.0, 5.0, -1, 1.0, true)
    else
        ClearPedTasks(CurrentAnimal)
    end
end

-- Vérification de la touche F9
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if IsControlJustReleased(0, Config.Keys.openMenu) then
            -- Ouvrir le menu d'actions si :
            -- - le joueur possède au moins un animal (OwnedAnimals)
            -- - ou s'il y a déjà un animal spawné
            if not ESX.UI.Menu.IsOpen(GetCurrentResourceName(), 'animal_actions') then
                if #OwnedAnimals > 0 or AnimalSpawned then
                    OpenAnimalActionMenu()
                else
                    ESX.ShowNotification('Vous n\'avez pas d\'animaux. Rendez-vous à l\'animalerie pour en acheter.')
                end
            end
        end

        -- Vérifier si le joueur est près de l'animalerie
        local playerCoords = GetEntityCoords(PlayerPedId())
        for k,v in pairs(Config.PetShopLocation) do
            local distance = #(playerCoords - v.coords)
            if distance < 2.0 then
                ESX.ShowHelpNotification("Appuyez sur ~INPUT_CONTEXT~ pour accéder à l'animalerie")
                if IsControlJustReleased(0, 38) then
                    OpenPetShopMenu()
                end
            end
        end
    end
end)

-- Sauvegarde périodique des animaux en base (toutes les 5 minutes)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5 * 60 * 1000)
        if PlayerData and PlayerData.identifier and #OwnedAnimals > 0 then
            TriggerServerEvent('esx_animal:saveOwnedAnimals', OwnedAnimals)
        end
    end
end)

-- Event handlers pour les items
RegisterNetEvent('esx_animal:useFood')
AddEventHandler('esx_animal:useFood', function()
    if AnimalSpawned then
        -- Mettre à jour la faim de l'animal actif stocké
        if CurrentAnimalIndex and OwnedAnimals[CurrentAnimalIndex] then
            OwnedAnimals[CurrentAnimalIndex].hunger = 100
        end
        ESX.ShowNotification("Vous avez nourri votre animal")
    end
end)

RegisterNetEvent('esx_animal:useWater')
AddEventHandler('esx_animal:useWater', function()
    if AnimalSpawned then
        -- Mettre à jour la soif de l'animal actif stocké
        if CurrentAnimalIndex and OwnedAnimals[CurrentAnimalIndex] then
            OwnedAnimals[CurrentAnimalIndex].thirst = 100
        end
        ESX.ShowNotification("Vous avez donné à boire à votre animal")
    end
end)
