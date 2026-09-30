# 🍔 Granolla Restaurants — Sistema Avançado de Gastronomia & Cozinha Física 3D

[![Framework](https://img.shields.io/badge/Framework-QBox%20(qbx__core)-10b981?style=for-the-badge)](https://github.com/Qbox-project/qbx_core)
[![Inventory](https://img.shields.io/badge/Inventory-ox__inventory-10b981?style=for-the-badge)](https://github.com/overextended/ox_inventory)
[![Target](https://img.shields.io/badge/Target-ox__target-10b981?style=for-the-badge)](https://github.com/overextended/ox_target)
[![Banking](https://img.shields.io/badge/Banking-Renewed--Banking-10b981?style=for-the-badge)](https://github.com/Renewed-Scripts/Renewed-Banking)
[![UI Standard](https://img.shields.io/badge/UI-Lation%20Modern%20(Emerald)-059669?style=for-the-badge)](file:///c:/Server%20Fivem%20Teste/_kb/ui/LATION_DESIGN_SYSTEM.md)

O **Granolla Restaurants** é um ecossistema gastronômico definitivo e hiper-imersivo para FiveM. O recurso substitui menus 2D estáticos por **mecânicas físicas tridimensionais interativas no mundo do jogo**, permitindo que os jogadores controlem espátulas, facas, cestos de fritura e dispensadores de bebidas diretamente com o mouse, acompanhados de áudio procedural e efeitos visuais volumétricos.

---

## 🌟 Destaques & Pilares de Arquitetura

- **Sem Menus Estáticos Fictícios:** Todo o processo culinário ocorre no espaço 3D do mundo através de câmeras de bancada e ray-plane intersections.
- **Áudio Procedural Web Audio API:** Chiado da chapa, borbulhas da fritadeira, impacto da lâmina na madeira, fluxo de refrigerante e som mecânico da tampa plástica ("SNAP!") sintetizados na NUI, sem depender de arquivos externos pesados ou corrompidos.
- **Economia Integrada & Anti-Exploit:** Validação rígida com tokens temporais server-side, consumo de insumos no `ox_inventory` e faturamento empresarial com depósitos automáticos via `Renewed-Banking`.
- **Compatibilidade com MLOs Nativos:** Reconhecimento automático de grelhas, fritadeiras e bancadas já presentes nos interiores do GTA V (ex: Burger Shot MLO) sem necessidade de spawnar props duplicados.

---

## 🍳 As 5 Estações Culinárias Físicas 3D

```
[1. TÁBUA DE CORTE] ──> Fatiar Batatas (/testcut) ──────> [2. FRITADEIRA 3D] ──> Batatas Crocantes (/testfryer) ┐
                    ──> Fatiar Tomate/Queijo/Carne ──> [3. CHAPA 3D] virar com espátula (/testkitchen)          │
                                                                   │                                           │
                                                                   ▼                                           │
[6. BALCÃO & POS]   <── Servir Combo na Bandeja ────── [4. MESA DE MONTAGEM] Hambúrguer Embrulhado (/testassembly) ┘
    ▲                                                              │
    └────────────────── [5. MÁQUINA DE BEBIDAS] Refrigerante Gelado (/testdrinks)
```

### 1. 🥩 Chapa de Cozimento com Espátula Física no Mouse ([`client/props.lua`](file:///c:/Server%20Fivem%20Teste/resources/[ai_create]/granolla_restaurants/client/props.lua))
- **Espátula no Cursor:** A espátula 3D (`mxc_kitchen_prop_tools_spatula` com fallback) tem sua ponta alinhada ao mouse via cálculo de *Ray-Plane Intersection*.
- **4 Estados de Interação do Cursor:**
  1. *Hover:* Círculo branco 3D de foco ao aproximar de ingredientes ou carnes.
  2. *Grabbed:* O ped segura o ingrediente na mão esquerda enquanto a espátula repousa na direita.
  3. *Target Zone:* Demarcação verde pontilhada indicando onde soltar a carne na chapa.
  4. *Ação da Espátula:* Inclinação física de 180° para virar a carne no ponto e recolher.
- **Áudio:** Som contínuo de fritura que se intensifica conforme a quantidade de carnes chiando na chapa.

### 2. 🍟 Estação de Fritura com Cesto Móvel 3D ([`client/fryer.lua`](file:///c:/Server%20Fivem%20Teste/resources/[ai_create]/granolla_restaurants/client/fryer.lua))
- **Cesto Metálico Móvel:** O cesto (`mxc_kitchen_prop_tools_friesbasket`) repousa suspenso e afunda no óleo quente ao receber batatas cortadas (`raw_fries`).
- **Efeitos Volumétricos:** Vapor quente, partículas de gordura e borbulhas contínuas de óleo.
- **Temporizador NanoRing:** Medidor circular com contagem regressiva em tempo real.
- **Drenagem & Pá de Batatas:** O cesto sobe escorrendo o excesso de óleo exibindo batatas douradas, recolhidas com a pá metálica para dentro da caixinha do Burger Shot (`frenchfries`).

### 3. 🔪 Tábua de Corte com Faca de Chef 3D ([`client/cutting_board.lua`](file:///c:/Server%20Fivem%20Teste/resources/[ai_create]/granolla_restaurants/client/cutting_board.lua))
- **Fatiamento Rítmico:** O jogador controla a faca de chef suspensa sobre a tábua de madeira (`v_res_tre_kitchenboard`).
- **Golpe com [ESPAÇO] ou [CLIQUE]:** Descida acelerada da lâmina com impacto sonoro na madeira (`CHOP!`).
- **Desacoplamento Físico de Fatias:** Cada corte gera uma fatia 3D independente que tomba e se acomoda na lateral da tábua.
- **Insumos Suportados:**
  - Batata Inteira (`raw_potato`) ➔ Batatas em Palito (`raw_fries`)
  - Tomate Inteiro (`raw_tomato`) ➔ Fatias de Tomate (`tomato`)
  - Bloco de Queijo (`raw_cheese`) ➔ Fatias de Cheddar (`cheese`)
  - Cebola Inteira (`raw_onion`) ➔ Cebola Fatiada (`sliced_onion`)
  - Peça de Carne (`raw_meat`) ➔ Carnes moldadas para hambúrguer

### 4. 🍔 Mesa de Montagem em Camadas 3D ([`client/assembly.lua`](file:///c:/Server%20Fivem%20Teste/resources/[ai_create]/granolla_restaurants/client/assembly.lua))
- **Bancada com Potes de Condimentos:** Papel manteiga aberto central com recipientes de ingredientes ao redor.
- **Empilhamento Cumulativo $+Z$:** Pão Inferior ➔ Carne Grelhada ➔ Queijo Cheddar ➔ Alface Crocante ➔ Tomate ➔ Bacon ➔ Pão Superior.
- **Embrulho com Sineta ("Ding!"):** Ao finalizar, o papel se fecha no hambúrguer embrulhado (`burger_bacon`), pronto para servir.

### 5. 🥤 Máquina de Bebidas & Refrigerante 3D ([`client/drinks.lua`](file:///c:/Server%20Fivem%20Teste/resources/[ai_create]/granolla_restaurants/client/drinks.lua))
- **Dispenser com Copo Descartável:** O copo (`prop_plastic_cup_02`) é posicionado sob as torneiras do dispensador.
- **Seleção de Sabores:** Cola, Laranja, Limão ou Uva.
- **Acionamento da Torneira:** Fluxo de refrigerante com borbulhas e áudio contínuo de enchimento.
- **Tampa e Canudo ("SNAP!"):** Aplicação da tampa plástica com som mecânico de travamento, transformando no copo oficial do Burger Shot (`burger_softdrink` ou `juice_orange`).

---

## 🍱 Balcão de Atendimento & Caixa Registradora (POS)

### Bandejas de Servir (Trays) ([`client/counter.lua`](file:///c:/Server%20Fivem%20Teste/resources/[ai_create]/granolla_restaurants/client/counter.lua))
- Props de bandejas (`prop_tray_01`) posicionados sobre os balcões.
- Registradas no `ox_inventory` como stashes públicas de 25 kg (`RegisterStash`), permitindo que o atendente deposite o combo e o cliente retire seu pedido diretamente.

### Caixa Registradora POS & Repasse Empresarial ([`server/economy.lua`](file:///c:/Server%20Fivem%20Teste/resources/[ai_create]/granolla_restaurants/server/economy.lua))
- Atendente seleciona a caixa registradora (`prop_till_01`) e envia a conta para o cliente mais próximo via `ox_lib:inputDialog`.
- O cliente recebe um modal na tela (`ox_lib:alertDialog`) confirmando o valor e pagando com Dinheiro ou Banco.
- O valor é depositado diretamente na conta bancária da empresa/society do restaurante via `Renewed-Banking` (`exports['Renewed-Banking']:addAccountMoney(job, amount)`).

---

## 🏛️ Sistema de Compatibilidade com MLOs de Restaurantes

O `granolla_restaurants` possui **detecção automática de MLOs e mapeamento espacial inteligente** ([`shared/kitchens.lua`](file:///c:/Server%20Fivem%20Teste/resources/[ai_create]/granolla_restaurants/shared/kitchens.lua) e [`client/kitchens.lua`](file:///c:/Server%20Fivem%20Teste/resources/[ai_create]/granolla_restaurants/client/kitchens.lua)), ativando todas as estações culinárias 3D nas posições originais dos mapas sem necessidade de comandos de spawn:

| MLO Suportado | Resource do Mapa | Estações Mapeadas | Status |
| :--- | :--- | :--- | :---: |
| **Burger Shot (Uniqx)** | `uniqx_burgershot` | 1x Chapa 3D, 3x Fritadeiras, 2x Mesas Montagem, 2x Tábuas Corte, Bebidas, Balcão & Bandejas POS | ✅ **Ativo & Calibrado** |
| **Burger Shot (Gabz)** | `cfx-gabz-burgershot`| 1x Chapa 3D, 2x Fritadeiras, 2x Mesas Montagem, Tábua Corte, Lixeira | ✅ Suportado |
| **Burger Shot (WX)** | `wxmaps_burgershot` | 4x Chapas 3D, 8x Fritadeiras, 8x Mesas Montagem, 4x Tábuas Corte | ✅ Suportado |
| **Burger Shot Sandy Shores** | `cfx_gn_burgershot_sandy` | 1x Chapa 3D, 2x Fritadeiras, 2x Mesas Montagem, Tábua Corte | ✅ Suportado |
| **Horny's (Gabz)** | `cfx-gabz-hornys` | 1x Chapa 3D, 1x Fritadeira, 2x Mesas Montagem, Tábua Corte | ✅ Suportado |
| **Drive-in La Puerta (MXC)** | `cfx-mxc-drivein` | 1x Chapa 3D, 2x Fritadeiras, 2x Mesas Montagem, Tábua Corte | ✅ Suportado |
| **Drive-in Paleto (MXC)** | `cfx-mxc-drivein` | 1x Chapa 3D, 2x Fritadeiras, 2x Mesas Montagem, Tábua Corte | ✅ Suportado |
| **Rex's Diner (Map4All)** | `map4all-rexs-diner` | 1x Chapa 3D, 2x Fritadeiras, 2x Mesas Montagem, Tábua Corte | ✅ Suportado |
| **Wigwam Diner (Kiiya)** | `kiiya_wigwam` | 1x Chapa 3D, 2x Fritadeiras, 2x Mesas Montagem, Tábua Corte | ✅ Suportado |
| **Route 68 Diner (Kiiya)** | `kiiya_r68_diner_p` | 1x Chapa 3D, 1x Fritadeira, 1x Mesa Montagem, Tábua Corte | ✅ Suportado |
| **Space Restaurant (MXC)** | `cfx-mxc-spacerestaurant` | 1x Chapa 3D, 2x Fritadeiras, 2x Mesas Montagem, Tábua Corte | ✅ Suportado |
| **Space Restaurant Vinewood**| `cfx-mxc-spacerestaurant`| 1x Chapa 3D, 2x Fritadeiras, 2x Mesas Montagem, Tábua Corte | ✅ Suportado |
| **Mirror Park Diner (MXC)** | `cfx-mxc-mirror` | 1x Chapa 3D, 2x Fritadeiras, 2x Mesas Montagem, Tábua Corte | ✅ Suportado |

> [!TIP]
> O **Burger Shot Uniqx (`uniqx_burgershot`)** opera de forma 100% nativa sem necessidade de modificação em seus arquivos de streaming `.ytyp` ou `.ymap`. O `granolla_restaurants` vincula automaticamente as estações (`ox_target`) sobre as superfícies e modelos originais.

---

## 📦 Lista de Itens do `ox_inventory`

Todos os itens necessários estão cadastrados em [`resources/[ox]/ox_inventory/data/items.lua`](file:///c:/Server%20Fivem%20Teste/resources/[ox]/ox_inventory/data/items.lua):

| Item | Label | Peso (g) | Tipo | Utilidade |
| :--- | :--- | :---: | :---: | :--- |
| `kitchen_knife` | Faca de Cozinha | 300 | Ferramenta | Faca de chef para a Tábua de Corte |
| `cooking_oil` | Óleo de Cozinha | 1000 | Insumo | Abastece a Fritadeira Industrial (rende 10 porções) |
| `raw_potato` | Batata Inteira | 150 | Ingrediente | Fatiada na tábua de corte para gerar `raw_fries` |
| `raw_fries` | Batatas Cortadas | 150 | Ingrediente | Pronta para mergulhar no óleo quente da Fritadeira |
| `raw_tomato` | Tomate Inteiro | 100 | Ingrediente | Fatiado na tábua para gerar `tomato` |
| `raw_cheese` | Bloco de Queijo | 200 | Ingrediente | Fatiado na tábua para gerar `cheese` |
| `raw_onion` | Cebola Inteira | 80 | Ingrediente | Fatiada na tábua para gerar `sliced_onion` |
| `raw_meat` | Carne Crua | 200 | Ingrediente | Bife cru para grelhar na chapa com a espátula |
| `raw_sausage` | Salsicha Crua | 100 | Ingrediente | Salsicha para grelhar para cachorro quente |
| `raw_fish` | Peixe Cru | 250 | Ingrediente | Filé de peixe para o hambúrguer de peixe |
| `bread` | Pão de Hambúrguer | 100 | Ingrediente | Base e topo na Mesa de Montagem |
| `cheese` | Queijo Fatiado | 50 | Ingrediente | Fatias de cheddar para o hambúrguer |
| `lettuce` | Alface Crocante | 50 | Ingrediente | Folhas de alface para montagem |
| `tomato` | Tomate Fatiado | 50 | Ingrediente | Fatias de tomate fresco |
| `bacon` | Fatias de Bacon | 60 | Ingrediente | Tiras crocantes de bacon |
| `sliced_onion` | Cebola Fatiada | 40 | Ingrediente | Fatias de cebola para lanches |
| `empty_cup` | Copo Descartável | 10 | Recipiente | Copo vazio para a Máquina de Bebidas |
| `burger_bacon` | X-Burguer Bacon | 300 | Consumível | Hambúrguer artesanal embrulhado (Fome +75) |
| `hotdog` | Cachorro Quente | 250 | Consumível | Cachorro quente tradicional (Fome +60) |
| `fishburger` | Hambúrguer de Peixe | 300 | Consumível | Lanche de filé de peixe grelhado (Fome +65) |
| `frenchfries` | Batata Frita | 200 | Consumível | Batatas douradas na caixinha (Fome +45) |
| `chicken_nuggets`| Nuggets de Frango | 200 | Consumível | Empanados de frango crocantes (Fome +50) |
| `burger_softdrink`| Refrigerante de Copo| 350 | Consumível | Refrigerante com gás, tampa e canudo (Sede +70) |
| `juice_orange` | Suco de Frutas | 350 | Consumível | Suco natural gelado com canudo (Sede +75) |
| `granolla_grill` | Churrasqueira Móvel | 15000 | Estrutura | Prop colocável com 4 slots de grelha |
| `granolla_fryer` | Fritadeira Elétrica | 8000 | Estrutura | Prop colocável com cesto móvel |
| `granolla_foodcart`| Carrinho Hot Dog | 25000 | Estrutura | Lanchonete móvel portátil |
| `granolla_table` | Mesa de Plástico | 5000 | Estrutura | Mesa para clientes |
| `granolla_chair` | Cadeira Dobrável | 2000 | Estrutura | Cadeira dobrável para clientes |
| `granolla_gazebo`| Tenda (Gazebo) | 10000 | Estrutura | Tenda protegida de sol e chuva |
| `granolla_flood_light`| Luz Externa | 3000 | Estrutura | Iluminação noturna de trabalho |
| `granolla_soda_machine`| Caixa Térmica | 6000 | Estrutura | Dispensador de bebidas portátil |

---

## 🎮 Comandos de Teste & Administração

| Comando | Descrição | Permissão |
| :--- | :--- | :--- |
| `/testcut` | Abre a Tábua de Corte com Faca de Chef 3D | Livre / Dev |
| `/testfryer` | Abre a Estação de Fritura com Cesto e Pá de Batatas 3D | Livre / Dev |
| `/testkitchen` | Abre a Chapa com Espátula Física orientada pelo Mouse | Livre / Dev |
| `/testassembly` | Abre a Mesa de Montagem de Hambúrguer com Empilhamento 3D | Livre / Dev |
| `/testdrinks` | Abre o Dispensador de Bebidas & Refrigerante 3D | Livre / Dev |
| `/tablet_restaurante` | Abre o Tablet NUI de Gerenciamento de Receitas do Restaurante | Boss do Job |
| `/getcoords` | Copia coordenadas `vector3` e `vector4` no console F8 | Admin / Dev |
| `/onduty` | Entra em serviço no restaurante | Funcionário |

---

## 📋 Guia de Testes Passo a Passo

Para instruções detalhadas de teste, checklists e procedimentos operacionais, consulte:  
👉 **[`TEST_GUIDE.md`](file:///c:/Server%20Fivem%20Teste/resources/[ai_create]/granolla_restaurants/TEST_GUIDE.md)**
