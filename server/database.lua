-- server/database.lua
local function InitializeDatabase()
    -- Tabela Principal dos Restaurantes
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS granolla_restaurants (
            id INT AUTO_INCREMENT PRIMARY KEY,
            business_name VARCHAR(100) NOT NULL,
            owner VARCHAR(50) NOT NULL,
            social_handle VARCHAR(50),
            balance INT DEFAULT 0,
            stash_data LONGTEXT
        )
    ]])

    -- Tabela das Receitas Customizadas
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS granolla_recipes (
            id INT AUTO_INCREMENT PRIMARY KEY,
            restaurant_id INT DEFAULT 0,
            recipe_name VARCHAR(100) NOT NULL,
            result_item VARCHAR(50) NOT NULL,
            ingredients JSON NOT NULL,
            workstation VARCHAR(50) DEFAULT 'grill',
            job VARCHAR(50) DEFAULT 'public',
            is_public BOOLEAN DEFAULT FALSE,
            image VARCHAR(255)
        )
    ]])

    -- Garante que colunas novas existam sem floodar o console do oxmysql
    MySQL.query('SHOW COLUMNS FROM granolla_recipes LIKE "job"', {}, function(res)
        if not res or #res == 0 then
            MySQL.query('ALTER TABLE granolla_recipes ADD COLUMN job VARCHAR(50) DEFAULT "public"')
        end
    end)
    
    MySQL.query('SHOW COLUMNS FROM granolla_recipes LIKE "is_public"', {}, function(res)
        if not res or #res == 0 then
            MySQL.query('ALTER TABLE granolla_recipes ADD COLUMN is_public BOOLEAN DEFAULT FALSE')
        end
    end)

    -- Tabela de Props Salvos no Mundo
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS granolla_props_saved (
            id INT AUTO_INCREMENT PRIMARY KEY,
            owner VARCHAR(50) NOT NULL,
            prop_model VARCHAR(100) NOT NULL,
            item_name VARCHAR(50) NOT NULL,
            coords JSON NOT NULL,
            rotation JSON NOT NULL,
            job VARCHAR(50) DEFAULT 'unemployed'
        )
    ]])
    
    MySQL.query('SHOW COLUMNS FROM granolla_props_saved LIKE "job"', {}, function(res)
        if not res or #res == 0 then
            MySQL.query('ALTER TABLE granolla_props_saved ADD COLUMN job VARCHAR(50) DEFAULT "unemployed"')
        end
    end)

    print('^2[Granolla Restaurants]^0 Banco de dados inicializado/verificado com sucesso!')
end

CreateThread(function()
    InitializeDatabase()
end)
