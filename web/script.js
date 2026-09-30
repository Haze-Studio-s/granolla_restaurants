// =====================================================
// GRANOLLA RESTAURANTS — Cozinha 3D Transparente Lation UI
// Suporte aos 4 Estados de Interação + Som de Chapa Chiando
// =====================================================

document.addEventListener('DOMContentLoaded', () => {
    let availableItems = [];
    let currentRecipes = [];
    let mouseX = 0, mouseY = 0;

    // Elementos da UI
    const cookingWorld = document.getElementById('cooking-world');
    const worldLabels  = document.getElementById('world-labels');
    const hoverCircle  = document.getElementById('hover-target-circle');
    const cursorTooltip= document.getElementById('cursor-tooltip');
    const tooltipIcon  = document.getElementById('tooltip-icon');
    const tooltipTitle = document.getElementById('tooltip-title');
    const tooltipAction= document.getElementById('tooltip-action');
    const hintText     = document.getElementById('cooking-hint-text');
    const appEl        = document.getElementById('app');

    // ── Sintetizador Físico de Som de Chapa Chiando (Web Audio API) ──
    let audioCtx = null;
    let sizzleSource = null;
    let sizzleGain = null;
    let isSizzling = false;

    function initAudioContext() {
        if (!audioCtx) {
            audioCtx = new (window.AudioContext || window.webkitAudioContext)();
        }
        if (audioCtx.state === 'suspended') {
            audioCtx.resume();
        }
    }

    function createSizzleNoise() {
        if (!audioCtx) return;
        const bufferSize = audioCtx.sampleRate * 2;
        const noiseBuffer = audioCtx.createBuffer(1, bufferSize, audioCtx.sampleRate);
        const output = noiseBuffer.getChannelData(0);
        let b0 = 0, b1 = 0, b2 = 0;
        for (let i = 0; i < bufferSize; i++) {
            const white = Math.random() * 2 - 1;
            b0 = 0.99886 * b0 + white * 0.0555179;
            b1 = 0.99332 * b1 + white * 0.0750759;
            b2 = 0.96900 * b2 + white * 0.1538520;
            output[i] = (b0 + b1 + b2) * 0.11;
        }

        sizzleSource = audioCtx.createBufferSource();
        sizzleSource.buffer = noiseBuffer;
        sizzleSource.loop = true;

        const filter = audioCtx.createBiquadFilter();
        filter.type = 'bandpass';
        filter.frequency.value = 1400;
        filter.Q.value = 1.2;

        sizzleGain = audioCtx.createGain();
        sizzleGain.gain.setValueAtTime(0.001, audioCtx.currentTime);

        sizzleSource.connect(filter);
        filter.connect(sizzleGain);
        sizzleGain.connect(audioCtx.destination);
        sizzleSource.start(0);
    }

    function setSizzleSound(active) {
        if (active && !isSizzling) {
            initAudioContext();
            if (!sizzleSource) createSizzleNoise();
            if (sizzleGain) {
                sizzleGain.gain.cancelScheduledValues(audioCtx.currentTime);
                sizzleGain.gain.linearRampToValueAtTime(0.18, audioCtx.currentTime + 0.6);
            }
            isSizzling = true;
        } else if (!active && isSizzling) {
            if (sizzleGain && audioCtx) {
                sizzleGain.gain.cancelScheduledValues(audioCtx.currentTime);
                sizzleGain.gain.linearRampToValueAtTime(0.0001, audioCtx.currentTime + 0.8);
            }
            isSizzling = false;
        }
    }

    // ── Mapa de Emojis de Alimentos ─────────────────────────────
    const EMOJIS = {
        raw_meat: '🥩', beef: '🥩', carne: '🥩', steak: '🥩', burger: '🍔',
        raw_sausage: '🌭', sausage: '🌭', hotdog: '🌭',
        raw_fish: '🐟', fish: '🐟', peixe: '🐟', chicken: '🍗', frango: '🍗',
        bacon: '🥓', egg: '🥚', ovo: '🥚', fries: '🍟', batata: '🥔',
        cheese: '🧀', queijo: '🧀', bread: '🍞', pao: '🍞', tomato: '🍅',
        lettuce: '🥬', alface: '🥬',
    };
    function getEmoji(key) {
        if (!key) return '🍳';
        const l = key.toLowerCase();
        for (const [k, v] of Object.entries(EMOJIS)) {
            if (l.includes(k)) return v;
        }
        return '🍳';
    }

    // Acompanha a posição do mouse em tempo real
    window.addEventListener('mousemove', (e) => {
        mouseX = e.clientX; mouseY = e.clientY;
        if (cursorTooltip && !cursorTooltip.classList.contains('hidden')) {
            cursorTooltip.style.left = mouseX + 'px';
            cursorTooltip.style.top  = mouseY + 'px';
        }
    });

    // ── Atualização dos 4 Estados de Interação do Cursor ─────────
    function updateWorldLabels(data) {
        if (!worldLabels) return;
        worldLabels.innerHTML = '';

        const labels = data.labels || [];
        const grabbed = data.grabbed;

        let activeHoverItem = null;
        let anyCookingOnGrill = false;

        labels.forEach(lbl => {
            if (lbl.type === 'ingredient') {
                const el = document.createElement('div');
                el.className = 'wl-ingredient' + (lbl.hovered ? ' hovered' : '');
                el.style.left = lbl.x + '%';
                el.style.top  = lbl.y + '%';
                el.innerHTML =
                    '<div class="wi-tag">' +
                        '<span class="wi-label">' + getEmoji(lbl.key) + ' ' + lbl.label + '</span>' +
                        '<span class="wi-count">x' + lbl.count + ' disponível</span>' +
                    '</div>';
                worldLabels.appendChild(el);

                if (lbl.hovered) {
                    activeHoverItem = {
                        type: 'ingredient',
                        title: lbl.label,
                        icon: getEmoji(lbl.key),
                        action: 'Clique para pegar',
                        x: lbl.x, y: lbl.y
                    };
                }

            } else if (lbl.type === 'slot') {
                const el = document.createElement('div');
                el.style.left = lbl.x + '%';
                el.style.top  = lbl.y + '%';

                if (lbl.isDropTarget) {
                    el.className = 'wl-slot drop-target';
                    el.innerHTML = '<span class="wl-slot-icon">➕</span><span>SOLTAR</span>';
                    activeHoverItem = {
                        type: 'drop_target',
                        title: (grabbed ? grabbed.label : 'Ingrediente'),
                        icon: '⬇️',
                        action: 'Soltar na chapa',
                        x: lbl.x, y: lbl.y
                    };
                } else if (lbl.occupied) {
                    el.className = 'wl-slot st-' + lbl.state;
                    if (lbl.state === 'raw' || lbl.state === 'side2') {
                        anyCookingOnGrill = true;
                        el.innerHTML = '<span class="wl-slot-icon">⏳</span><span>FRITANDO</span>';
                    } else if (lbl.state === 'needs_flip') {
                        el.innerHTML = '<span class="wl-slot-icon">🔄</span><span>VIRAR</span>';
                    } else if (lbl.state === 'cooked') {
                        el.innerHTML = '<span class="wl-slot-icon">✅</span><span>PRONTO</span>';
                    } else if (lbl.state === 'burnt') {
                        el.innerHTML = '<span class="wl-slot-icon">🔥</span><span>QUEIMADO</span>';
                    }

                    if (lbl.isInteractable) {
                        if (lbl.state === 'needs_flip') {
                            activeHoverItem = {
                                type: 'spatula_action',
                                title: 'Carne na Chapa',
                                icon: '🔄',
                                action: 'Clique para virar com a espátula',
                                x: lbl.x, y: lbl.y
                            };
                        } else if (lbl.state === 'cooked') {
                            activeHoverItem = {
                                type: 'spatula_action',
                                title: 'Carne Pronta!',
                                icon: '🍽️',
                                action: 'Clique para recolher com a espátula',
                                x: lbl.x, y: lbl.y
                            };
                        } else if (lbl.state === 'burnt') {
                            activeHoverItem = {
                                type: 'spatula_action',
                                title: 'Carne Queimada',
                                icon: '🗑️',
                                action: 'Clique para descartar com a espátula',
                                x: lbl.x, y: lbl.y
                            };
                        } else {
                            activeHoverItem = {
                                type: 'spatula_action',
                                title: 'Carne Fritando',
                                icon: '⏳',
                                action: 'Aguarde chiar e chegar no ponto',
                                x: lbl.x, y: lbl.y
                            };
                        }
                    }
                } else {
                    el.className = 'wl-slot';
                    el.style.opacity = '0';
                }

                worldLabels.appendChild(el);
            }
        });

        // Atualiza chiado sonoro da chapa
        setSizzleSound(anyCookingOnGrill);

        // ── GERENCIA OS 4 ESTADOS VISUAIS DO CURSOR ─────────────────
        if (grabbed && !activeHoverItem) {
            // Estado 2: Ingrediente segurado na mão
            cursorTooltip.classList.remove('hidden');
            tooltipIcon.textContent   = getEmoji(grabbed.key);
            tooltipTitle.textContent  = grabbed.label;
            tooltipAction.textContent = 'Arraste para a chapa';
            if (hoverCircle) hoverCircle.classList.add('hidden');
            if (hintText) hintText.textContent = 'Solte sobre um slot vazio da chapa';

        } else if (activeHoverItem) {
            // Estado 1 / 3 / 4: Hover ativo
            cursorTooltip.classList.remove('hidden');
            tooltipIcon.textContent   = activeHoverItem.icon;
            tooltipTitle.textContent  = activeHoverItem.title;
            tooltipAction.textContent = activeHoverItem.action;

            // Estado 1: Círculo branco ao redor do item
            if (hoverCircle) {
                hoverCircle.classList.remove('hidden');
                hoverCircle.style.left = activeHoverItem.x + '%';
                hoverCircle.style.top  = activeHoverItem.y + '%';
            }

            if (hintText) hintText.textContent = activeHoverItem.action;

        } else {
            // Repouso: espátula livre na mão
            cursorTooltip.classList.add('hidden');
            if (hoverCircle) hoverCircle.classList.add('hidden');
            if (hintText) hintText.textContent = 'Mova a espátula sobre a chapa para interagir';
        }
    }

    // ── Mensagens enviadas pelo Client Lua ───────────────────────
    window.addEventListener('message', (event) => {
        const d = event.data;
        if (!d || !d.action) return;

        if (d.action === 'openDrinksWorld') {
            if (drinksWorld) drinksWorld.classList.remove('hidden');
            document.body.style.cursor = 'none';
            updateDrinksWorld(d);

        } else if (d.action === 'closeDrinksWorld') {
            if (drinksWorld) drinksWorld.classList.add('hidden');
            document.body.style.cursor = '';

        } else if (d.action === 'UPDATE_DRINKS_PROGRESS') {
            updateDrinksWorld(d);

        } else if (d.action === 'PLAY_POUR_SOUND') {
            playPourSound(d.active);

        } else if (d.action === 'PLAY_SNAP_SOUND') {
            playSnapSound();

        } else if (d.action === 'openCuttingWorld') {
            if (cuttingWorld) cuttingWorld.classList.remove('hidden');
            document.body.style.cursor = 'none';
            updateCuttingWorld(d);

        } else if (d.action === 'closeCuttingWorld') {
            if (cuttingWorld) cuttingWorld.classList.add('hidden');
            document.body.style.cursor = '';

        } else if (d.action === 'UPDATE_CUTTING_PROGRESS') {
            updateCuttingWorld(d);

        } else if (d.action === 'PLAY_CHOP_SOUND') {
            playChopSound();

        } else if (d.action === 'PLAY_DING_SOUND') {
            playDingSound();

        } else if (d.action === 'openFryerWorld') {
            if (fryerWorld) fryerWorld.classList.remove('hidden');
            document.body.style.cursor = 'none';
            updateFryerStatus(d);

        } else if (d.action === 'closeFryerWorld') {
            if (fryerWorld) fryerWorld.classList.add('hidden');
            document.body.style.cursor = '';
            if (cursorTooltip) cursorTooltip.classList.add('hidden');
            setSizzleSound(false);

        } else if (d.action === 'UPDATE_FRYER_STATUS') {
            updateFryerStatus(d);

        } else if (d.action === 'UPDATE_FRYER_PROGRESS') {
            updateFryerProgress(d);

        } else if (d.action === 'UPDATE_FRYER_HOVER') {
            updateFryerHover(d);

        } else if (d.action === 'openAssemblyWorld') {
            if (assemblyWorld) assemblyWorld.classList.remove('hidden');
            document.body.style.cursor = 'none';

        } else if (d.action === 'closeAssemblyWorld') {
            if (assemblyWorld) assemblyWorld.classList.add('hidden');
            document.body.style.cursor = '';
            if (cursorTooltip) cursorTooltip.classList.add('hidden');
            if (hoverCircle) hoverCircle.classList.add('hidden');

        } else if (d.action === 'UPDATE_ASSEMBLY_HOVER') {
            updateAssemblyHover(d);

        } else if (d.action === 'UPDATE_ASSEMBLY_STACK') {
            updateAssemblyStack(d);

        } else if (d.action === 'openCookingWorld') {
            if (cookingWorld) {
                cookingWorld.classList.remove('hidden');
                cookingWorld.style.display = 'block';
            }
            document.body.style.cursor = 'none';

        } else if (d.action === 'closeCookingUI') {
            if (cookingWorld) {
                cookingWorld.classList.add('hidden');
                cookingWorld.style.display = 'none';
            }
            document.body.style.cursor = 'default';
            if (worldLabels) worldLabels.innerHTML = '';
            if (cursorTooltip) cursorTooltip.classList.add('hidden');
            if (hoverCircle) hoverCircle.classList.add('hidden');
            const rc = document.getElementById('cooking-rings-container');
            if (rc) rc.innerHTML = '';
            setSizzleSound(false);

        } else if (d.action === 'UPDATE_WORLD_LABELS') {
            updateWorldLabels(d);

        } else if (d.action === 'UPDATE_COOKING_RINGS') {
            const rc = document.getElementById('cooking-rings-container');
            if (!rc) return;
            const rings = d.rings || [];
            const activeIds = new Set();
            rings.forEach(ring => {
                activeIds.add(ring.id);
                let el = document.getElementById('ring-' + ring.id);
                if (!el) {
                    el = document.createElement('div');
                    el.id = 'ring-' + ring.id;
                    el.className = 'nano-cooking-ring';
                    el.innerHTML = '<div class="nano-ring-wrapper"><svg class="nano-ring-svg" viewBox="0 0 64 64"><circle class="nano-ring-bg" cx="32" cy="32" r="26"></circle><circle class="nano-ring-progress" cx="32" cy="32" r="26"></circle></svg><div class="nano-ring-content"><span class="nano-ring-time">0:00</span><span class="nano-ring-badge">GRILL</span></div></div>';
                    el.addEventListener('click', () => {
                        fetch('https://' + GetParentResourceName() + '/clickCookingRing', {
                            method: 'POST', headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({ slotKey: ring.id, status: ring.status })
                        }).catch(() => {});
                    });
                    rc.appendChild(el);
                }
                el.style.left = ring.x + '%'; el.style.top = ring.y + '%'; el.style.display = 'flex';
                const prog = el.querySelector('.nano-ring-progress');
                prog.style.strokeDashoffset = 163 - (163 * ring.progress / 100);
                if (ring.status === 'needs_flip' || ring.status === 'cooked') prog.style.stroke = '#10b981';
                else if (ring.status === 'burnt') prog.style.stroke = '#ef4444';
                else prog.style.stroke = '#f59e0b';
                el.querySelector('.nano-ring-time').innerText = ring.timeText;
                const badge = el.querySelector('.nano-ring-badge');
                badge.innerText = ring.label; badge.className = 'nano-ring-badge ' + ring.status;
            });
            Array.from(rc.children).forEach(ch => {
                if (!activeIds.has(ch.id.replace('ring-', ''))) ch.remove();
            });

        } else if (d.action === 'openTablet') {
            availableItems = d.ingredients || [];
            const resultItems = d.resultItems || [];
            let opt = '<option value="">Selecione...</option>';
            resultItems.forEach(i => { opt += '<option value="' + i.value + '">' + i.label + ' (' + i.value + ')</option>'; });
            document.getElementById('resultItem').innerHTML = opt;
            const myRecipes = d.myRecipes || [];
            currentRecipes = myRecipes;
            let html = '';
            if (!myRecipes.length) {
                html = '<p style="color:var(--content-muted);font-size:13px;padding:20px;text-align:center">Nenhuma receita encontrada.</p>';
            } else {
                myRecipes.forEach(r => {
                    html += '<div class="recipe-card"><div class="recipe-info"><h4>' + r.name + '</h4><p><strong>Item:</strong> ' + r.result + ' | <strong>Estação:</strong> ' + r.workstation + '</p></div><div class="recipe-actions"><button class="lation-btn ghost" onclick="editRecipe(\'' + r.id + '\')">Editar</button><button class="lation-btn danger" onclick="deleteRecipe(\'' + r.id + '\')">Excluir</button></div></div>';
                });
            }
            document.getElementById('recipes-container').innerHTML = html;
            if (appEl) appEl.classList.remove('hidden');

        } else if (d.action === 'copyToClipboard') {
            try {
                const el = document.createElement('textarea'); el.value = d.text; el.style.position = 'fixed'; el.style.opacity = '0';
                document.body.appendChild(el); el.focus(); el.select(); document.execCommand('copy'); document.body.removeChild(el);
            } catch(e) {}
        }
    });

    // ── Tablet do Gerente (Manutenção do CRUD) ───────────────────
    const tabCreate = document.getElementById('tab-create');
    const tabList   = document.getElementById('tab-list');
    const viewCreate= document.getElementById('view-create');
    const viewList  = document.getElementById('view-list');
    const recipeForm= document.getElementById('recipe-form');
    const ingredientsList = document.getElementById('ingredients-list');
    const addIngBtn = document.getElementById('add-ingredient-btn');

    if (tabCreate) tabCreate.addEventListener('click', () => {
        tabCreate.classList.add('active'); tabList.classList.remove('active');
        viewCreate.classList.remove('hidden'); viewList.classList.add('hidden');
        document.getElementById('editRecipeId').value = '';
        document.getElementById('create-title').innerText = 'Criar Nova Receita';
        recipeForm.reset(); ingredientsList.innerHTML = '';
    });
    if (tabList) tabList.addEventListener('click', () => {
        tabList.classList.add('active'); tabCreate.classList.remove('active');
        viewCreate.classList.add('hidden'); viewList.classList.remove('hidden');
    });

    const closeTablet = () => {
        if (appEl) appEl.classList.add('hidden');
        fetch('https://' + GetParentResourceName() + '/closeUI', { method: 'POST', body: JSON.stringify({}) }).catch(() => {});
    };
    const closeBtnEl = document.getElementById('close-btn');
    if (closeBtnEl) closeBtnEl.addEventListener('click', closeTablet);

    if (addIngBtn) addIngBtn.addEventListener('click', () => {
        const row = document.createElement('div'); row.className = 'ingredient-row';
        let o = '<option value="">Selecione...</option>';
        availableItems.forEach(i => { o += '<option value="' + i.value + '">' + i.label + ' (' + i.value + ')</option>'; });
        row.innerHTML = '<select class="ing-id" required>' + o + '</select><input type="number" class="ing-qtd" placeholder="Qtd" value="1" min="1" required><button type="button" class="remove-ing-btn">X</button>';
        ingredientsList.appendChild(row);
        row.querySelector('.remove-ing-btn').addEventListener('click', () => row.remove());
    });

    if (recipeForm) recipeForm.addEventListener('submit', (e) => {
        e.preventDefault();
        const recipeName = document.getElementById('recipeName').value;
        const resultItem = document.getElementById('resultItem').value;
        const workstation= document.getElementById('workstation').value;
        const isPublic   = document.getElementById('isPublic').checked;
        const ingredients= [];
        document.querySelectorAll('.ingredient-row').forEach(row => {
            const id = row.querySelector('.ing-id').value;
            const qty= parseInt(row.querySelector('.ing-qtd').value);
            if (id && qty > 0) ingredients.push({ item: id, amount: qty });
        });
        if (!ingredients.length) { alert('Adicione pelo menos 1 ingrediente!'); return; }
        const editId = document.getElementById('editRecipeId').value;
        const payload = { id: editId ? (isNaN(parseInt(editId)) ? editId : parseInt(editId)) : null, recipeName, resultItem, workstation, isPublic, ingredients };
        fetch('https://' + GetParentResourceName() + '/saveRecipe', { method: 'POST', body: JSON.stringify(payload) }).catch(() => {});
        recipeForm.reset(); ingredientsList.innerHTML = ''; closeTablet();
    });

    window.deleteRecipe = function(id) {
        if (confirm('Apagar esta receita?')) {
            fetch('https://' + GetParentResourceName() + '/deleteRecipe', { method: 'POST', body: JSON.stringify({ id }) }).catch(() => {});
            closeTablet();
        }
    };
    window.editRecipe = function(id) {
        const recipe = currentRecipes.find(r => String(r.id) === String(id));
        if (!recipe) return;
        if (String(id).includes('default_')) { alert('Não pode editar receita padrão.'); return; }
        document.getElementById('editRecipeId').value = recipe.id;
        document.getElementById('create-title').innerText = 'Editar Receita';
        document.getElementById('recipeName').value = recipe.name;
        document.getElementById('resultItem').value = recipe.result;
        document.getElementById('workstation').value = recipe.workstation;
        document.getElementById('isPublic').checked = recipe.is_public;
        ingredientsList.innerHTML = '';
        recipe.ingredients.forEach(ing => {
            const row = document.createElement('div'); row.className = 'ingredient-row';
            let o = '<option value="">Selecione...</option>';
            availableItems.forEach(i => { o += '<option value="' + i.value + '" ' + (i.value === ing.item ? 'selected' : '') + '>' + i.label + ' (' + i.value + ')</option>'; });
            row.innerHTML = '<select class="ing-id" required>' + o + '</select><input type="number" class="ing-qtd" value="' + ing.amount + '" min="1" required><button type="button" class="remove-ing-btn">X</button>';
            ingredientsList.appendChild(row);
            row.querySelector('.remove-ing-btn').addEventListener('click', () => row.remove());
        });
        if (tabCreate) tabCreate.click();
    };

    window.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            closeTablet();
            if (cookingWorld && (!cookingWorld.classList.contains('hidden') || cookingWorld.style.display !== 'none')) {
                fetch('https://' + GetParentResourceName() + '/closeCookingUI', { method: 'POST', body: JSON.stringify({}) }).catch(() => {});
            }
        }
        if (e.key === 'Backspace' && cookingWorld && (!cookingWorld.classList.contains('hidden') || cookingWorld.style.display !== 'none')) {
            fetch('https://' + GetParentResourceName() + '/closeCookingUI', { method: 'POST', body: JSON.stringify({}) }).catch(() => {});
        }
    });


    // ── BANCADA DE MONTAGEM FÍSICA 3D ──────────────────────────
    const assemblyWorld   = document.getElementById('assembly-world');
    const layersListEl    = document.getElementById('assembly-layers-list');
    const layersCountEl   = document.getElementById('assembly-count');
    const wrapBurgerBtn   = document.getElementById('wrap-burger-btn');

    if (wrapBurgerBtn) {
        wrapBurgerBtn.addEventListener('click', () => {
            fetch('https://' + GetParentResourceName() + '/wrapBurger', {
                method: 'POST', headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            }).catch(() => {});
        });
    }

    function updateAssemblyHover(data) {
        if (!cursorTooltip) return;
        if (data.hoveredKey && data.hoveredData) {
            cursorTooltip.classList.remove('hidden');
            tooltipIcon.textContent   = data.hoveredData.icon || '👉';
            tooltipTitle.textContent  = data.hoveredData.label || 'Ingrediente';
            tooltipAction.textContent = 'Clique para adicionar à pilha';
            if (hoverCircle) hoverCircle.classList.add('hidden');
        } else if (data.isHoverPaper) {
            cursorTooltip.classList.remove('hidden');
            if (data.isTopReady) {
                tooltipIcon.textContent   = '📦';
                tooltipTitle.textContent  = 'Hambúrguer Completo!';
                tooltipAction.textContent = 'Clique no papel para embrulhar';
            } else {
                tooltipIcon.textContent   = '🍞';
                tooltipTitle.textContent  = 'Papel Manteiga';
                tooltipAction.textContent = data.hasLayers ? 'Continue empilhando as camadas' : 'Coloque o pão base aqui';
            }
            if (hoverCircle) hoverCircle.classList.add('hidden');
        } else {
            cursorTooltip.classList.add('hidden');
        }
    }

    function updateAssemblyStack(data) {
        const layers = data.layers || [];
        if (layersCountEl) layersCountEl.textContent = layers.length + (layers.length === 1 ? ' camada' : ' camadas');
        if (!layersListEl) return;

        if (layers.length === 0) {
            layersListEl.innerHTML = '<div class="assembly-empty">Coloque o Pão Base no papel manteiga</div>';
            if (wrapBurgerBtn) wrapBurgerBtn.classList.add('hidden');
            return;
        }

        let html = '';
        layers.forEach(l => {
            html += '<div class="assembly-layer-item"><span class="al-icon">' + (l.icon || '🍔') + '</span><span class="al-name">' + l.label + '</span></div>';
        });
        layersListEl.innerHTML = html;

        if (wrapBurgerBtn) {
            if (data.isComplete) {
                wrapBurgerBtn.classList.remove('hidden');
            } else {
                wrapBurgerBtn.classList.add('hidden');
            }
        }
    }



    // ── ESTAÇÃO DE FRITURA FÍSICA 3D ───────────────────────────
    const fryerWorld        = document.getElementById('fryer-world');
    const fryerStateBadge   = document.getElementById('fryer-state-badge');
    const fryerRingBox      = document.getElementById('fryer-ring-box');
    const fryerProgressCirc = document.getElementById('fryer-progress-circle');
    const fryerTimeText     = document.getElementById('fryer-time-text');
    const fryerStatusTitle  = document.getElementById('fryer-status-title');
    const fryerStatusHint   = document.getElementById('fryer-status-hint');

    function updateFryerStatus(data) {
        if (fryerStateBadge) fryerStateBadge.textContent = data.state.toUpperCase();
        if (fryerStatusTitle) fryerStatusTitle.textContent = data.title || 'Fritadeira';
        if (fryerStatusHint) fryerStatusHint.textContent   = data.hint || '';

        if (data.state === 'frying') {
            if (fryerRingBox) fryerRingBox.classList.remove('hidden');
            setSizzleSound(true);
        } else {
            if (fryerRingBox) fryerRingBox.classList.add('hidden');
            setSizzleSound(false);
        }
    }

    function updateFryerProgress(data) {
        if (fryerProgressCirc) {
            const prog = data.progress || 0;
            fryerProgressCirc.style.strokeDashoffset = 163 - (163 * prog / 100);
        }
        if (fryerTimeText) {
            fryerTimeText.textContent = data.timeText || '0:00';
        }
    }

    function updateFryerHover(data) {
        if (!cursorTooltip) return;
        if (data.isHoverBasket) {
            cursorTooltip.classList.remove('hidden');
            if (data.fryerState === 'empty') {
                tooltipIcon.textContent   = '🥔';
                tooltipTitle.textContent  = 'Cesto de Fritura';
                tooltipAction.textContent = 'Clique para colocar batatas cruas';
            } else if (data.fryerState === 'loaded') {
                tooltipIcon.textContent   = '⬇️';
                tooltipTitle.textContent  = 'Cesto com Batatas';
                tooltipAction.textContent = 'Clique para mergulhar no óleo';
            } else if (data.fryerState === 'draining') {
                tooltipIcon.textContent   = '🍟';
                tooltipTitle.textContent  = 'Batatas Douradas';
                tooltipAction.textContent = 'Clique para recolher na caixinha';
            } else {
                tooltipIcon.textContent   = '⏳';
                tooltipTitle.textContent  = 'Fritando no Óleo';
                tooltipAction.textContent = 'Aguarde ficar dourada';
            }
        } else if (data.isHoverShovel && data.fryerState === 'draining') {
            cursorTooltip.classList.remove('hidden');
            tooltipIcon.textContent   = '🥄';
            tooltipTitle.textContent  = 'Pá de Batatas';
            tooltipAction.textContent = 'Clique para embalar na caixinha';
        } else {
            if (!assemblyWorld || assemblyWorld.classList.contains('hidden')) {
                cursorTooltip.classList.add('hidden');
            }
        }
    }

    // ── TÁBUA DE CORTE FÍSICA 3D ───────────────────────────────
    const cuttingWorld        = document.getElementById('cutting-world');
    const cuttingBadge        = document.getElementById('cutting-progress-badge');
    const cuttingProgressFill = document.getElementById('cutting-progress-fill');
    const cuttingTargetTitle  = document.getElementById('cutting-target-title');
    const cuttingTargetHint   = document.getElementById('cutting-target-hint');

    function updateCuttingWorld(data) {
        const cuts = data.cuts || 0;
        const total = data.totalCuts || 4;
        const pct = Math.min(100, Math.floor((cuts / total) * 100));

        if (cuttingBadge) cuttingBadge.textContent = cuts + ' / ' + total + ' fatias';
        if (cuttingProgressFill) cuttingProgressFill.style.width = pct + '%';
        if (cuttingTargetTitle) cuttingTargetTitle.textContent = data.title || 'Ingrediente';
        if (cuttingTargetHint) cuttingTargetHint.textContent = data.hint || 'Pressione [ESPAÇO] ou [CLIQUE] para descer a lâmina';
    }

    function playChopSound() {
        initAudioContext();
        if (!audioCtx) return;
        try {
            // Golpe seco da lâmina
            const osc = audioCtx.createOscillator();
            const gain = audioCtx.createGain();
            osc.type = 'triangle';
            osc.frequency.setValueAtTime(160, audioCtx.currentTime);
            osc.frequency.exponentialRampToValueAtTime(40, audioCtx.currentTime + 0.07);
            gain.gain.setValueAtTime(0.35, audioCtx.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.08);
            osc.connect(gain);
            gain.connect(audioCtx.destination);
            osc.start();
            osc.stop(audioCtx.currentTime + 0.09);

            // Impacto de choque mecânico na madeira da tábua
            const bufferSize = Math.floor(audioCtx.sampleRate * 0.06);
            const noiseBuffer = audioCtx.createBuffer(1, bufferSize, audioCtx.sampleRate);
            const output = noiseBuffer.getChannelData(0);
            for (let i = 0; i < bufferSize; i++) {
                output[i] = (Math.random() * 2 - 1) * Math.exp(-i / (audioCtx.sampleRate * 0.015));
            }
            const noise = audioCtx.createBufferSource();
            noise.buffer = noiseBuffer;
            const noiseFilter = audioCtx.createBiquadFilter();
            noiseFilter.type = 'lowpass';
            noiseFilter.frequency.value = 1600;
            const noiseGain = audioCtx.createGain();
            noiseGain.gain.setValueAtTime(0.45, audioCtx.currentTime);
            noiseGain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.06);
            noise.connect(noiseFilter);
            noiseFilter.connect(noiseGain);
            noiseGain.connect(audioCtx.destination);
            noise.start();
        } catch(e) {}
    }

    function playDingSound() {
        initAudioContext();
        if (!audioCtx) return;
        try {
            const osc = audioCtx.createOscillator();
            const gain = audioCtx.createGain();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(1760, audioCtx.currentTime); // Nota Lá (A6)
            osc.frequency.exponentialRampToValueAtTime(880, audioCtx.currentTime + 0.7);
            gain.gain.setValueAtTime(0.28, audioCtx.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.8);
            osc.connect(gain);
            gain.connect(audioCtx.destination);
            osc.start();
            osc.stop(audioCtx.currentTime + 0.8);
        } catch(e) {}
    }

    // ── MÁQUINA DE BEBIDAS & REFRIGERANTE 3D ───────────────────
    const drinksWorld        = document.getElementById('drinks-world');
    const drinksBadge        = document.getElementById('drinks-progress-badge');
    const drinksProgressFill = document.getElementById('drinks-progress-fill');
    const drinksTargetTitle  = document.getElementById('drinks-target-title');
    const drinksTargetHint   = document.getElementById('drinks-target-hint');
    let pourSource = null;
    let pourGain = null;
    let isPouring = false;

    function updateDrinksWorld(data) {
        const pct = Math.min(100, Math.max(0, data.progress || 0));
        if (drinksProgressFill) drinksProgressFill.style.width = pct + '%';
        if (drinksBadge) {
            if (pct >= 100) drinksBadge.textContent = 'Cheio (Pronto)';
            else if (pct > 0) drinksBadge.textContent = pct + '% Cheio';
            else drinksBadge.textContent = 'Vazio';
        }
        if (drinksTargetTitle) drinksTargetTitle.textContent = data.title || 'Refrigerante';
        if (drinksTargetHint) drinksTargetHint.textContent = data.hint || 'Segure [ESPAÇO] ou [CLIQUE] para acionar a torneira';
    }

    function playPourSound(active) {
        initAudioContext();
        if (!audioCtx) return;
        if (active && !isPouring) {
            isPouring = true;
            try {
                const bufferSize = audioCtx.sampleRate * 2;
                const noiseBuffer = audioCtx.createBuffer(1, bufferSize, audioCtx.sampleRate);
                const output = noiseBuffer.getChannelData(0);
                for (let i = 0; i < bufferSize; i++) {
                    output[i] = (Math.random() * 2 - 1) * 0.2;
                }
                pourSource = audioCtx.createBufferSource();
                pourSource.buffer = noiseBuffer;
                pourSource.loop = true;

                const filter = audioCtx.createBiquadFilter();
                filter.type = 'bandpass';
                filter.frequency.value = 1100;
                filter.Q.value = 2.0;

                pourGain = audioCtx.createGain();
                pourGain.gain.setValueAtTime(0.01, audioCtx.currentTime);
                pourGain.gain.linearRampToValueAtTime(0.22, audioCtx.currentTime + 0.2);

                pourSource.connect(filter);
                filter.connect(pourGain);
                pourGain.connect(audioCtx.destination);
                pourSource.start();
            } catch(e) {}
        } else if (!active && isPouring) {
            isPouring = false;
            if (pourGain && audioCtx) {
                pourGain.gain.cancelScheduledValues(audioCtx.currentTime);
                pourGain.gain.linearRampToValueAtTime(0.0001, audioCtx.currentTime + 0.25);
            }
        }
    }

    function playSnapSound() {
        initAudioContext();
        if (!audioCtx) return;
        try {
            const osc = audioCtx.createOscillator();
            const gain = audioCtx.createGain();
            osc.type = 'square';
            osc.frequency.setValueAtTime(800, audioCtx.currentTime);
            osc.frequency.exponentialRampToValueAtTime(120, audioCtx.currentTime + 0.05);
            gain.gain.setValueAtTime(0.3, audioCtx.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.05);
            osc.connect(gain);
            gain.connect(audioCtx.destination);
            osc.start();
            osc.stop(audioCtx.currentTime + 0.06);
        } catch(e) {}
    }

    // Seleção de Sabores
    document.querySelectorAll('.flavor-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.flavor-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            const flavor = btn.dataset.flavor;
            fetch('https://' + GetParentResourceName() + '/selectDrinkFlavor', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ flavor: flavor })
            }).catch(() => {});
        });
    });

});


