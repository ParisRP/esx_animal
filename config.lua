Config = {}

-- Coordonnées de l'animalerie
Config.PetShopLocation = {
    {
        coords = vector3(562.19, 2741.30, 42.87),
        blipSprite = 267,
        blipColor = 3,
        blipScale = 0.8,
        blipName = "Animalerie"
    }
}

-- Liste des animaux disponibles
Config.Animals = {
    {label = "Chien Rottweiler", model = "a_c_rottweiler", price = 50000},
    {label = "Chien Berger", model = "a_c_shepherd", price = 45000},
    {label = "Chat", model = "a_c_cat_01", price = 30000},
    {label = "Lapin", model = "a_c_rabbit_01", price = 25000},
    {label = "Husky", model = "a_c_husky", price = 55000},
    {label = "Caniche", model = "a_c_poodle", price = 40000}
}

-- Items de nourriture
Config.FoodItems = {
    {name = "pet_food", label = "Pet Food", price = 50},
    {name = "pet_water", label = "Pet Water", price = 25}
}

-- Distance maximale entre le joueur et son animal
Config.MaxDistance = 30.0

-- Temps en minutes avant que l'animal n'ait faim
Config.HungerTime = 30

-- Touches par défaut
Config.Keys = {
    openMenu = 56, -- F9
    whistle = 47   -- G
}
