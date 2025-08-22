document.addEventListener('DOMContentLoaded', () => {
    // --- Get DOM Elements ---
    const homeScreen = document.getElementById('home-screen');
    const levelSelectScreen = document.getElementById('level-select-screen');
    const levelSelectWrapper = document.getElementById('level-select-wrapper');
    const gameScreen = document.getElementById('game-screen');
    const gameArea = document.getElementById('game-area');
    const bottlesContainer = document.getElementById('bottles-container');
    const animationLayer = document.getElementById('animation-layer');
    const currentLevelDisplay = document.getElementById('current-level-display');
    const winModal = document.getElementById('win-modal');
    const nextLevelButton = document.getElementById('next-level-btn');
    const homeButton = document.getElementById('home-btn');
    const startGameBtn = document.getElementById('start-game-btn');
    const levelsBtn = document.getElementById('levels-btn');
    const backBtn = document.getElementById('back-button');
    const gameBackBtn = document.getElementById('game-back-button');
    const levelsContainer = document.getElementById('levels-container');
    const homeCoins = document.getElementById('home-coins');
    const gameCoins = document.getElementById('game-coins');
    const settingsBtn = document.getElementById('settings-btn');
    const settingsModal = document.getElementById('settings-modal');
    const closeSettings = document.getElementById('close-settings');
    const musicToggle = document.getElementById('music-toggle');
    const soundToggle = document.getElementById('sound-toggle');
    const animationToggle = document.getElementById('animation-toggle');
    const autosaveToggle = document.getElementById('autosave-toggle');
    const hintsToggle = document.getElementById('hints-toggle');
    const resetProgressBtn = document.getElementById('reset-progress');
    const addBottleButton = document.getElementById('add-bottle-button');
    const addBottleCount = document.getElementById('add-bottle-count');
    const adModal = document.getElementById('ad-modal');
    const adTitle = document.getElementById('ad-title');
    const adProgress = document.getElementById('ad-progress');
    const adTimer = document.getElementById('ad-timer');
    const starDisplay = document.getElementById('star-display');
    const coinReward = document.getElementById('coin-reward');
    const completedLevelNum = document.getElementById('completed-level-num');
    const undoButton = document.getElementById('undo-button');
    const undoCount = document.getElementById('undo-count');
    const gameOverModal = document.getElementById('game-over-modal');
    const gameOverMessage = document.getElementById('game-over-message');
    const retryLevelBtn = document.getElementById('retry-level-btn');
    const gameOverHomeBtn = document.getElementById('game-over-home-btn');
    const toastNotification = document.getElementById('toast-notification');

    // New Feature Elements
    const shopBtn = document.getElementById('shop-btn');
    const shopModal = document.getElementById('shop-modal');
    const shopItemsContainer = document.getElementById('shop-items-container');

    // Pro Mode Elements
    const proModeBtn = document.getElementById('pro-mode-btn');
    const proModal = document.getElementById('pro-modal');
    const buyProBtn = document.getElementById('buy-pro-btn');

    // Ad Choice Modal Elements
    const adChoiceModal = document.getElementById('ad-choice-modal');
    const adChoiceWatchBtn = document.getElementById('ad-choice-watch-btn');
    const adChoiceSkipBtn = document.getElementById('ad-choice-skip-btn');
    const adTitleChoice = document.getElementById('ad-title-choice');
    const adDescChoice = document.getElementById('ad-desc-choice');

    // --- Game Constants & State ---
    let gameSettings = {
        musicEnabled: true,
        soundEnabled: true,
        animationsEnabled: true,
        vibrationEnabled: false,
        autoSave: true,
        hintsEnabled: true
    };
    
    let cameFromLevelSelect = false;
    let cachedGameState = null;
    let adCallback = null; // Callback to run after an ad
    let toastTimeout;
    
    const ambiance = {
        loop: null,
        synth: null,
        filter: null,
        reverb: null,
        delay: null,
        isPlaying: false,
        start() { /* Music removed */ },
        stop() { /* Music removed */ }
    };

    const sounds = {
        pickup: new Tone.Synth({ oscillator: { type: 'sine' }, envelope: { attack: 0.01, decay: 0.3, sustain: 0.05, release: 0.2 } }).toDestination(),
        addBlock: new Tone.MembraneSynth({ pitchDecay: 0.01, octaves: 10, oscillator: { type: 'sine' }, envelope: { attack: 0.001, decay: 0.1, sustain: 0.01, release: 0.1, attackCurve: 'exponential' } }).toDestination(),
        complete: new Tone.Synth({ oscillator: { type: 'triangle' }, envelope: { attack: 0.02, decay: 0.5, sustain: 0.2, release: 0.4 } }).toDestination(),
        win: new Tone.PolySynth(Tone.Synth, { oscillator: { type: "sine" }, envelope: { attack: 0.05, decay: 0.3, sustain: 0.2, release: 0.8 } }).toDestination(),
        click: new Tone.Synth({ oscillator: { type: 'sine' }, envelope: { attack: 0.001, decay: 0.15, sustain: 0, release: 0.1 } }).toDestination(),
        explode: new Tone.NoiseSynth({ noise: { type: 'pink' }, envelope: { attack: 0.01, decay: 0.3, sustain: 0, release: 0.2 } }).toDestination(),
        unlock: new Tone.MetalSynth({ frequency: 300, envelope: { attack: 0.001, decay: 0.2, release: 0.1 }, harmonicity: 3.1, modulationIndex: 22, resonance: 3000, octaves: 1.5 }).toDestination(),
        reward: new Tone.Synth({ oscillator: { type: 'triangle8' }, envelope: { attack: 0.01, decay: 0.4, sustain: 0.2, release: 0.4 } }).toDestination(),
        wheelTick: new Tone.Synth({ oscillator: { type: 'sine' }, envelope: { attack: 0.001, decay: 0.05, sustain: 0, release: 0.1 } }).toDestination(),
    };
    
    sounds.pickup.volume.value = -10;
    sounds.addBlock.volume.value = -8;
    sounds.complete.volume.value = -8;
    sounds.win.volume.value = -9;
    sounds.click.volume.value = -18;
    sounds.explode.volume.value = -8;
    sounds.unlock.volume.value = -12;
    sounds.reward.volume.value = -8;
    sounds.wheelTick.volume.value = -20;

    const BOTTLE_CAPACITY = 4;
    
    const COLOR_MAP = {
        '#e6194B': { s: '#b8143c' }, '#3cb44b': { s: '#30903c' }, '#ffe119': { s: '#ccb414' },
        '#4363d8': { s: '#364fa4' }, '#f58231': { s: '#c46827' }, '#911eb4': { s: '#741890' },
        '#42d4f4': { s: '#35abbd' }, '#f032e6': { s: '#c028b8' }, '#bfef45': { s: '#99bf37' },
        '#fabed4': { s: '#c898aa' }, '#469990': { s: '#387a73' }, '#dcbeff': { s: '#b098cc' },
        '#9A6324': { s: '#7b4f1d' }, '#fffac8': { s: '#ccc8a0' }, '#800000': { s: '#660000' },
        '#aaffc3': { s: '#88cc9c' }, '#808000': { s: '#666600' }, '#ffd8b1': { s: '#ccae8e' },
        '#000075': { s: '#00005d' }, '#a9a9a9': { s: '#878787' }, '#ffffff': { s: '#cccccc' },
        '#000000': { s: '#222222' }
    };
    const COLORS = Object.keys(COLOR_MAP);
    
    const LEVELS = Array.from({ length: 1000 }, (_, i) => {
        const levelNum = i + 1;
        
        let colors = 2 + Math.floor(i / 3);
        let bottles = colors + 2; // Always start with 2 empty bottles
        let isHidden = false;
        let hasStone = false;
        let hasChainLock = false;
        let hasBomb = false;

        if (levelNum > 0 && levelNum % 25 === 0) {
            colors += 2;
            bottles = colors + 2;
            const features = ['stone', 'bomb', 'hidden', 'chain'];
            const feature1 = features.splice(Math.floor(Math.random() * features.length), 1)[0];
            const feature2 = features.splice(Math.floor(Math.random() * features.length), 1)[0];
            if (feature1 === 'stone' || feature2 === 'stone') hasStone = true;
            if (feature1 === 'bomb' || feature2 === 'bomb') hasBomb = true;
            if (feature1 === 'hidden' || feature2 === 'hidden') isHidden = true;
            if (feature1 === 'chain' || feature2 === 'chain') hasChainLock = true;
        } else if (levelNum >= 4) {
            const featureCycleIndex = (levelNum - 4) % 4;
            switch(featureCycleIndex) {
                case 0: hasStone = true; break;
                case 1: hasBomb = true; break;
                case 2: isHidden = true; break;
                case 3: hasChainLock = true; break;
            }
        }
        
        colors = Math.min(colors, 19);
        return { bottles, colors, isHidden, hasStone, hasChainLock, hasBomb };
    });

    let state = {
        isPro: false,
        currentLevel: 0,
        bottles: [],
        selectedBottleIndex: null,
        isAnimating: false,
        highestLevelUnlocked: 1,
        coins: 0,
        bottleCharges: 0,
        moveHistory: [],
        completedLevels: [],
        levelStars: {},
        freeUndos: 3,
        undosUsedInLevel: 0,
        adBottlesUsedCount: 0,
        isHintMode: false,
        solutionSteps: [],
        currentHintStep: 0,
        optimalMoves: 0,
        nextBlockId: 0, 
        revealedBlockId: null,
        isBrickActive: false,
        brickedBottleIndex: null,
        brickKeyColor: null,
        revealingBricksInBottle: null,
        isChainLockActive: false, 
        chainLockedBottleIndex: null,
        chainLockKeyBottleIndex: null,
        chainLockKeyColor: null,
        isBombActive: false, 
        bombedBlocks: [], 
        lastLogin: null,
        winsForBonus: 0,
        purchasedDesigns: ['default'],
        selectedDesign: 'default',
    };

    const BOTTLE_DESIGNS = [
        { id: 'default', name: 'Classic', cost: 0 },
        { id: 'potion', name: 'Potion Flask', cost: 4000 },
        { id: 'crystal', name: 'Crystal Vial', cost: 4000 },
        { id: 'geo', name: 'Geo Flask', cost: 5000 },
        { id: 'biotank', name: 'Bio-Tank', cost: 5000 }
    ];

    function showToast(message) {
        clearTimeout(toastTimeout);
        toastNotification.textContent = message;
        toastNotification.classList.add('show');
        toastTimeout = setTimeout(() => {
            toastNotification.classList.remove('show');
        }, 3000);
    }

    function loadSettings() {
        const savedSettings = localStorage.getItem('gameSettings');
        if (savedSettings) gameSettings = { ...gameSettings, ...JSON.parse(savedSettings) };
        updateSettingsUI();
    }
    function saveSettings() {
        localStorage.setItem('gameSettings', JSON.stringify(gameSettings));
    }
    function updateSettingsUI() {
        musicToggle.classList.toggle('active', gameSettings.musicEnabled);
        soundToggle.classList.toggle('active', gameSettings.soundEnabled);
        animationToggle.classList.toggle('active', gameSettings.animationsEnabled);
        autosaveToggle.classList.toggle('active', gameSettings.autoSave);
        hintsToggle.classList.toggle('active', gameSettings.hintsEnabled);
    }

    function init() {
        loadSettings();
        loadProgress();
        showHomeScreen();
        
        document.body.addEventListener('click', async () => {
            if (Tone.context.state !== 'running') {
                await Tone.start();
            }
            ambiance.start(); 
        }, { once: true });

        const bonusCheck = () => {
            if (state.winsForBonus >= 4 && !state.isPro) {
                showAdChoiceModal(
                    "4 Wins Bonus!", 
                    "You won 4 new levels! Watch an ad to claim 3000 Coins.",
                    "Skip Bonus",
                    () => { // Watch Callback
                        animateCoinGain(3000);
                        showToast("You earned a 3000 coin bonus!");
                        state.winsForBonus = 0;
                        saveProgress();
                    },
                    () => { // Skip Callback
                        state.winsForBonus = 0;
                        saveProgress();
                        showToast("Bonus skipped.");
                    }
                );
            }
        };
        
        nextLevelButton.addEventListener('click', () => {
            playSound('click');
            hideWinModal();
            setupLevel(state.currentLevel + 1);
            setTimeout(bonusCheck, 500); // Delay check to allow modal to close
        });
        homeButton.addEventListener('click', () => { 
            playSound('click'); 
            hideWinModal(); 
            showHomeScreen(); 
            setTimeout(bonusCheck, 500); // Delay check to allow modal to close
        });
        startGameBtn.addEventListener('click', () => {
            playSound('click');
            cachedGameState = null;
            cameFromLevelSelect = false;
            const lastCompleted = state.completedLevels.length > 0 ? Math.max(...state.completedLevels) : 0;
            const startLevel = state.completedLevels.length > 0 ? lastCompleted : 0;
            setupLevel(startLevel);
        });
        levelsBtn.addEventListener('click', () => { playSound('click'); showLevelSelectScreen(); });
        backBtn.addEventListener('click', () => { playSound('click'); showHomeScreen(); });
        gameBackBtn.addEventListener('click', () => {
            playSound('click');
            cachedGameState = {
                currentLevel: state.currentLevel,
                bottles: JSON.parse(JSON.stringify(state.bottles)),
                moveHistory: [...state.moveHistory],
                freeUndos: state.freeUndos,
                undosUsedInLevel: state.undosUsedInLevel,
                adBottlesUsedCount: state.adBottlesUsedCount,
                isBrickActive: state.isBrickActive,
                brickedBottleIndex: state.brickedBottleIndex,
                brickKeyColor: state.brickKeyColor,
                isChainLockActive: state.isChainLockActive,
                chainLockedBottleIndex: state.chainLockedBottleIndex,
                chainLockKeyBottleIndex: state.chainLockKeyBottleIndex,
                chainLockKeyColor: state.chainLockKeyColor,
                isBombActive: state.isBombActive,
                bombedBlocks: JSON.parse(JSON.stringify(state.bombedBlocks)),
            };
            cameFromLevelSelect ? showLevelSelectScreen() : showHomeScreen();
        });
        
        addBottleButton.addEventListener('click', () => { 
            playSound('click');
            if (state.bottleCharges > 0) {
                state.bottleCharges--;
                addNewBottle();
                updateAddBottleButtonUI();
                saveProgress();
                showToast('Used 1 Extra Bottle Charge.');
                return;
            }
            if (state.adBottlesUsedCount < 2) {
                const callback = () => {
                    state.adBottlesUsedCount++;
                    addNewBottle();
                    updateAddBottleButtonUI();
                };
                if (!state.isPro) {
                    showAdModal('Get an Extra Bottle', callback);
                } else {
                    callback();
                }
            }
        });
        
        undoButton.addEventListener('click', handleUndoClick);
        
        settingsBtn.addEventListener('click', () => { playSound('click'); showSettings(); });
        shopBtn.addEventListener('click', () => { playSound('click'); openFeatureModal('shop-modal'); });
        closeSettings.addEventListener('click', () => { playSound('click'); hideSettings(); });
        settingsModal.addEventListener('click', (e) => { if (e.target === settingsModal) { playSound('click'); hideSettings(); } });
        
        musicToggle.addEventListener('click', () => { playSound('click'); gameSettings.musicEnabled = !gameSettings.musicEnabled; saveSettings(); updateSettingsUI(); if (gameSettings.musicEnabled) ambiance.start(); else ambiance.stop(); });
        soundToggle.addEventListener('click', () => { playSound('click'); gameSettings.soundEnabled = !gameSettings.soundEnabled; saveSettings(); updateSettingsUI(); });
        animationToggle.addEventListener('click', () => { playSound('click'); gameSettings.animationsEnabled = !gameSettings.animationsEnabled; saveSettings(); updateSettingsUI(); });
        autosaveToggle.addEventListener('click', () => { playSound('click'); gameSettings.autoSave = !gameSettings.autoSave; saveSettings(); updateSettingsUI(); });
        hintsToggle.addEventListener('click', () => { playSound('click'); gameSettings.hintsEnabled = !gameSettings.hintsEnabled; saveSettings(); updateSettingsUI(); });
        resetProgressBtn.addEventListener('click', () => {
            playSound('click');
            const userConfirmed = window.confirm("Are you sure you want to reset ALL your progress? This cannot be undone.");
            if (userConfirmed) {
                localStorage.removeItem('colorSortState_guest');
                window.location.reload();
            }
        });
        
        retryLevelBtn.addEventListener('click', () => {
            playSound('click');
            const retryAction = () => {
                hideGameOverModal();
                cachedGameState = null;
                setupLevel(state.currentLevel);
            };

            if (state.isPro) {
                retryAction();
            } else {
                showAdModal('Watch Ad to Retry', retryAction);
            }
        });
        gameOverHomeBtn.addEventListener('click', () => { playSound('click'); hideGameOverModal(); showHomeScreen(); });

        proModeBtn.addEventListener('click', () => { playSound('click'); openFeatureModal('pro-modal'); });

        buyProBtn.addEventListener('click', () => {
            playSound('reward');
            state.isPro = true;
            showToast("Congratulations! You are now a Pro user!");
            animateCoinGain(10000); // Bonus coins
            saveProgress();
            updateUIForPro();
            closeFeatureModal('pro-modal');
        });

        document.querySelectorAll('.close-feature-modal').forEach(btn => {
            btn.addEventListener('click', () => {
                playSound('click');
                closeFeatureModal(btn.dataset.modal);
            });
        });
        
        // Ad choice modal listeners
        adChoiceWatchBtn.addEventListener('click', () => {
            playSound('click');
            adChoiceModal.classList.add('hidden');
            showAdModal("Thanks for playing!", adCallback);
        });
        adChoiceSkipBtn.addEventListener('click', () => {
            playSound('click');
            adChoiceModal.classList.add('hidden');
            const skipCallback = adChoiceSkipBtn.onclick;
            if(typeof skipCallback === 'function') skipCallback();
        });

        // Shop listener (delegated)
        shopItemsContainer.addEventListener('click', (e) => {
            const button = e.target.closest('.shop-buy-btn');
            if (button && !button.disabled) {
                const item = button.dataset.item;
                const cost = parseInt(button.dataset.cost, 10);
                const type = button.dataset.type;

                if (type === 'powerup') {
                     if (state.coins >= cost) {
                         state.coins -= cost;
                         let purchaseMessage = '';
                         if (item === 'undos') {
                             state.freeUndos += 5;
                             purchaseMessage = 'Purchased +5 Undos!';
                         } else if (item === 'bottle') {
                             state.bottleCharges = (state.bottleCharges || 0) + 1;
                             purchaseMessage = 'Purchased +1 Extra Bottle Charge!';
                         }
                         playSound('reward');
                         updateCoinDisplay();
                         updateUndoButtonUI();
                         updateAddBottleButtonUI();
                         showToast(purchaseMessage);
                     } else {
                         showToast("Not enough coins!");
                     }
                } else if (type === 'design') {
                    const isPurchased = state.purchasedDesigns.includes(item);
                    if (!isPurchased) { // This is a "Buy" action
                        if (state.coins >= cost) {
                            state.coins -= cost;
                            state.purchasedDesigns.push(item);
                            state.selectedDesign = item;
                            playSound('reward');
                            showToast(`Purchased & selected ${button.dataset.name} design!`);
                        } else {
                            showToast("Not enough coins!");
                        }
                    } else { // This is a "Select" action
                        state.selectedDesign = item;
                        playSound('click');
                        showToast(`Selected ${button.dataset.name} design!`);
                    }
                } else if (type === 'no-ads') {
                    playSound('reward');
                    state.isPro = true;
                    showToast("Thank you for your purchase! Ads removed.");
                    updateUIForPro();
                    closeFeatureModal('shop-modal');
                }
                saveProgress();
                renderShopItems();
            }
        });
    }
    
    function showSettings() { settingsModal.classList.remove('hidden'); }
    function hideSettings() { settingsModal.classList.add('hidden'); }

    function showHomeScreen() {
        homeScreen.classList.remove('hidden');
        levelSelectScreen.classList.add('hidden');
        gameScreen.classList.add('hidden');
        updateCoinDisplay();
        updateDailyBonusButtonState();
    }

    function showLevelSelectScreen() {
        renderLevelSelect();
        homeScreen.classList.add('hidden');
        levelSelectScreen.classList.remove('hidden');
        gameScreen.classList.add('hidden');
        
        setTimeout(() => {
            const lastCompleted = state.completedLevels.length > 0 ? Math.max(0, ...state.completedLevels) : 0;
            const currentLevelNode = levelsContainer.querySelector(`[data-level="${lastCompleted + 1}"]`);
            if (currentLevelNode) {
                const container = levelSelectWrapper;
                const nodeTop = currentLevelNode.offsetTop;
                const containerHeight = container.clientHeight;
                const nodeHeight = currentLevelNode.offsetHeight;
                
                const scrollTop = nodeTop - (containerHeight / 2) + (nodeHeight / 2);
                container.scrollTop = Math.max(0, scrollTop);
            }
        }, 100);
    }
    
    function showGameScreen() {
        homeScreen.classList.add('hidden');
        levelSelectScreen.classList.add('hidden');
        gameScreen.classList.remove('hidden');
        updateCoinDisplay();
    }

    function setupLevel(levelIndex) {
        if (cachedGameState && cachedGameState.currentLevel === levelIndex) {
            showGameScreen();
            hideWinModal();
            hideGameOverModal();
            state = { ...state, ...cachedGameState };
            cachedGameState = null; 
            currentLevelDisplay.textContent = state.currentLevel + 1;
            render();
            updateUndoButtonUI();
            updateAddBottleButtonUI();
            return;
        }

        cachedGameState = null;
        showGameScreen();
        hideWinModal();
        hideGameOverModal();
        gameArea.classList.remove('exploded');
        state.currentLevel = levelIndex % LEVELS.length;
        const level = LEVELS[state.currentLevel];
        gameArea.style.paddingTop = level.bottles === 4 && ![0, 1, 2].includes(state.currentLevel) ? '0' : '7rem';
        const availableColors = COLORS.slice(0, Math.min(level.colors, COLORS.length));
        state = {
            ...state,
            selectedBottleIndex: null, isAnimating: false, moveHistory: [],
            adBottlesUsedCount: 0, undosUsedInLevel: 0,
            isHintMode: false, solutionSteps: [], currentHintStep: 0,
            nextBlockId: 0, revealedBlockId: null, isBrickActive: false,
            brickedBottleIndex: null, brickKeyColor: null, revealingBricksInBottle: null,
            isChainLockActive: false, chainLockedBottleIndex: null,
            chainLockKeyBottleIndex: null, chainLockKeyColor: null,
            isBombActive: false, bombedBlocks: [], 
        };
        if (!state.isPro) {
            state.freeUndos = 3;
        }
        currentLevelDisplay.textContent = state.currentLevel + 1;
        let allBlocks = [];
        for (const color of availableColors) {
            for (let i = 0; i < BOTTLE_CAPACITY; i++) {
                allBlocks.push({ color, id: state.nextBlockId++, isHidden: false, isBricked: false, isChained: false });
            }
        }
        let attempts = 0;
        do {
            allBlocks.sort(() => Math.random() - 0.5);
            state.bottles = Array.from({ length: level.bottles }, () => []);
            let blockIndex = 0;
            for (let i = 0; i < availableColors.length; i++) {
                for (let j = 0; j < BOTTLE_CAPACITY; j++) {
                    const block = allBlocks[blockIndex++];
                    block.isHidden = false; block.isBricked = false; block.isChained = false;
                    if (level.isHidden && j < 3) { block.isHidden = true; }
                    state.bottles[i].push(block);
                }
            }
            if (level.hasChainLock) setupChainLockFeature(availableColors);
            if (level.hasStone) setupBrickWallFeature(availableColors);
            if (level.hasBomb) setupBombFeature();
            attempts++;
        } while (isGameWon() && attempts < 50);
        
        // Solve for optimal moves
        const simplifiedInitialBottles = state.bottles.map(bottle => bottle.map(block => block.color));
        const solution = findSolution(simplifiedInitialBottles);
        state.optimalMoves = solution ? solution.length : (level.colors * 3); // Fallback heuristic

        render();
        updateUndoButtonUI();
        updateAddBottleButtonUI();
        if (state.currentLevel < 2) {
            state.isHintMode = true;
            solveAndStartHints();
        }
    }

    function setupChainLockFeature(availableColors) {
        let placementAttempts = 0;
        let success = false;
        while (!success && placementAttempts < 50) {
            placementAttempts++;
            const filledBottleIndices = state.bottles.map((b, i) => b.length > 0 ? i : -1).filter(i => i !== -1);
            if (filledBottleIndices.length < 2) break;
            const lockedIndex = filledBottleIndices[Math.floor(Math.random() * filledBottleIndices.length)];
            const lockedBottleColors = new Set(state.bottles[lockedIndex].map(b => b.color));
            const potentialKeyColors = availableColors.filter(c => !lockedBottleColors.has(c));
            if (potentialKeyColors.length === 0) continue;
            const keyColor = potentialKeyColors[Math.floor(Math.random() * potentialKeyColors.length)];
            const potentialKeyBottleIndices = filledBottleIndices.filter(idx => 
                idx !== lockedIndex && !state.bottles[idx].some(b => b.color === keyColor)
            );
            if (potentialKeyBottleIndices.length > 0) {
                const keyIndex = potentialKeyBottleIndices[Math.floor(Math.random() * potentialKeyBottleIndices.length)];
                state.isChainLockActive = true;
                state.chainLockedBottleIndex = lockedIndex;
                state.chainLockKeyColor = keyColor;
                state.chainLockKeyBottleIndex = keyIndex;
                state.bottles[lockedIndex].forEach(block => { block.isChained = true; });
                success = true;
            }
        }
        if (!success) state.isChainLockActive = false;
    }

    function setupBrickWallFeature(availableColors) {
        const potentialKeyColors = [...availableColors];
        let validPlacement = false;
        while(potentialKeyColors.length > 0 && !validPlacement) {
            const keyColorIndex = Math.floor(Math.random() * potentialKeyColors.length);
            state.brickKeyColor = potentialKeyColors[keyColorIndex];
            potentialKeyColors.splice(keyColorIndex, 1);
            const validBottleIndices = [];
            for(let i=0; i < state.bottles.length; i++) {
                 if (state.bottles[i].length > 0 && !state.bottles[i].some(b => b.color === state.brickKeyColor)) {
                     validBottleIndices.push(i);
                 }
            }
            if(validBottleIndices.length > 0) {
                state.brickedBottleIndex = validBottleIndices[Math.floor(Math.random() * validBottleIndices.length)];
                state.isBrickActive = true;
                state.bottles[state.brickedBottleIndex].forEach(block => { block.isBricked = true; });
                validPlacement = true;
            }
        }
        if(!validPlacement) state.isBrickActive = false;
    }

    function setupBombFeature() {
        const allBlocks = state.bottles.flat();
        if (allBlocks.length < 2) return;
        const initialMoves = 3 + Math.floor(state.currentLevel / 20);
        let attempts = 0;
        while (state.bombedBlocks.length < 2 && attempts < 50) {
            attempts++;
            const block1 = allBlocks[Math.floor(Math.random() * allBlocks.length)];
            const block2 = allBlocks[Math.floor(Math.random() * allBlocks.length)];
            if (block1.id !== block2.id && block1.color !== block2.color) {
                state.isBombActive = true;
                state.bombedBlocks = [
                    { id: block1.id, movesLeft: initialMoves },
                    { id: block2.id, movesLeft: initialMoves }
                ];
            }
        }
    }

    function loadProgress() {
        const savedState = localStorage.getItem('colorSortState_guest');
        if (savedState) {
            const loadedData = JSON.parse(savedState);
            // Ensure new state properties have default values if not in saved data
            state = { ...state, ...loadedData };
            if (!state.purchasedDesigns) state.purchasedDesigns = ['default'];
            if (!state.selectedDesign) state.selectedDesign = 'default';
        }
        
        updateCoinDisplay();
        updateUIForPro();
        updateDailyBonusButtonState();
    }

    function saveProgress() {
        if (gameSettings.autoSave) {
            localStorage.setItem('colorSortState_guest', JSON.stringify(state));
        }
    }

    function updateCoinDisplay() {
        homeCoins.textContent = state.coins;
        gameCoins.textContent = state.coins;
    }

    function updateUndoButtonUI() {
        if (state.isPro) {
            undoCount.innerHTML = `<i class="fas fa-infinity"></i>`;
            undoButton.disabled = state.moveHistory.length === 0;
        } else {
            undoCount.textContent = state.freeUndos > 0 ? state.freeUndos : 'Ad';
            undoButton.disabled = state.moveHistory.length === 0;
        }
    }

    function updateAddBottleButtonUI() {
        const charges = state.bottleCharges || 0;
        const adAvailable = 2 - state.adBottlesUsedCount;
        if (charges > 0) {
            addBottleCount.textContent = charges;
            addBottleButton.querySelector('.plus-sign').textContent = 'x1';
            addBottleButton.disabled = false;
        } else {
            addBottleCount.textContent = adAvailable;
            addBottleButton.querySelector('.plus-sign').style.fontSize = '0.8rem';
            addBottleButton.querySelector('.plus-sign').textContent = 'AD';
            addBottleButton.disabled = adAvailable <= 0;
        }
    }

    function vibrate(pattern) {
        if (gameSettings.vibrationEnabled && navigator.vibrate) navigator.vibrate(pattern);
    }

    function checkWinCondition() {
        if (isGameWon()) {
            cachedGameState = null;
            vibrate([100, 50, 100, 50, 200]);
            const levelNum = state.currentLevel + 1;
            const isFirstCompletion = !state.completedLevels.includes(levelNum);
            
            const moves = state.moveHistory.length;
            const optimal = state.optimalMoves;
            let starsEarned = 1;
            if (moves <= optimal + 1) {
                starsEarned = 3;
            } else if (moves <= optimal + 4) {
                starsEarned = 2;
            }

            state.levelStars[levelNum] = Math.max(state.levelStars[levelNum] || 0, starsEarned);
            
            let coinsAwarded;
            if (isFirstCompletion) {
                coinsAwarded = 500;
                state.completedLevels.push(levelNum);
                state.highestLevelUnlocked = Math.max(state.highestLevelUnlocked, levelNum + 1);
                state.winsForBonus++;
            } else {
                coinsAwarded = 25;
            }

            saveProgress(); 
            setTimeout(() => showWinModal(starsEarned, coinsAwarded, isFirstCompletion), 200);
        }
    }

    function showAdModal(title, callback) {
        adTitle.textContent = title;
        adCallback = callback;
        adModal.classList.remove('hidden');
        startAdTimer();
    }
    
    function startAdTimer() {
        let timeLeft = 5;
        adTimer.textContent = timeLeft;
        adProgress.style.width = '0%';
        const timer = setInterval(() => {
            timeLeft--;
            adTimer.textContent = timeLeft;
            adProgress.style.width = `${((5 - timeLeft) / 5) * 100}%`;
            if (timeLeft <= 0) {
                clearInterval(timer);
                adTimer.textContent = 'Complete!';
                setTimeout(() => {
                    hideAdModal();
                    if (adCallback) {
                        adCallback();
                        playSound('reward');
                    }
                }, 500);
            }
        }, 1000);
    }
    
    function hideAdModal() { 
        adModal.classList.add('hidden'); 
    }

    function showAdChoiceModal(title, desc, skipText, watchCallback, skipCallback) {
        adCallback = watchCallback;
        adTitleChoice.textContent = title;
        adDescChoice.textContent = desc;
        adChoiceSkipBtn.textContent = skipText;
        adChoiceSkipBtn.onclick = skipCallback;
        adChoiceModal.classList.remove('hidden');
    }
    
    function addNewBottle() {
        state.bottles.push([]);
        playSound('complete');
        vibrate(100);
        render();
    }

    function triggerLeafAnimation(bottleWrapper, color) {
        const rect = bottleWrapper.getBoundingClientRect();
        const gameAreaRect = gameArea.getBoundingClientRect();
        const startX = rect.left - gameAreaRect.left + (rect.width / 2);
        const startY = rect.top - gameAreaRect.top;
        const celebrationColors = ['#e6194B', '#3cb44b', '#ffe119', '#4363d8', '#f58231', '#911eb4', '#42d4f4'];
        for (let i = 0; i < 10; i++) {
            const leaf = document.createElement('div');
            leaf.className = 'leaf-particle';
            const randomColor = celebrationColors[Math.floor(Math.random() * celebrationColors.length)];
            leaf.style.setProperty('--leaf-color', randomColor);
            leaf.style.left = `${startX - 7.5}px`;
            leaf.style.top = `${startY}px`;
            const swayX = `${(Math.random() - 0.5) * 100}px`;
            const swayRot = `${(Math.random() - 0.5) * 360}deg`;
            const delay = Math.random() * 0.5;
            leaf.style.setProperty('--sway-x', swayX);
            leaf.style.setProperty('--sway-rot', swayRot);
            leaf.style.animationDelay = `${delay}s`;
            animationLayer.appendChild(leaf);
            leaf.addEventListener('animationend', () => leaf.remove());
        }
    }

    function render() {
        animationLayer.innerHTML = '';
        const currentBottleElements = Array.from(bottlesContainer.children);
        const stateBottleCount = state.bottles.length;
        while (currentBottleElements.length < stateBottleCount) {
            const newBottle = createBottleElement(currentBottleElements.length);
            bottlesContainer.appendChild(newBottle);
            currentBottleElements.push(newBottle);
        }
        while (currentBottleElements.length > stateBottleCount) {
            bottlesContainer.removeChild(currentBottleElements.pop());
        }
        state.bottles.forEach((bottleContent, index) => {
            const bottleWrapper = currentBottleElements[index];
            const bottleEl = bottleWrapper.querySelector('.bottle');
            bottleEl.className = 'bottle'; // Reset classes
            if (state.selectedDesign !== 'default') {
                bottleEl.classList.add(`bottle-design-${state.selectedDesign}`);
            }

            const bottleInner = bottleWrapper.querySelector('.bottle-inner');
            bottleWrapper.className = 'bottle-wrapper';
            bottleInner.innerHTML = '';
            const oldDynamicElements = bottleWrapper.querySelectorAll('.brick-wall-blocker, .lock-indicator, .chain-overlay');
            oldDynamicElements.forEach(el => el.remove());
            if (state.isBrickActive && index === state.brickedBottleIndex) {
                bottleWrapper.classList.add('bricked');
                bottleWrapper.prepend(createBrickBlockerElement());
            }
            if (state.isChainLockActive) {
                if (index === state.chainLockedBottleIndex) {
                    bottleWrapper.classList.add('chained');
                    bottleWrapper.prepend(createChainOverlayElement());
                }
                if (index === state.chainLockKeyBottleIndex) {
                    bottleWrapper.prepend(createLockIndicatorElement());
                }
            }
            bottleContent.forEach((block, blockIndex) => {
                const blockElement = createBlockElement(block, index);
                if (gameSettings.animationsEnabled) {
                    blockElement.style.transitionDelay = `${blockIndex * 0.05}s`;
                }
                bottleInner.appendChild(blockElement);
            });
            if (index === state.selectedBottleIndex && bottleInner.lastChild) {
                bottleInner.lastChild.style.visibility = 'hidden';
            }
        });
        if (state.selectedBottleIndex !== null) {
            const fromWrapper = bottlesContainer.children[state.selectedBottleIndex];
            const topBlock = state.bottles[state.selectedBottleIndex][state.bottles[state.selectedBottleIndex].length - 1];
            if (fromWrapper && topBlock) {
                const liftedBlock = createLiftedBlockElement(topBlock);
                const sampleBlock = fromWrapper.querySelector('.block');
                if (sampleBlock) {
                    const rect = sampleBlock.getBoundingClientRect();
                    liftedBlock.style.width = `${rect.width}px`;
                    liftedBlock.style.height = `${rect.height}px`;
                }
                const gameAreaRect = gameArea.getBoundingClientRect();
                const fromWrapperRect = fromWrapper.getBoundingClientRect();
                const liftedBlockWidth = parseFloat(liftedBlock.style.width) || 40;
                const startX = fromWrapperRect.left - gameAreaRect.left + (fromWrapper.offsetWidth - liftedBlockWidth) / 2;
                const startY = fromWrapperRect.top - gameAreaRect.top - liftedBlock.offsetHeight - 20;
                liftedBlock.style.left = `${startX}px`;
                liftedBlock.style.top = `${startY}px`;
                animationLayer.appendChild(liftedBlock);
            }
        }
    }
    
    function renderLevelSelect() {
        const container = levelsContainer;
        container.innerHTML = '';
        const renderLimit = Math.max(100, state.highestLevelUnlocked + 5);

        for(let index = 0; index < LEVELS.length; index++) {
            if (index >= renderLimit) break;

            const levelNum = index + 1;
            const node = document.createElement('div');
            node.className = 'level-node';
            node.dataset.level = levelNum;
            const isLocked = levelNum > state.highestLevelUnlocked; 
            const isCompleted = state.completedLevels.includes(levelNum);
            const stars = state.levelStars[levelNum] || 0;
            const lastCompleted = state.completedLevels.length > 0 ? Math.max(0, ...state.completedLevels) : 0;
            const isCurrent = levelNum === lastCompleted + 1;
            if (isLocked) {
                node.classList.add('locked');
                node.innerHTML = `<i class="fas fa-lock" style="font-size: 1.2rem;"></i>`;
            } else {
                node.classList.add('unlocked');
                node.textContent = levelNum;
                if (isCompleted && stars > 0) {
                    node.innerHTML += `<div class="star-container">${'⭐'.repeat(stars)}</div>`;
                }
                node.addEventListener('click', () => {
                    playSound('click');
                    cameFromLevelSelect = true;
                    setupLevel(index);
                });
            }
            if (isCurrent && !isLocked) {
                const avatar = document.createElement('div');
                avatar.id = 'player-avatar';
                avatar.innerHTML = `<div class="player-head"></div><div class="player-body"><div class="player-arm left"></div><div class="player-arm right"></div><div class="player-leg left"></div><div class="player-leg right"></div></div>`;
                node.style.position = 'relative';
                node.appendChild(avatar);
            }
            container.appendChild(node);
            if (index < LEVELS.length - 1) {
                const road = document.createElement('div');
                road.className = 'level-road';
                road.style.height = '4rem';
                road.style.top = '70px';
                node.appendChild(road);
            }
        }
        if (renderLimit < LEVELS.length) {
            const moreIndicator = document.createElement('div');
            moreIndicator.className = 'more-levels-indicator';
            moreIndicator.textContent = '...';
            container.lastChild.appendChild(moreIndicator);
        }
    }

    function createBottleElement(index) {
        const wrapper = document.createElement('div');
        wrapper.className = 'bottle-wrapper';
        wrapper.dataset.index = index;
        wrapper.addEventListener('click', () => handleBottleClick(index));
        wrapper.innerHTML = `<div class="bottle"><div class="bottle-inner"></div></div>`;
        return wrapper;
    }
    
    function createBlockElement(block, bottleIndex) {
        const el = document.createElement('div');
        el.className = 'block';
        if (block.isChained) el.classList.add('chained-block');
        if (block.isBricked) { el.classList.add('bricked-block'); return el; }
        if (bottleIndex === state.revealingBricksInBottle) el.classList.add('revealing');
        if (block.isHidden) {
            el.classList.add('hidden-block');
            el.textContent = '?';
        } else {
            const colorData = COLOR_MAP[block.color];
            el.style.backgroundColor = block.color;
            el.style.setProperty('--shadow-color', colorData.s);
        }
        if (state.isBombActive) {
            const bombedBlockData = state.bombedBlocks.find(b => b.id === block.id);
            if (bombedBlockData) {
                const bombOverlay = document.createElement('div');
                bombOverlay.className = 'bomb-overlay';
                bombOverlay.innerHTML = `<div class="bomb-icon">💣</div><div class="bomb-counter">${bombedBlockData.movesLeft}</div>`;
                el.appendChild(bombOverlay);
            }
        }
        if (block.id === state.revealedBlockId) el.classList.add('revealing');
        return el;
    }

    function createBrickBlockerElement() {
        const el = document.createElement('div');
        el.className = 'brick-wall-blocker';
        el.innerHTML = `<div class="brick-wall-cap"></div><div class="brick-key-color" style="background-color: ${state.brickKeyColor};"></div>`;
        return el;
    }

    function createChainOverlayElement() {
        const el = document.createElement('div');
        el.className = 'chain-overlay';
        el.innerHTML = `<div class="chain left"></div><div class="chain right"></div>`;
        return el;
    }

    function createLockIndicatorElement() {
        const el = document.createElement('div');
        el.className = 'lock-indicator';
        const keyBottle = document.createElement('div');
        keyBottle.className = 'key-bottle-preview';
        for (let i = 0; i < 4; i++) {
            const keyBlock = document.createElement('div');
            keyBlock.className = 'key-block-preview';
            keyBlock.style.backgroundColor = state.chainLockKeyColor;
            const shadowColor = COLOR_MAP[state.chainLockKeyColor]?.s || '#000';
            keyBlock.style.boxShadow = `inset 0 -2px 0 0 ${shadowColor}`;
            keyBottle.appendChild(keyBlock);
        }
        el.appendChild(keyBottle);
        return el;
    }

    function createLiftedBlockElement(block) {
        const el = document.createElement('div');
        el.className = 'lifted-block';
        const colorData = COLOR_MAP[block.color];
        el.style.backgroundColor = block.color;
        el.style.setProperty('--shadow-color', colorData.s);
        return el;
    }

    function handleBottleClick(tappedIndex) {
        if (state.isAnimating || (state.isBrickActive && tappedIndex === state.brickedBottleIndex) || (state.isChainLockActive && tappedIndex === state.chainLockedBottleIndex)) return;
        if (state.isHintMode) { handleHintedClick(tappedIndex); return; }
        if (state.selectedBottleIndex === null) {
            if (state.bottles[tappedIndex].length > 0 && !isBottleComplete(tappedIndex)) {
                playSound('pickup');
                vibrate(50);
                state.selectedBottleIndex = tappedIndex;
                render();
            }
        } else {
            const fromIndex = state.selectedBottleIndex;
            const fromBottle = state.bottles[fromIndex];
            const colorToMove = fromBottle[fromBottle.length - 1].color;
            let blocksToMoveCount = 0;
            for (let i = fromBottle.length - 1; i >= 0; i--) {
                if (fromBottle[i].color === colorToMove && !fromBottle[i].isChained) blocksToMoveCount++;
                else break;
            }
            const targetBottle = state.bottles[tappedIndex];
            const canReceive = targetBottle.length === 0 || targetBottle[targetBottle.length - 1].color === colorToMove;
            const spaceAvailable = BOTTLE_CAPACITY - targetBottle.length;
            const actualBlocksToMove = Math.min(blocksToMoveCount, spaceAvailable);
            if (tappedIndex !== fromIndex && canReceive && actualBlocksToMove > 0) {
                const topBlock = fromBottle[fromBottle.length - 1];
                state.moveHistory.push({ from: fromIndex, to: tappedIndex, count: actualBlocksToMove, movedBlockId: topBlock.id });
                updateUndoButtonUI();
                performPour(fromIndex, tappedIndex, actualBlocksToMove);
            } else {
                state.selectedBottleIndex = null;
                render();
            }
        }
    }
    
    function handleUndoClick() {
        if (state.isAnimating || state.moveHistory.length === 0) return;
        if (state.isPro || state.freeUndos > 0) {
            undoMove();
        } else {
            showAdModal('Watch Ad for +3 Undos', () => {
                state.freeUndos += 3;
                updateUndoButtonUI();
            });
        }
    }

    function undoMove() {
        if (!state.isPro) {
            state.freeUndos--;
        }
        state.undosUsedInLevel++;
        const lastMove = state.moveHistory.pop();
        const { from, to, count, movedBlockId } = lastMove;
        if (state.isBombActive) {
            const bombedBlock = state.bombedBlocks.find(b => b.id === movedBlockId);
            if (bombedBlock) bombedBlock.movesLeft++;
        }
        for (let i = 0; i < count; i++) {
            const block = state.bottles[to].pop();
            if (block) state.bottles[from].push(block);
        }
        playSound('pickup');
        vibrate(40);
        render();
        updateUndoButtonUI();
    }

    async function performPour(fromIndex, toIndex, blocksToMoveCount) {
        state.isAnimating = true;
        for (let i = 0; i < blocksToMoveCount; i++) {
            state.selectedBottleIndex = fromIndex;
            render(); 
            const fromWrapper = bottlesContainer.children[fromIndex];
            const toWrapper = bottlesContainer.children[toIndex];
            const liftedBlock = animationLayer.querySelector('.lifted-block');
            if (!liftedBlock || !fromWrapper || !toWrapper) {
                state.isAnimating = false; state.selectedBottleIndex = null; render(); return;
            }
            if (gameSettings.animationsEnabled) {
                const gameAreaRect = gameArea.getBoundingClientRect();
                const toWrapperRect = toWrapper.getBoundingClientRect();
                const blockWidth = liftedBlock.offsetWidth;
                const peakY = Math.min(fromWrapper.getBoundingClientRect().top, toWrapperRect.top) - gameAreaRect.top - blockWidth * 1.5;
                const targetX = toWrapperRect.left - gameAreaRect.left + (toWrapper.offsetWidth - blockWidth) / 2;
                liftedBlock.style.transition = 'top 0.1s cubic-bezier(0.25, 1, 0.5, 1), left 0.1s ease-in-out';
                liftedBlock.style.top = `${peakY}px`;
                liftedBlock.style.left = `${targetX}px`;
                await new Promise(res => setTimeout(res, 100));
                const finalBlockCount = state.bottles[toIndex].length + 1;
                const bottleInner = toWrapper.querySelector('.bottle-inner');
                const blockHeight = 36, blockMargin = 4, paddingOffset = 8;
                const targetY = toWrapperRect.top - gameAreaRect.top + bottleInner.offsetHeight - (finalBlockCount * (blockHeight + blockMargin)) + paddingOffset;
                liftedBlock.style.transition = 'top 0.15s cubic-bezier(0.5, 0, 0.75, 0)';
                liftedBlock.style.top = `${targetY}px`;
                await new Promise(res => setTimeout(res, 150));
            }
            const blockToMove = state.bottles[fromIndex].pop();
            if (state.isBombActive) {
                const bombedBlock = state.bombedBlocks.find(b => b.id === blockToMove.id);
                if (bombedBlock) bombedBlock.movesLeft--;
            }
            state.bottles[toIndex].push(blockToMove);
            playSound('addBlock');
            vibrate(30);
            const fromBottle = state.bottles[fromIndex];
            if (fromBottle.length > 0) {
                const newTopBlock = fromBottle[fromBottle.length - 1];
                if (newTopBlock.isHidden) {
                    newTopBlock.isHidden = false;
                    state.revealedBlockId = newTopBlock.id;
                }
            }
        }
        state.selectedBottleIndex = null;
        render();
        setTimeout(() => { state.revealedBlockId = null; }, 0);
        if (checkGameOverCondition()) return;
        checkBrickWallBreakCondition();
        checkChainLockBreakCondition();
        if (isBottleComplete(toIndex)) {
            if (!state.bottlesCollected) state.bottlesCollected = {};
            if (!state.bottlesCollected[state.currentLevel]) state.bottlesCollected[state.currentLevel] = new Set();
            const completedColor = state.bottles[toIndex][0].color;
            const wasNewCollection = !state.bottlesCollected[state.currentLevel].has(completedColor);
            state.bottlesCollected[state.currentLevel].add(completedColor);
            if (wasNewCollection) {
                vibrate(100);
                triggerLeafAnimation(bottlesContainer.children[toIndex], completedColor);
            }
        }
        state.isAnimating = false;
        if (state.isHintMode) {
            state.currentHintStep++;
            showNextHint();
        } else {
            checkWinCondition();
        }
    }

    function checkBrickWallBreakCondition() {
        if (!state.isBrickActive) return;
        for (let i = 0; i < state.bottles.length; i++) {
            const bottle = state.bottles[i];
            if (bottle.length === BOTTLE_CAPACITY && bottle[0].color === state.brickKeyColor && bottle.every(b => b.color === state.brickKeyColor)) {
                removeBrickWall();
                break;
            }
        }
    }

    function checkChainLockBreakCondition() {
        if (!state.isChainLockActive) return;
        const keyBottle = state.bottles[state.chainLockKeyBottleIndex];
        if (keyBottle.length === BOTTLE_CAPACITY && keyBottle.every(b => b.color === state.chainLockKeyColor)) {
            removeChainLock();
        }
    }

    function checkGameOverCondition() {
        if (state.isBombActive) {
            for (const bombedBlock of state.bombedBlocks) {
                if (bombedBlock.movesLeft <= 0) {
                    for (let i = 0; i < state.bottles.length; i++) {
                        if (state.bottles[i].some(b => b.id === bombedBlock.id)) {
                            triggerBombExplosion(i);
                            return true; 
                        }
                    }
                }
            }
        }
        if (state.isChainLockActive) {
            for (let i = 0; i < state.bottles.length; i++) {
                const bottle = state.bottles[i];
                if (bottle.length === BOTTLE_CAPACITY && bottle.every(b => !b.isHidden && !b.isBricked && !b.isChained)) {
                    const firstColor = bottle[0].color;
                    if (bottle.every(b => b.color === firstColor)) {
                        if (i === state.chainLockKeyBottleIndex && firstColor !== state.chainLockKeyColor) {
                            initiateGameOver(i, "You used the wrong color for the key bottle!");
                            return true; 
                        }
                        if (i !== state.chainLockKeyBottleIndex && firstColor === state.chainLockKeyColor) {
                            initiateGameOver(i, "You sorted the key color into the wrong bottle!");
                            return true; 
                        }
                    }
                }
            }
        }
        return false; 
    }

    function triggerBombExplosion(bottleIndex) {
        initiateGameOver(bottleIndex, "You ran out of moves for the bomb!");
    }

    function initiateGameOver(bottleIndex, message) {
        state.isAnimating = true;
        playSound('explode');
        vibrate([100, 50, 200]);

        const bottleWrapper = bottlesContainer.children[bottleIndex];
        if (bottleWrapper) {
            const bottleEl = bottleWrapper.querySelector('.bottle');
            bottleEl.classList.add('error');
        }

        if (message.includes("bomb")) {
             const rect = bottleWrapper.getBoundingClientRect();
             gameArea.style.setProperty('--explode-x', `${rect.left + rect.width / 2}px`);
             gameArea.style.setProperty('--explode-y', `${rect.top + rect.height / 2}px`);
             gameArea.classList.add('exploded');
        }

        setTimeout(() => {
            showGameOverModal(message);
        }, 1000);
    }

    function removeBrickWall() {
        playSound('explode');
        vibrate([50, 50, 50]);
        const bottleWrapper = bottlesContainer.children[state.brickedBottleIndex];
        const brickBlocker = bottleWrapper.querySelector('.brick-wall-blocker');
        if (brickBlocker) {
            brickBlocker.classList.add('exploding');
            brickBlocker.addEventListener('animationend', () => brickBlocker.remove());
        }
        state.isBrickActive = false;
        state.revealingBricksInBottle = state.brickedBottleIndex;
        state.bottles[state.brickedBottleIndex].forEach(block => { block.isBricked = false; });
        render();
        setTimeout(() => { state.revealingBricksInBottle = null; }, 600);
    }

    function removeChainLock() {
        playSound('unlock');
        vibrate([20, 80, 20]);
        const lockedWrapper = bottlesContainer.children[state.chainLockedBottleIndex];
        const keyWrapper = bottlesContainer.children[state.chainLockKeyBottleIndex];
        const chainOverlay = lockedWrapper.querySelector('.chain-overlay');
        if (chainOverlay) {
            chainOverlay.classList.add('unlocking');
            chainOverlay.addEventListener('transitionend', () => chainOverlay.remove());
        }
        const lockIndicator = keyWrapper.querySelector('.lock-indicator');
        if (lockIndicator) {
            lockIndicator.classList.add('unlocking');
            lockIndicator.addEventListener('transitionend', () => lockIndicator.remove());
        }
        state.isChainLockActive = false;
        state.bottles[state.chainLockedBottleIndex].forEach(block => { block.isChained = false; });
        setTimeout(() => render(), 100);
    }

    function isBottleComplete(index) {
        const bottle = state.bottles[index];
        if (bottle.length !== BOTTLE_CAPACITY) return false;
        const firstColor = bottle[0].color;
        return bottle.every(block => !block.isHidden && !block.isBricked && !block.isChained && block.color === firstColor);
    }

    function isGameWon() {
        if (state.isBrickActive || state.isChainLockActive) return false;
        return state.bottles.every((bottle, index) => bottle.length === 0 || isBottleComplete(index));
    }

    function showWinModal(stars = 3, coinsAwarded = 0, isFirstCompletion = false) {
        starDisplay.innerHTML = '';
        completedLevelNum.textContent = state.currentLevel + 1;
        for (let i = 0; i < stars; i++) {
            const starEl = document.createElement('span');
            starEl.textContent = '⭐';
            starEl.className = 'star-animated';
            const animDelay = i * 0.2;
            starEl.style.animationDelay = `${animDelay}s`;
            starEl.style.setProperty('--glint-delay', `${0.6 + i * 0.15}s`);
            starDisplay.appendChild(starEl);
        }
        playSound('win', Tone.now() + 0.1);

        if (coinsAwarded > 0) {
            coinReward.textContent = `🪙 +${coinsAwarded} Coins!`;
            coinReward.style.display = 'inline-block';
            setTimeout(() => animateCoinGain(coinsAwarded), 600);
        } else {
            coinReward.style.display = 'none';
        }
        winModal.classList.remove('hidden');
        winModal.classList.add('visible');
    }

    function hideWinModal() {
        winModal.classList.remove('visible');
        setTimeout(() => winModal.classList.add('hidden'), 300);
    }

    function showGameOverModal(message) {
        cachedGameState = null;
        state.isAnimating = true;
        gameOverMessage.textContent = message;
        updateGameOverUIForPro();
        gameOverModal.classList.remove('hidden');
        gameOverModal.classList.add('visible');
    }


    function hideGameOverModal() {
        gameOverModal.classList.remove('visible');
        setTimeout(() => gameOverModal.classList.add('hidden'), 300);
    }

    function animateCoinGain(amount) {
        if (amount <= 0) return;
        if (!gameSettings.animationsEnabled) {
            state.coins += amount;
            saveProgress();
            updateCoinDisplay();
            return;
        }
        const startRect = coinReward.getBoundingClientRect();
        const endRect = homeCoins.getBoundingClientRect();
        const startX = startRect.left + startRect.width / 2;
        const startY = startRect.top + startRect.height / 2;
        const endX = endRect.left + endRect.width / 2;
        const endY = endRect.top + endRect.height / 2;
        const particleCount = Math.min(amount / 60, 12);
        for (let i = 0; i < particleCount; i++) {
            const coinParticle = document.createElement('span');
            coinParticle.textContent = '🪙';
            coinParticle.style.cssText = `position:fixed; left:${startX}px; top:${startY}px; font-size:18px; z-index:999; pointer-events:none; transition: all ${0.4 + Math.random() * 0.3}s cubic-bezier(0.5, -0.5, 1, 1);`;
            document.body.appendChild(coinParticle);
            setTimeout(() => {
                coinParticle.style.transform = `translate(${endX - startX}px, ${endY - startY}px) scale(0.4)`;
                coinParticle.style.opacity = '0';
            }, 20 + i * 15);
            coinParticle.addEventListener('transitionend', () => coinParticle.remove());
        }
        const initialCoins = state.coins;
        const targetCoins = initialCoins + amount;
        const duration = 500;
        let startTime = null;
        function countUp(timestamp) {
            if (!startTime) startTime = timestamp;
            const progress = timestamp - startTime;
            const currentAmount = Math.min(initialCoins + Math.floor((progress / duration) * amount), targetCoins);
            state.coins = currentAmount;
            updateCoinDisplay();
            if (progress < duration) {
                requestAnimationFrame(countUp);
            } else {
                state.coins = targetCoins;
                updateCoinDisplay();
                saveProgress();
            }
        }
        requestAnimationFrame(countUp);
    }

    function playSound(sound, time = Tone.now()) {
        if (!gameSettings.soundEnabled || !sounds[sound]) return;
        if (Tone.context.state !== 'running') Tone.start().catch(console.error);
        try {
            if (sound === 'pickup') sounds.pickup.triggerAttackRelease('D5', '12n', time);
            else if (sound === 'addBlock') sounds.addBlock.triggerAttackRelease('C4', '8n', time);
            else if (sound === 'complete') sounds.complete.triggerAttackRelease('G5', '8n', time);
            else if (sound === 'click') sounds.click.triggerAttackRelease('C5', '16n', time);
            else if (sound === 'explode') sounds.explode.triggerAttackRelease("8n", time);
            else if (sound === 'unlock') sounds.unlock.triggerAttackRelease("8n", time);
            else if (sound === 'reward') sounds.reward.triggerAttackRelease('A5', '8n', time);
            else if (sound === 'wheelTick') sounds.wheelTick.triggerAttackRelease('G5', '32n', time);
            else if (sound === 'win') {
                const notes = ["C4", "E4", "G4", "C5"];
                notes.forEach((note, i) => sounds.win.triggerAttackRelease(note, "8n", time + i * 0.1));
            }
        } catch (e) { console.error("Sound error:", e); }
    }
    
    function solveAndStartHints() {
        const simplifiedBottles = state.bottles.map(bottle => bottle.map(block => block.color));
        const solution = findSolution(simplifiedBottles);
        if (solution) {
            state.solutionSteps = solution;
            state.currentHintStep = 0;
            showNextHint();
        } else {
            state.isHintMode = false;
        }
    }

    function showNextHint() {
        const oldPointer = document.getElementById('hint-pointer');
        if (oldPointer) oldPointer.remove();
        if (state.currentHintStep >= state.solutionSteps.length) {
            state.isHintMode = false;
            checkWinCondition();
            return;
        }
        const move = state.solutionSteps[state.currentHintStep];
        const pointer = document.createElement('div');
        pointer.id = 'hint-pointer';
        pointer.classList.add('bobbing-arrow');
        animationLayer.appendChild(pointer);
        movePointerToBottle(move.from);
    }

    function movePointerToBottle(bottleIndex) {
        const pointer = document.getElementById('hint-pointer');
        if (!pointer) return;
        const bottleWrapper = bottlesContainer.children[bottleIndex];
        if (!bottleWrapper) return;
        const rect = bottleWrapper.getBoundingClientRect();
        const gameAreaRect = gameArea.getBoundingClientRect();
        pointer.style.left = `${rect.left - gameAreaRect.left + (rect.width / 2) - 25}px`;
        pointer.style.top = `${rect.top - gameAreaRect.top - 60}px`;
    }
    
    function handleHintedClick(tappedIndex) {
        const move = state.solutionSteps[state.currentHintStep];
        if (!move) return;
        if (state.selectedBottleIndex === null) {
            if (tappedIndex === move.from) {
                playSound('pickup');
                state.selectedBottleIndex = tappedIndex;
                render();
                movePointerToBottle(move.to);
            }
        } else {
            if (tappedIndex === move.to) {
                const fromIndex = state.selectedBottleIndex;
                const fromBottle = state.bottles[fromIndex];
                const colorToMove = fromBottle[fromBottle.length - 1].color;
                let blocksToMoveCount = 0;
                for (let i = fromBottle.length - 1; i >= 0; i--) {
                    if (fromBottle[i].color === colorToMove) blocksToMoveCount++;
                    else break;
                }
                const targetBottle = state.bottles[tappedIndex];
                const spaceAvailable = BOTTLE_CAPACITY - targetBottle.length;
                const actualBlocksToMove = Math.min(blocksToMoveCount, spaceAvailable);
                performPour(fromIndex, tappedIndex, actualBlocksToMove);
            } else {
                state.selectedBottleIndex = null;
                render();
                movePointerToBottle(move.from);
            }
        }
    }
    
    function findSolution(initialBottles) {
        const queue = [{ bottles: initialBottles, path: [] }];
        const visited = new Set([JSON.stringify(initialBottles)]);
        let iterations = 0;
        const maxIterations = 20000; // Safety break for performance

        while (queue.length > 0) {
            iterations++;
            if (iterations > maxIterations) {
                console.warn("Solver timed out.");
                return null;
            }

            const { bottles, path } = queue.shift();
            const isWon = bottles.every(b => b.length === 0 || (b.length === BOTTLE_CAPACITY && new Set(b).size === 1));
            if (isWon) return path;
            for (let i = 0; i < bottles.length; i++) {
                for (let j = 0; j < bottles.length; j++) {
                    if (i === j) continue;
                    const fromBottle = bottles[i];
                    if (fromBottle.length === 0) continue;
                    const toBottle = bottles[j];
                    if (toBottle.length === BOTTLE_CAPACITY) continue;
                    const colorToMove = fromBottle[fromBottle.length - 1];
                    if (toBottle.length > 0 && toBottle[toBottle.length - 1] !== colorToMove) continue;
                    let blocksToMoveCount = 0;
                    for (let k = fromBottle.length - 1; k >= 0; k--) {
                        if (fromBottle[k] === colorToMove) blocksToMoveCount++;
                        else break;
                    }
                    const spaceAvailable = BOTTLE_CAPACITY - toBottle.length;
                    const actualBlocksToMove = Math.min(blocksToMoveCount, spaceAvailable);
                    if (actualBlocksToMove > 0) {
                        const newBottles = JSON.parse(JSON.stringify(bottles));
                        for (let k = 0; k < actualBlocksToMove; k++) newBottles[j].push(newBottles[i].pop());
                        const newStateKey = JSON.stringify(newBottles);
                        if (!visited.has(newStateKey)) {
                            visited.add(newStateKey);
                            queue.push({ bottles: newBottles, path: [...path, { from: i, to: j }] });
                        }
                    }
                }
            }
        }
        return null;
    }

    function isNewDay(lastLoginTimestamp) {
        if (!lastLoginTimestamp) return true;
        const now = new Date();
        const lastLogin = new Date(lastLoginTimestamp);
        now.setHours(0, 0, 0, 0);
        lastLogin.setHours(0, 0, 0, 0);
        return now > lastLogin;
    }

    function updateDailyBonusButtonState() {
        // This function is kept for potential re-integration of the daily bonus button
    }

    function openFeatureModal(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) {
            if (modalId === 'shop-modal') {
                renderShopItems();
            }
            modal.classList.remove('hidden');
        }
    }

    function closeFeatureModal(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) {
            modal.classList.add('hidden');
        }
    }

    function updateUIForPro() {
        if (state.isPro) {
            proModeBtn.innerHTML = `<i class="fas fa-check-circle mr-2"></i> Pro Activated`;
            proModeBtn.classList.add('pro-activated');
            proModeBtn.disabled = true;
        } else {
            proModeBtn.innerHTML = `<i class="fas fa-crown mr-2"></i>Get Pro`;
            proModeBtn.classList.remove('pro-activated');
            proModeBtn.disabled = false;
        }
        updateUndoButtonUI();
        updateGameOverUIForPro();
    }

    function updateGameOverUIForPro() {
        if (state.isPro) {
            retryLevelBtn.innerHTML = `Retry <i class="fas fa-redo"></i>`;
        } else {
            retryLevelBtn.innerHTML = `Retry (Ad) <i class="fas fa-redo"></i>`;
        }
    }

    function renderShopItems() {
        shopItemsContainer.innerHTML = '';
        
        // No Ads Item
        if (!state.isPro) {
            let noAdsHTML = `
                <div class="shop-item" style="background: linear-gradient(45deg, #facc15, #eab308);">
                    <div class="flex items-center gap-4">
                        <div class="shop-item-icon" style="color: #422006;">👑</div>
                        <div class="shop-item-details">
                            <div class="shop-item-title" style="color: #422006;">Remove Ads</div>
                            <div class="shop-item-desc" style="color: #654321;">Enjoy an ad-free experience!</div>
                        </div>
                    </div>
                    <button class="shop-buy-btn" data-type="no-ads" data-item="no_ads" style="background: #fff; color: #422006; border-bottom-color: #ca8a04;">
                        Buy for $7.99
                    </button>
                </div>
            `;
            shopItemsContainer.innerHTML += noAdsHTML;
        }

        // Power-ups
        let powerupsHTML = `<div class="shop-category-title">Power-ups</div>`;
        powerupsHTML += `
            <div class="shop-item">
                <div class="flex items-center gap-4">
                    <div class="shop-item-icon">⏪</div>
                    <div class="shop-item-details">
                        <div class="shop-item-title">5 Undos</div>
                        <div class="shop-item-desc">Get five extra chances to undo a move.</div>
                    </div>
                </div>
                <button class="shop-buy-btn" data-type="powerup" data-item="undos" data-cost="500">
                    <i class="fas fa-coins"></i> 500
                </button>
            </div>
            <div class="shop-item">
                 <div class="flex items-center gap-4">
                    <div class="shop-item-icon">🧪</div>
                    <div class="shop-item-details">
                        <div class="shop-item-title">1 Extra Bottle</div>
                        <div class="shop-item-desc">Get a permanent charge for an extra bottle.</div>
                    </div>
                </div>
                <button class="shop-buy-btn" data-type="powerup" data-item="bottle" data-cost="2000">
                    <i class="fas fa-coins"></i> 2000
                </button>
            </div>
        `;
        shopItemsContainer.innerHTML += powerupsHTML;

        // Designs
        let designsHTML = `<div class="shop-category-title">Bottle Designs</div>`;
        BOTTLE_DESIGNS.forEach(design => {
            const isPurchased = state.purchasedDesigns.includes(design.id);
            const isSelected = state.selectedDesign === design.id;
            let buttonHTML = '';
            if (isSelected) {
                buttonHTML = `<button class="shop-buy-btn" disabled>Selected</button>`;
            } else if (isPurchased) {
                buttonHTML = `<button class="shop-buy-btn select-btn" data-type="design" data-item="${design.id}" data-name="${design.name}">Select</button>`;
            } else {
                 buttonHTML = `<button class="shop-buy-btn" data-type="design" data-item="${design.id}" data-cost="${design.cost}" data-name="${design.name}"><i class="fas fa-coins"></i> ${design.cost}</button>`;
            }

            designsHTML += `
                <div class="shop-item">
                    <div class="flex items-center gap-4">
                        <div class="bottle-design-preview-container">
                            <div class="bottle bottle-design-${design.id}"></div>
                        </div>
                        <div class="shop-item-details">
                            <div class="shop-item-title">${design.name}</div>
                        </div>
                    </div>
                    ${buttonHTML}
                </div>
            `;
        });
        shopItemsContainer.innerHTML += designsHTML;
    }


    init();
});