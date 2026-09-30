Config = {}

-- Configuração do Item de Óleo de Cozinha para Fritadeiras
Config.OilItem = "cooking_oil"
Config.OilMaxUses = 10 -- Quantidade de porções fritas suportadas por cada galão de óleo

-- Dicionário de Modelos e Estágios de Cozimento (Grelha)
-- Cada ingrediente que vai para a grelha possui 3 modelos 3D / tempos em tempo real:
-- 1. Raw (Cru) -> 2. Cooked (No ponto) -> 3. Burnt (Queimado)
Config.MeatModels = {
	["raw_meat"] = {
		label = "Carne Hambúrguer",
		item = "raw_meat",
		rewardItem = "burger_bacon",
		cookedLabel = "Carne no Ponto",
		burntLabel = "Carne Queimada",
		rawModel = "prop_cs_steak",
		cookedModel = "prop_cs_steak",
		burntModel = "prop_cs_steak",
		requiresFlip = true,
		cookTime = 10, -- 5s por lado
		burnTime = 20,
	},
	["raw_sausage"] = {
		label = "Salsicha",
		item = "raw_sausage",
		rewardItem = "hotdog",
		cookedLabel = "Salsicha Grelhada",
		burntLabel = "Salsicha Queimada",
		rawModel = "prop_cs_hotdog_02",
		cookedModel = "prop_cs_hotdog_02",
		burntModel = "prop_cs_hotdog_02",
		requiresFlip = true,
		cookTime = 8,
		burnTime = 16,
	},
	["raw_fish"] = {
		label = "Filé de Peixe",
		item = "raw_fish",
		rewardItem = "fishburger",
		cookedLabel = "Peixe Grelhado",
		burntLabel = "Peixe Queimado",
		rawModel = "prop_defilied_ragdoll_01",
		cookedModel = "prop_defilied_ragdoll_01",
		burntModel = "prop_defilied_ragdoll_01",
		requiresFlip = true,
		cookTime = 12,
		burnTime = 22,
	},
}

-- Dicionário de Frituras (Fritadeira + Cesta)
Config.FriedModels = {
	["frenchfries"] = {
		label = "Porção de Batata Frita",
		item = "raw_fries",
		rewardItem = "frenchfries",
		rawModel = "prop_kitch_pot_fry",
		cookedModel = "prop_kitch_pot_fry",
		cookTime = 8,
		burnTime = 18,
	},
}

-- Mapeamento Legado / Dicionário Dinâmico de Props
Config.PropDictionary = {
	["raw_meat"] = {
		model = "prop_cs_steak",
		colorChange = true,
		stages = {
			raw = { r = 255, g = 255, b = 255 },
			cooked = { r = 150, g = 100, b = 50 },
			burnt = { r = 30, g = 30, b = 30 },
		},
	},
	["raw_sausage"] = {
		model = "prop_cs_hotdog_02",
		colorChange = true,
		stages = {
			raw = { r = 255, g = 180, b = 180 },
			cooked = { r = 180, g = 90, b = 30 },
			burnt = { r = 40, g = 20, b = 10 },
		},
	},
	["raw_fish"] = {
		model = "prop_defilied_ragdoll_01",
		colorChange = true,
		stages = {
			raw = { r = 200, g = 200, b = 200 },
			cooked = { r = 255, g = 200, b = 150 },
			burnt = { r = 50, g = 50, b = 50 },
		},
	},
	["lettuce"] = {
		model = "prop_veg_crop_03_cab",
		colorChange = false,
	},
}

-- Estações de Trabalho (Workstations Modulares)
Config.Workstations = {
	["grill"] = {
		label = "Grelha",
		type = "fire",
		animDict = "amb@prop_human_bbq@male@base",
		animClip = "base",
		propUsed = "prop_fish_slice_01", -- Espátula
	},
	["fryer"] = {
		label = "Fritadeira",
		type = "fire",
		animDict = "mini@repair",
		animClip = "fixing_a_ped",
		propUsed = "prop_kitch_pot_fry",
		requiresOil = true,
	},
	["cutting_board"] = {
		label = "Tábua de Corte",
		type = "manual",
		animDict = "anim@heists@prison_heiststation@cop_reactions",
		animClip = "cop_b_idle",
		propUsed = "prop_knife",
	},
	["assembly"] = {
		label = "Bancada de Montagem",
		type = "manual",
		animDict = "anim@amb@business@weed@weed_inspecting_high_dry@",
		animClip = "weed_inspecting_high_base_inspector",
		propUsed = nil,
	},
	["drinks"] = {
		label = "Dispensador de Bebidas",
		type = "manual",
		animDict = "anim@amb@business@weed@weed_inspecting_high_dry@",
		animClip = "weed_inspecting_high_base_inspector",
		propUsed = "prop_plastic_cup_02",
	},
}

-- Modelos de Props Nativos do GTA V / MLOs que automaticamente funcionam como Estações
Config.NativeMLOModels = {
	grill = {
		"prop_bbq_3",
		"prop_bbq_1",
		"v_serv_ct_grill",
		"prop_grill_01",
		-1876087649, -- Grelha MLO Burger Shot
	},
	fryer = {
		"prop_kitch_pot_fry",
		"prop_fryer_01",
		1539659769, -- Fritadeira MLO Burger Shot
	},
	cutting_board = {
		"prop_knife",
		"v_res_tre_kitchenboard",
		1306960905, -- Microondas / Preparo Rápido MLO Burger Shot
	},
	drinks = {
		"prop_soda_disp_01",
		"prop_vend_soda_02",
		1158163071, -- Dispensador de Sucos MLO Burger Shot
	},
	assembly = {
		"prop_hotdog_stand_01",
		"v_res_kitchencounter",
		-938179374,  -- Cafeteira MLO Burger Shot
	},
}

-- Itens Colocáveis (Props Físicos no Mundo / Casas / Rua)
Config.PlaceableProps = {
	["granolla_grill"] = {
		label = "Churrasqueira Móvel",
		model = "prop_bbq_3",
		workstation = "grill",
		maxCapacity = 4,
		gridOffsets = {
			vector3(0.15, 0.15, 0.82),
			vector3(-0.15, 0.15, 0.82),
			vector3(0.15, -0.15, 0.82),
			vector3(-0.15, -0.15, 0.82),
		},
	},
	["granolla_fryer"] = {
		label = "Fritadeira Elétrica",
		model = "prop_kitch_pot_fry",
		workstation = "fryer",
		requiresOil = true,
		maxCapacity = 1,
		gridOffsets = {
			vector3(0.0, 0.0, 0.1),
		},
	},
	["granolla_foodcart"] = {
		label = "Carrinho de Cachorro Quente",
		model = "prop_hotdog_stand_01",
		workstation = "assembly",
		maxCapacity = 2,
		gridOffsets = {
			vector3(0.2, 0.0, 1.1),
			vector3(-0.2, 0.0, 1.1),
		},
	},
	["granolla_table"] = {
		label = "Mesa de Plástico",
		model = "prop_ven_market_table1",
		workstation = nil,
	},
	["granolla_gazebo"] = {
		label = "Tenda (Gazebo)",
		model = "prop_gazebo_02",
		workstation = nil,
	},
	["granolla_chair"] = {
		label = "Cadeira Dobrável",
		model = "prop_chair_01b",
		workstation = nil,
	},
	["granolla_flood_light"] = {
		label = "Luz Externa",
		model = "prop_worklight_03b",
		workstation = nil,
	},
	["granolla_soda_machine"] = {
		label = "Caixa Térmica (Bebidas)",
		model = "prop_vend_soda_02",
		workstation = "assembly",
	},
}

-- Configuração dos Restaurantes Fixos Refatorada
Config.Restaurants = {
	["burgershot"] = {
		label = "Burger Shot",
		jobRequired = "hotdog", -- Job necessário para acessar painel/entregas
		deliveryStartPoint = vector3(-1198.11, -899.04, 13.37),
		npcCounterPoint = vector3(-1195.07, -892.47, 12.89),
		blip = {
			enabled = true,
			sprite = 106,
			color = 5,
			scale = 0.8,
			coords = vector3(-1194.08, -893.59, 13.98),
		},
		npcSpawnPoints = {
			vector3(-1207.9, -897.63, 12.16),
			vector3(-1232.29, -909.96, 10.83),
			vector3(-1169.72, -866.43, 13.09),
		},
		-- Estações Fixas do MLO do Burger Shot com Hashes e Coordenadas Capturados
		fixedWorkstations = {
			{ id = "bs_grill_1", workstation = "grill", coords = vector3(-1195.72, -897.25, 13.90), heading = -15.5, rot = vector3(0.0, 0.0, -15.5), radius = 1.2, useExistingModel = true },
			{ id = "bs_grill_2", workstation = "grill", coords = vector3(-1195.14, -897.50, 13.90), heading = -15.5, rot = vector3(0.0, 0.0, -15.5), radius = 1.2, useExistingModel = true },
			{ id = "bs_fryer_1", workstation = "fryer", coords = vector3(-1195.39, -900.04, 13.79), heading = 74.5, rot = vector3(0.0, 0.0, 74.5), radius = 1.2, requiresOil = true, useExistingModel = true },
			{ id = "bs_juices_1", workstation = "drinks", coords = vector3(-1190.49, -898.39, 14.21), heading = 74.5, rot = vector3(0.0, 0.0, 74.5), radius = 1.2, useExistingModel = true },
			{ id = "bs_coffee_1", workstation = "assembly", coords = vector3(-1200.52, -896.74, 14.10), heading = 35.0, rot = vector3(0.0, 0.0, 35.0), radius = 1.2, useExistingModel = true },
			{ id = "bs_microwave_1", workstation = "cutting_board", coords = vector3(-1198.68, -899.14, 14.05), heading = 254.5, rot = vector3(0.0, 0.0, 254.5), radius = 1.2, useExistingModel = true },
		},
		-- Bandejas de Balcão (Stashes compartilhadas para servir lanches)
		trays = {
			{ id = "bs_tray_1", label = "Bandeja Balcão 1", coords = vector3(-1195.30, -892.35, 14.00), radius = 1.2 },
			{ id = "bs_tray_2", label = "Bandeja Balcão 2", coords = vector3(-1193.85, -892.35, 14.00), radius = 1.2 },
		},
		-- Caixas Registradoras (POS / Cobrança aos clientes com envio direto à conta da empresa)
		registers = {
			{ id = "bs_register_1", label = "Caixa Registradora 1", coords = vector3(-1196.00, -892.95, 14.00), radius = 1.2 },
			{ id = "bs_register_2", label = "Caixa Registradora 2", coords = vector3(-1194.50, -892.95, 14.00), radius = 1.2 },
		},
	},
}

Config.AllowedIngredients = {
	"raw_meat",
	"lettuce",
	"cheese",
	"bread",
	"raw_sausage",
	"raw_fish",
	"cooking_oil",
	"raw_potato",
	"raw_fries",
	"raw_tomato",
	"tomato",
	"raw_cheese",
	"raw_onion",
	"sliced_onion",
	"bacon",
	"empty_cup",
}

-- Receitas fixas padrão
Config.DefaultRecipes = {
	{
		id = "default_burger_1",
		name = "X-Burguer Tradicional",
		result = "burger_bacon",
		workstation = "grill",
		job = "public",
		is_public = true,
		ingredients = {
			{ item = "raw_meat", amount = 1 },
		},
	},
	{
		id = "default_hotdog_1",
		name = "Cachorro Quente Simples",
		result = "hotdog",
		workstation = "grill",
		job = "public",
		is_public = true,
		ingredients = {
			{ item = "raw_sausage", amount = 1 },
		},
	},
	{
		id = "default_cut_fries",
		name = "Fatiar Batatas em Palito",
		result = "raw_fries",
		workstation = "cutting_board",
		job = "public",
		is_public = true,
		ingredients = {
			{ item = "raw_potato", amount = 1 },
		},
	},
	{
		id = "default_cut_tomato",
		name = "Fatiar Tomate",
		result = "tomato",
		workstation = "cutting_board",
		job = "public",
		is_public = true,
		ingredients = {
			{ item = "raw_tomato", amount = 1 },
		},
	},
	{
		id = "default_cut_cheese",
		name = "Fatiar Queijo Cheddar",
		result = "cheese",
		workstation = "cutting_board",
		job = "public",
		is_public = true,
		ingredients = {
			{ item = "raw_cheese", amount = 1 },
		},
	},
	{
		id = "default_drink_cola",
		name = "Refrigerante de Copo",
		result = "burger_softdrink",
		workstation = "drinks",
		job = "public",
		is_public = true,
		ingredients = {
			{ item = "empty_cup", amount = 1 },
		},
	},
	{
		id = "default_drink_orange",
		name = "Suco de Frutas",
		result = "juice_orange",
		workstation = "drinks",
		job = "public",
		is_public = true,
		ingredients = {
			{ item = "empty_cup", amount = 1 },
		},
	},
}

Config.AllowedResultItems = {
	"burger_bacon",
	"hotdog",
	"fishburger",
	"custom_meal_1",
	"custom_meal_2",
	"raw_meat",
	"raw_fries",
	"frenchfries",
	"tomato",
	"cheese",
	"sliced_onion",
	"empty_cup",
	"burger_softdrink",
	"juice_orange",
}

Config.NPCLogic = {
	dutyTimeRequiredMin = 10,
	checkIntervalMin = 5,
	chanceIfSold = 40,
}
