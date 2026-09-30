# 🧪 Guia de Testes Completo — `granolla_restaurants` (Engine 3D, MLOs & Auditoria de Segurança)

> **Resource:** `granolla_restaurants` (Granolla Restaurants — Sistema Avançado de Gastronomia & Fast-Food)  
> **Framework:** QBox (`qbx_core`) | `ox_lib` (3.32.2) | `ox_inventory` (2.44.8) | `ox_target` | `Renewed-Banking` | `oxmysql`  
> **Design System:** Lation Modern UI (Emerald Edition — `#10b981` / `#6afe87`)  
> **Status:** 100% Auditado, Anti-Exploit Blindado & Sintaxe Lua 5.4 Validada (24 arquivos)  
> **Idioma:** Português (pt-BR)  

---

## 📋 Sumário
1. [Pré-requisitos & Preparação do Personagem](#1-pré-requisitos--preparação-do-personagem)
2. [Lista Completa de Invocação de Itens (/giveitem)](#2-lista-completa-de-invocação-de-itens-giveitem)
3. [Comandos de Teste & Atalhos F8](#3-comandos-de-teste--atalhos-f8)
4. [Módulo 1: Ferramentas Admin & Utilitários (/getcoords & /spatulatune)](#4-módulo-1-ferramentas-admin--utilitários)
5. [Módulo 2: Tablet de Gerenciamento & Cardápio (/tablet_restaurante)](#5-módulo-2-tablet-de-gerenciamento--cardápio)
6. [Módulo 3: Modo Construção & Props Móveis do Inventário](#6-módulo-3-modo-construção--props-móveis-do-inventário)
7. [Módulo 4: Engine de Culinária em Tempo Real na Grelha](#7-módulo-4-engine-de-culinária-em-tempo-real-na-grelha)
8. [Módulo 5: Tábua de Corte com Faca de Chef 3D (/testcut)](#8-módulo-5-tábua-de-corte-com-faca-de-chef-3d-testcut)
9. [Módulo 6: Estação de Fritura com Cesto Móvel 3D (/testfryer)](#9-módulo-6-estação-de-fritura-com-cesto-móvel-3d-testfryer)
10. [Módulo 7: Chapa de Cozimento com Espátula no Mouse (/testkitchen)](#10-módulo-7-chapa-de-cozimento-com-espátula-no-mouse-testkitchen)
11. [Módulo 8: Mesa de Montagem em Camadas 3D (/testassembly)](#11-módulo-8-mesa-de-montagem-em-camadas-3d-testassembly)
12. [Módulo 9: Dispensador de Refrigerante & Sucos 3D (/testdrinks)](#12-módulo-9-dispensador-de-refrigerante--sucos-3d-testdrinks)
13. [Módulo 10: Balcão de Atendimento (Bandejas & Caixa POS)](#13-módulo-10-balcão-de-atendimento-bandejas--caixa-pos)
14. [Módulo 11: Atendimento a Clientes NPCs](#14-módulo-11-atendimento-a-clientes-npcs)
15. [Módulo 12: Sistema de Entregas & Delivery GPS](#15-módulo-12-sistema-de-entregas--delivery-gps)
16. [Módulo 13: Validação Completa no MLO Burger Shot (uniqx_burgershot)](#16-módulo-13-validação-completa-no-mlo-burger-shot-uniqx_burgershot)
17. [Módulo 14: Guia de Teste Anti-Exploit & Blindagem Server-Side](#17-módulo-14-guia-de-teste-anti-exploit--blindagem-server-side)
18. [Módulo 15: Coordenadas & Teleportes Rápidos](#18-módulo-15-coordenadas--teleportes-rápidos)
19. [Matriz de Verificação / Checklist de Homologação](#19-matriz-de-verificação--checklist-de-homologação)

---

## 1. ⚙️ Pré-requisitos & Preparação do Personagem

### 1.1 Configuração de Emprego (Job)
Para testar todas as funcionalidades (incluindo o Tablet de Gerente, caixas registradoras POS e bancadas protegidas):
- **Job Padrão no Config:** `hotdog`
- **Cargo:** Gerente / Chefe (`grade = 4` ou `isboss = true`)

**Comandos no Console F8 ou RCON Admin:**
```bash
setjob 1 hotdog 4
onduty
```

*(Opcional: Caso deseje limpar o inventário antes dos testes, use `clearinv 1`)*

---

## 2. 🎒 Kit Admin Automático & Invocação de Itens (`/kitculinaria`)

Você pode gerar automaticamente os itens no seu inventário com um único comando no **Chat** ou no **F8**:

### Comandos Rápidos de Kit:
- `/kitculinaria` ou `/givekitchenkit` : Adiciona instantaneamente todos os **13 Insumos Brutos de Culinária** (faca, batata, tomate, queijo, cebola, carnes, etc. ~23kg).
- `/kitculinaria all` ou `/kitculinaria tudo` : Adiciona os **33 Itens** de uma só vez (brutos, processados, prontos e estruturas).
- `/kitculinaria processados` : Adiciona apenas insumos fatiados/cortados (batata cortada, tomate, queijo, cebola fatiada).
- `/kitculinaria prontos` : Adiciona os 9 produtos finais prontos (lanches, refrigerantes e água).
- `/kitculinaria props` : Adiciona as 7 estruturas móveis portáteis (churrasqueira, fritadeira, food cart, mesa, cadeiras, tenda, soda machine).
- `/kitculinaria [id] [categoria]` : Envia o kit para o jogador com o ID especificado (ex: `/kitculinaria 1 all` ou no console do servidor `kitculinaria 1 brutos`).

---

### Invocação Manual Individual (F8 / RCON):

### Insumos Brutos de Culinária:
```bash
giveitem 1 kitchen_knife 1
giveitem 1 raw_potato 15
giveitem 1 raw_tomato 15
giveitem 1 raw_cheese 15
giveitem 1 raw_onion 15
giveitem 1 raw_meat 15
giveitem 1 raw_sausage 15
giveitem 1 raw_fish 10
giveitem 1 cooking_oil 5
giveitem 1 empty_cup 15
giveitem 1 bread 15
giveitem 1 bacon 15
giveitem 1 lettuce 15
```

### Insumos Intermediários & Processados:
```bash
giveitem 1 raw_fries 15
giveitem 1 tomato 15
giveitem 1 cheese 15
giveitem 1 sliced_onion 15
```

### Produtos Prontos / Consumíveis Finais:
```bash
giveitem 1 burger_bacon 5
giveitem 1 hotdog 5
giveitem 1 fishburger 5
giveitem 1 frenchfries 5
giveitem 1 chicken_nuggets 5
giveitem 1 burger_softdrink 5
giveitem 1 juice_orange 5
giveitem 1 kurkakola 5
giveitem 1 water_bottle 5
```

### Estruturas Móveis (Props Colocáveis):
```bash
giveitem 1 granolla_grill 1
giveitem 1 granolla_fryer 1
giveitem 1 granolla_foodcart 1
giveitem 1 granolla_table 2
giveitem 1 granolla_chair 4
giveitem 1 granolla_gazebo 1
giveitem 1 granolla_soda_machine 1
```

---

## 3. ⌨️ Comandos de Teste & Atalhos F8

| Comando F8 / Chat | Módulo Testado | Descrição |
| :--- | :--- | :--- |
| `/kitculinaria [cat]` | Admin / Itens | Entrega kits culinários prontos (`brutos`, `processados`, `prontos`, `props`, `all`) |
| `/givekitchenkit` | Admin / Itens | Alias direto de `/kitculinaria` |
| `/testcut` | Módulo 5 | Abre a câmera da Tábua de Corte com Faca de Chef 3D |
| `/testfryer` | Módulo 6 | Abre a Fritadeira em 1ª pessoa com Cesto Móvel e Pá |
| `/testkitchen` | Módulo 7 | Abre a Chapa com Espátula Física controlada pelo Mouse |
| `/testassembly` | Módulo 8 | Abre a Mesa de Montagem de Hambúrguer em Camadas |
| `/testdrinks` | Módulo 9 | Abre a Máquina de Refrigerante & Sucos com Tampa SNAP |
| `/tablet_restaurante` | Módulo 2 | Abre o Tablet de Gestão Gastronômica (Lation Emerald UI) |
| `/fixkitchen` | Utilitário | Reset de emergência: destrava cursor do mouse e fecha qualquer NUI aberta |
| `/getcoords` | Módulo 1 | Copia `vector3` e `vector4` da posição exata para a Área de Transferência |
| `/spatulatune` | Módulo 1 | Ajusta em tempo real o ângulo, inclinação e profundidade da espátula 3D |

---

## 4. 🛠️ Módulo 1: Ferramentas Admin & Utilitários

### Teste 1.1: Captura de Coordenadas (`/getcoords`)
1. Posicione o ped onde deseja instalar uma nova bancada.
2. Digite `/getcoords` no F8.
3. **Validação:**
   - O console exibe `vector3(x, y, z)` e `vector4(x, y, z, h)`.
   - O valor é automaticamente copiado para a Área de Transferência (`Ctrl+V`).
   - Notificação verde de sucesso do `ox_lib:notify`.

### Teste 1.2: Sintonia Fina da Espátula 3D (`/spatulatune`)
1. Inicie a chapa com `/testkitchen`.
2. Abra o console F8 e teste valores de calibração ao vivo:
   ```bash
   spatulatune 5.0 0.0 0.22 0.03
   ```
3. **Validação:** A rotação (Pitch/Yaw), o comprimento do cabo e o offset Z da espátula mudam instantaneamente na tela sem reiniciar o script.

---

## 5. 📱 Módulo 2: Tablet de Gerenciamento & Cardápio

- **Comando:** `/tablet_restaurante`
- **Permissão Obrigatória:** Estar em serviço (`/onduty`) com `isboss = true` ou cargo $\ge 3$.

### Teste 2.1: Criação de Receita Customizada
1. Abra a aba **"Criar / Editar"**.
2. Preencha:
   - **Nome da Receita:** `Super Burger Duplo`
   - **Item de Resultado:** `burger_bacon`
   - **Estação:** `chapa`
   - **Ingredientes:** Adicione `raw_meat` (2x) e `cheese` (1x).
3. Clique em **"Salvar Receita"**.
4. **Validação:**
   - Notificação verde `Receita Super Burger Duplo adicionada ao cardápio!`.
   - Registro persistido na tabela `granolla_recipes` do MySQL.
   - Sincronização imediata para todos os funcionários online sem necessidade de restart.

### Teste 2.2: Bloqueio de Não-Gerentes (Anti-Exploit)
1. Altere seu cargo para novato: `setjob 1 hotdog 0`.
2. Tente salvar uma receita pelo evento de rede ou interface.
3. **Validação:** O servidor rejeita com notificação de erro `Permissão Negada: Apenas gerentes ou chefes podem alterar o cardápio.`

---

## 6. 🏗️ Módulo 3: Modo Construção & Props Móveis do Inventário

### Teste 3.1: Posicionamento no Mundo
1. No inventário `ox_inventory`, clique com o botão direito e use o item `granolla_grill`.
2. O modelo fantasma aparece na mira do jogador:
   - **[Scroll do Mouse]:** Gira o prop em 360°.
   - **[E]:** Fixa a churrasqueira no chão.
   - **[BACKSPACE]:** Cancela o posicionamento.
3. **Validação:**
   - 1x `granolla_grill` é consumido do inventário.
   - O objeto é registrado na tabela `granolla_props_saved` com as coordenadas exatas.
   - Um alvo do `ox_target` é criado automaticamente para utilizar a churrasqueira.

### Teste 3.2: Recolhimento de Props (Dono, Gerente e Admin)
1. Aproxime-se da churrasqueira posicionada e use a opção do `ox_target` **"Recolher"**.
2. **Validação:**
   - O objeto desaparece do mundo e o item `granolla_grill` retorna ao inventário.
   - Caso um funcionário tenha colocado o prop e desconectado, o gerente do restaurante (`isboss = true`) ou um administrador consegue recolhê-lo com sucesso, impedindo poluição do mapa.

---

## 7. 🍳 Módulo 4: Engine de Culinária em Tempo Real na Grelha

1. Vá até a chapa ou churrasqueira.
2. Selecione a opção **"Usar Chapa & Grelha"**.
3. **Ciclo de Cozimento em Tempo Real:**
   - **0s a 5s (Lado 1 - Cru):** A carne chia na grelha.
   - **5s (Virar):** O status muda para `needs_flip` ("VIRE A CARNE"). Pressione **[E]** para virar o alimento com a espátula.
   - **5s a 10s (Lado 2 - Cozinhando):** O outro lado grelha uniformemente.
   - **10s a 20s (No Ponto):** O anel indicador fica verde brilhante ("PRONTO"). Pressione **[E]** para recolher.
   - **> 20s (Queimou):** Se esquecida na chapa, a carne queima (`burnt`), solta fumaça escura e deve ser descartada.

---

## 8. 🔪 Módulo 5: Tábua de Corte com Faca de Chef 3D (`/testcut`)

- **Acesso:** Comando `/testcut` ou interagir com uma tábua de corte.
- **Insumos necessários:** `kitchen_knife` + `raw_potato`, `raw_tomato` ou `raw_cheese`.

### Passos de Teste:
1. Digite `/testcut`. A câmera desliza suavemente em ângulo diagonal sobre a tábua de madeira.
2. Selecione o insumo no menu flutuante (ex: *🥔 Batata Inteira*).
3. A faca de chef suspensa acompanha com alta fidelidade a mira do mouse sobre o ingrediente.
4. Pressione **[ESPAÇO]** ou **[CLIQUE LMB]**:
   - A lâmina desce golpeando a madeira com áudio realista de corte seco (`CHOP!`).
   - Uma fatia 3D independente se destaca do bloco e tomba na lateral da tábua.
   - A barra Lation Emerald avança: `1/4` ➔ `2/4` ➔ `3/4` ➔ `4/4`.
5. No 4º golpe: toca a sineta ("Ding!"), 1x `raw_potato` é consumido e 3x `raw_fries` são adicionados ao inventário através de validação server-side com token exclusivo.

---

## 9. 🍟 Módulo 6: Estação de Fritura com Cesto Móvel 3D (`/testfryer`)

- **Acesso:** Comando `/testfryer` ou interagir com a fritadeira industrial.
- **Insumos necessários:** `cooking_oil` (caso precise reabastecer) + `raw_fries`.

### Passos de Teste:
1. Digite `/testfryer`. A câmera fixa no nicho da fritadeira.
2. Com `raw_fries` no inventário, clique no cesto metálico suspenso:
   - As batatas cruas preenchem o fundo do cesto.
3. Clique novamente para **mergulhar o cesto no óleo**:
   - O cesto desce proceduralmente até o fundo da cuba quente.
   - Partículas volumétricas de vapor e borbulhas de gordura sobem.
   - O áudio contínuo de fritura borbulhante é ativado.
   - O temporizador NanoRing executa a contagem regressiva de 8 segundos.
4. Ao término do tempo:
   - O cesto sobe automaticamente e repousa escorrendo o excesso de óleo.
   - As batatas mudam para a tonalidade dourada e crocante.
5. Clique para recolher:
   - A pá metálica recolhe a porção com animação rápida e embala na caixinha oficial (`frenchfries`).

---

## 10. 🥩 Módulo 7: Chapa de Cozimento com Espátula no Mouse (`/testkitchen`)

- **Acesso:** Comando `/testkitchen` ou interagir com a chapa do restaurante.
- **Insumos necessários:** `raw_meat`, `raw_sausage` ou `raw_fish`.

### Passos de Teste:
1. Digite `/testkitchen`.
2. A espátula 3D fixa perfeitamente na ponta do cursor do mouse, sincronizada com plano 3D (Ray-Plane).
3. **Hover nos Potes:** Passe o mouse sobre o pote de carnes à esquerda e observe o anel tridimensional de destaque.
4. **Pegar Ingrediente:** Clique com o botão esquerdo para apanhar o bife cru.
5. **Soltar na Chapa:** Posicione sobre um slot livre delimitado na grelha e clique para soltar.
6. A carne entra imediatamente em processo de fritura com áudio imersivo, temporizador visual e possibilidade de virada com a espátula.

---

## 11. 🍔 Módulo 8: Mesa de Montagem em Camadas 3D (`/testassembly`)

- **Acesso:** Comando `/testassembly` ou bancada de montagem.
- **Insumos necessários:** `bread`, `cheese`, `bacon`, `lettuce`, `tomato`.

### Passos de Teste:
1. Digite `/testassembly`. O papel manteiga aberto repousa no centro da mesa.
2. Clique nos potes de ingredientes na bancada para adicionar as camadas:
   - Pão Inferior (`bread`) ➔ Carne Grelhada (`burger_bacon`) ➔ Queijo Cheddar (`cheese`) ➔ Alface (`lettuce`) ➔ Tomate (`tomato`) ➔ Bacon (`bacon`) ➔ Pão Superior (`bread`).
3. Cada camada empilha fisicamente com offset cumulativo $+Z$ sem atravessar as outras.
4. Ao colocar o pão superior, a opção **"📦 Embrulhar Hambúrguer"** é liberada no papel central.
5. Clique no papel:
   - O lanche é embrulhado, toca a sineta ("Ding!") e o item `burger_bacon` embalado é entregue com qualidade 100%.

---

## 12. 🥤 Módulo 9: Dispensador de Refrigerante & Sucos 3D (`/testdrinks`)

- **Acesso:** Comando `/testdrinks` ou máquina de refrigerante (`bs_juices_1`).
- **Insumos necessários:** `empty_cup`.

### Passos de Teste:
1. Digite `/testdrinks`. O copo descartável repousa sob a torneira da máquina.
2. Selecione o sabor desejado (Cola, Laranja, Limão ou Uva).
3. Mantenha pressionado **[ESPAÇO]** ou **[CLIQUE LMB]**:
   - O fluxo de líquido desce com som contínuo de refrigerante gasoso.
   - O nível interno sobe progressivamente de 0% a 100%.
4. Ao completar 100%:
   - Ocorre o estalo mecânico da tampa plástica e do canudo travando ("SNAP!").
   - O copo aberto se transforma no copo oficial com tampa e canudo (`prop_food_bs_juice01`).
   - A sineta toca e o refrigerante gelado (`burger_softdrink`) vai para o inventário.

---

## 13. 🍱 Módulo 10: Balcão de Atendimento (Bandejas & Caixa POS)

### Teste 10.1: Bandejas de Balcão (Trays)
1. Aproxime-se do balcão do Burger Shot (`coords: -1195.30, -892.35, 14.00`).
2. Mire na bandeja metálica (`prop_tray_01`) via `ox_target` ➔ **"🍱 Bandeja de Pedidos"**.
3. Uma stash pública de 25 kg do `ox_inventory` abre:
   - Deposite o Combo (Hambúrguer + Batata Frita + Refrigerante).
   - Qualquer cliente do outro lado do balcão pode abrir e retirar o pedido.

### Teste 10.2: Caixa Registradora (POS) & Repasse à Society
1. Mire na caixa registradora (`prop_till_01`) ➔ **"💵 Cobrar Cliente no Balcão"**.
2. O diálogo `ox_lib:inputDialog` abre com o ID do cliente mais próximo pré-selecionado.
3. Informe o valor (ex: `$250`) e a descrição (ex: `Combo Burger Shot + Fritas`).
4. O cliente recebe um diálogo modal na tela confirmando o pagamento (Dinheiro ou Banco).
5. Ao confirmar:
   - O valor é debitado do cliente.
   - O montante é creditado diretamente na conta da empresa no `Renewed-Banking`!

---

## 14. 🧍 Módulo 11: Atendimento a Clientes NPCs

1. Fique em serviço (`/onduty`).
2. A cada intervalo configurado, um pedestre NPC caminha até o balcão do restaurante e aguarda ser atendido.
3. Mire no NPC com o `ox_target` e selecione **"Entregar Pedido ao Cliente"**.
4. Uma barra de progresso de 3 segundos executa a entrega.
5. O NPC agradece, vai embora e você recebe entre **$80 e $150** em dinheiro com registro de faturamento.

---

## 15. 🛵 Módulo 12: Sistema de Entregas & Delivery GPS

1. Vá até o ponto de entrega do restaurante (`deliveryStartPoint`).
2. Selecione **"Pegar Mochila de Entrega"**.
3. O servidor abre uma sessão segura (`StartDelivery`) e marca a residência do cliente no GPS.
4. Pilote a moto até o local marcado:
   - A menos de 50 metros, o cliente surge esperando na porta da residência.
5. Aproxime-se e entregue o pacote com o `ox_target`.
6. O pagamento de **$150 a $300** é creditado e a sessão é encerrada com sucesso.

---

## 16. 🏬 Módulo 13: Validação Completa no MLO Burger Shot (`uniqx_burgershot`)

Para testar o fluxo gastronômico completo dentro do interior oficial do **Burger Shot (`uniqx_burgershot`)**:

1. **Teletransporte para o Burger Shot:**
   ```bash
   tp -1195.0 -895.0 14.0
   ```
2. **Estações Físicas Integradas:**
   - **Chapa Central (`-1195.56, -897.75, 13.46`):**
     - Mire na chapa metálica ➔ **"🥩 Usar Chapa & Grelha (3D)"**.
   - **Bateria de Fritadeiras (`-1196.94, -899.73, 13.67`):**
     - Mire nos nichos de fritura ➔ **"🍟 Fritadeira com Cesto (3D)"**.
   - **Bancadas de Montagem (`-1201.57, -895.43, 13.24`):**
     - Mire na bancada ➔ **"🍔 Montagem de Hambúrguer (3D)"**.
   - **Bancadas de Corte (`-1194.08, -900.56, 13.23`):**
     - Mire na bancada ➔ **"🔪 Tábua de Corte de Alimentos (3D)"**.
   - **Dispensador de Refrigerante (`-1199.50, -894.20, 13.80`):**
     - Mire na máquina de refrigerante ➔ **"🥤 Dispensador de Refrigerante & Sucos (3D)"**.
   - **Balcão de Atendimento & Caixa POS (`-1195.30, -892.35, 14.00`):**
     - Bandeja de pedidos (`prop_tray_01`) e Caixa Registradora (`prop_till_01`).

---

## 17. 🛡️ Módulo 14: Guia de Teste Anti-Exploit & Blindagem Server-Side

Todas as operações financeiras e de inventário contam com blindagem ativa no servidor:

### 17.1 Teste de Injeção de Dinheiro no Delivery
- **Cenário:** Um cheat tenta disparar `TriggerServerEvent('granolla_restaurants:server:DeliveryPayout')` sem iniciar a rota.
- **Resultado Esperado:** O servidor rejeita com aviso `Nenhuma rota de entrega ativa registrada.` e $0 é creditado.
- **Cenário:** O jogador inicia a rota e se teletransporta instantaneamente para o destino final em menos de 20 segundos.
- **Resultado Esperado:** O servidor detecta o tempo insuficiente ($\text{elapsed} < 20s$) e bloqueia o pagamento por `Entrega concluída rápido demais.`.

### 17.2 Teste de Injeção de Itens nos Minigames
- **Cenário:** O cliente tenta enviar `CompleteBurgerAssembly(token, 'weapon_pistol')` ou token forjado.
- **Resultado Esperado:** A whitelist `ValidBurgers` e a verificação do token de sessão bloqueiam o item arbitrário, garantindo integridade absoluta do inventário.

### 17.3 Teste de Cooldown em NPCs
- **Cenário:** O cliente spama o evento de venda de NPC em menos de 25 segundos.
- **Resultado Esperado:** O servidor impõe cooldown de 25s por jogador e rejeita transações repetitivas.

---

## 18. 📍 Módulo 15: Coordenadas & Teleportes Rápidos

Use o comando `tp x y z` no console F8 para se deslocar instantaneamente entre as cozinhas:

| Cozinha / Restaurante | Comando de Teleporte F8 | Tipo |
| :--- | :--- | :--- |
| **Burger Shot Principal (MLO Uniqx)** | `tp -1195.0 -895.0 14.0` | Interior MLO |
| **Drive-In La Puerta (MXC)** | `tp -305.69 -1469.27 29.94` | MLO / Estações |
| **Drive-In Paleto Bay (MXC)** | `tp 50.33 6507.79 30.68` | MLO / Estações |
| **Space Restaurant (MXC)** | `tp -912.14 -2511.62 13.95` | MLO / Estações |
| **Pizza This (K4MB1)** | `tp 798.50 -755.20 26.70` | MLO / Estações |
| **Horny's Burgers (Gabz / SM)** | `tp 1245.50 -360.20 69.00` | MLO / Estações |
| **UwU Cafe (SM / Gabz)** | `tp -580.50 -1070.20 22.30` | MLO / Estações |

---

## 19. 📊 Matriz de Verificação / Checklist de Homologação

| ID | Funcionalidade Testada | Comportamento Esperado | Status |
| :---: | :--- | :--- | :---: |
| **01** | Suporte a Props Nativos de MLOs (`addModel`) | Reconhece grelhas e bancadas do MLO sem props duplicados | `[ OK ]` |
| **02** | Abastecimento de Fritadeiras com Óleo (`cooking_oil`) | Consome o galão, ativa o nível de óleo e habilita fritura | `[ OK ]` |
| **03** | Cozimento em Tempo Real (Cru ➔ No Ponto ➔ Queimado) | Transições de estado automáticas gerenciadas pelo servidor | `[ OK ]` |
| **04** | Tábua de Corte com Faca de Chef 3D (`/testcut`) | Fatias 3D desacopladas, áudio de corte e token server-side | `[ OK ]` |
| **05** | Fritadeira com Cesto Móvel 3D (`/testfryer`) | Cesto afunda no óleo, borbulhas volumétricas e pá de batatas | `[ OK ]` |
| **06** | Chapa com Espátula Física no Mouse (`/testkitchen`) | Ray-Plane com alta fidelidade sem torção de IK do ped | `[ OK ]` |
| **07** | Mesa de Montagem em Camadas 3D (`/testassembly`) | Empilhamento procedimental $+Z$, camadas físicas e embrulho | `[ OK ]` |
| **08** | Máquina de Bebidas & Refrigerante 3D (`/testdrinks`) | Enchimento contínuo, som de gás e estalo da tampa ("SNAP!") | `[ OK ]` |
| **09** | Bandejas de Balcão Stash (`ox_inventory`) | Stash compartilhada de 25 kg para repasse direto de combos | `[ OK ]` |
| **10** | Caixa Registradora POS (`Renewed-Banking`) | Cobrança interativa com repasse direto à conta da sociedade | `[ OK ]` |
| **11** | Atendimento a Clientes NPCs no Balcão | Pedestres se aproximam, compram o pedido e pagam em dinheiro | `[ OK ]` |
| **12** | Sistema de Entregas & Delivery GPS | Rota com GPS, ped na porta e validação temporal $\ge 20s$ | `[ OK ]` |
| **13** | Modo Construção de Props (`ox_inventory`) | Posicionamento suave com scroll e gravação no banco MySQL | `[ OK ]` |
| **14** | Recolhimento de Props Abandonados | Autorizado para quem colocou, gerentes da empresa ou admins | `[ OK ]` |
| **15** | Consumíveis & Efeitos no `qbx_consumables` | Alimentos e bebidas saciam fome, sede e aliviam estresse | `[ OK ]` |
| **16** | Permissões de Gerência no Cardápio | Apenas cargos $\ge 3$ ou `isboss = true` alteram receitas | `[ OK ]` |
| **17** | Tokens de Sessão Anti-Replay | Proteção total contra injeção de itens em todos os minigames | `[ OK ]` |
| **18** | Prevenção de Injeção de Dinheiro | DeliveryPayout e NPCPayout blindados com rate-limit e sessão | `[ OK ]` |
| **19** | Sintaxe e Integridade Lua 5.4 | 100% dos 24 arquivos de código balanceados sem erros | `[ OK ]` |
| **20** | Design System Lation Emerald Edition | UI moderna (`#10b981`), fontes Inter e animações fluidas | `[ OK ]` |

---
*Granolla Restaurants — Documentação Oficial & Manual de Testes.*
