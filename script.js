// This script tag contains the main game logic. It is intentionally kept separate
// from the Firebase module script to ensure proper execution order.
document.addEventListener('DOMContentLoaded', () => {
    // --- Get DOM Elements ---
    const loginScreen = document.getElementById('login-screen');
    const loadingText = document.getElementById('loading-text');
    const loginOptions = document.getElementById('login-options');
    const guestModeBtn = document.getElementById('guest-mode-btn');
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
    const doubleCoinsBtn = document.getElementById('double-coins-btn');
    const toastNotification = document.getElementById('toast-notification');
    const dailyBonusBtn = document.getElementById('daily-bonus-btn');

    // New Feature Elements
    const profileBtn = document.getElementById('profile-btn');
    const inviteBtn = document.getElementById('invite-btn');
    const withdrawBtn = document.getElementById('withdraw-btn');
    const profileModal = document.getElementById('profile-modal');
    const inviteModal = document.getElementById('invite-modal');
    const withdrawModal = document.getElementById('withdraw-modal');
    const copyCodeBtn = document.getElementById('copy-code-btn');
    const withdrawAmountInput = document.getElementById('withdraw-amount-input');
    const withdrawUsdValue = document.getElementById('withdraw-usd-value');
    const submitWithdrawBtn = document.getElementById('submit-withdraw-btn');
    const binanceIdInput = document.getElementById('binance-id-input');
    const shareInviteBtn = document.getElementById('share-invite-btn');
    const profileUserId = document.getElementById('profile-user-id');
    const confirmWithdrawBtn = document.getElementById('confirm-withdraw-btn');
    const withdrawalRequirements = document.getElementById('withdrawal-requirements');
    const reqDaysStatus = document.getElementById('req-days-status');
    const reqInvitesStatus = document.getElementById('req-invites-status');


    // Top Bar & Earner Notification Elements
    const homeUsd = document.getElementById('home-usd');
    const homePoints = document.getElementById('home-points');
    const earnerNotificationContent = document.getElementById('earner-notification-content');

    // Missions Elements
    const missionsBtn = document.getElementById('missions-btn');
    const missionsModal = document.getElementById('missions-modal');
    const missionTabs = document.querySelectorAll('.mission-tab');
    const dailyMissionsContainer = document.getElementById('daily-missions');
    const weeklyMissionsContainer = document.getElementById('weekly-missions');
    const missionTimer = document.getElementById('mission-timer');

    // Spin Wheel Elements
    const spinWheelBtn = document.getElementById('spin-wheel-btn');
    const spinWheelModal = document.getElementById('spin-wheel-modal');
    const wheel = document.getElementById('wheel');
    const spinBtn = document.getElementById('spin-btn');
    const spinTimer = document.getElementById('spin-timer');
    let spinCooldownInterval;

    // Pro Mode Elements
    const proModeBtn = document.getElementById('pro-mode-btn');
    const proModal = document.getElementById('pro-modal');
    const buyProBtn = document.getElementById('buy-pro-btn');

    // Ad Choice Modal Elements
    const adChoiceModal = document.getElementById('ad-choice-modal');
    const adChoiceWatchBtn = document.getElementById('ad-choice-watch-btn');
    const adChoiceSkipBtn = document.getElementById('ad-choice-skip-btn');

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
    let missionTimerInterval;
    let earnerNotificationInterval;

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
        userId: null,
        isPro: false,
        currentLevel: 0,
        bottles: [],
        selectedBottleIndex: null,
        isAnimating: false,
        highestLevelUnlocked: 1,
        coins: 0,
        moveHistory: [],
        completedLevels: [],
        levelStars: {},
        freeUndos: 3,
        undosUsedInLevel: 0,
        adBottlesUsedCount: 0,
        isHintMode: false,
        solutionSteps: [],
        currentHintStep: 0,
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
        gamesPlayedSinceAd: 0,
        dailyMissions: { date: null, missions: [] },
        weeklyMissions: { week: null, missions: [] },
        friendsInvited: 0,
        lastSpinTime: null,
        // NEW: Withdrawal state
        withdrawalRequest: null, // { amount: number, submittedAt: string }
        dailyMissionCompletionDates: [], // Array of 'YYYY-MM-DD' strings
        // Mission progress trackers
        missionStats: {
            daily: { play_3_games: 0, complete_1_level: 0, use_5_undos: 0, watch_2_ads: 0, complete_bomb_level: 0, earn_500_coins: 0, solve_level_no_undos: 0, invite_5_friends: 0 },
            weekly: { complete_25_levels: 0, earn_10000_coins: 0, complete_5_stone_levels: 0, complete_5_chain_levels: 0, reach_level_50: 0, invite_10_friends: 0, collect_100_stars: 0 }
        }
    };

    // Make state and key functions globally accessible for the Firebase module script
    window.gameState = state;
    window.loadGameProgress = loadProgress;
    window.updateUIForProStatus = updateUIForPro;
    window.updateDailyBonusButtonState = updateDailyBonusButtonState;
    window.startEarnerNotifications = startEarnerNotifications;
    window.updateNotificationDots = updateNotificationDots;


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

        document.body.addEventListener('click', async () => {
            if (Tone.context.state !== 'running') {
                await Tone.start();
            }
            ambiance.start();
        }, { once: true });

        nextLevelButton.addEventListener('click', () => {
            playSound('click');
            hideWinModal();
            state.gamesPlayedSinceAd++;
            // NEW: Ad logic change - show a forced ad with a coin reward
            if (state.gamesPlayedSinceAd >= 3 && !state.isPro) {
                state.gamesPlayedSinceAd = 0;
                saveProgress();
                showAdModal("Thanks for playing! Here's a bonus!", () => {
                    showToast("You earned 1000 bonus coins!");
                    animateCoinGain(1000);
                    setupLevel(state.currentLevel + 1);
                });
            } else {
                saveProgress();
                setupLevel(state.currentLevel + 1);
            }
        });
        homeButton.addEventListener('click', () => { playSound('click'); hideWinModal(); showHomeScreen(); });
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
            if (state.adBottlesUsedCount < 2) {
                const callback = () => {
                    state.adBottlesUsedCount++;
                    addNewBottle();
                    updateAddBottleButtonUI();
                    updateMissionProgress('watch_ad', 1);
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
        closeSettings.addEventListener('click', () => { playSound('click'); hideSettings(); });
        settingsModal.addEventListener('click', (e) => { if (e.target === settingsModal) { playSound('click'); hideSettings(); } });

        musicToggle.addEventListener('click', () => { playSound('click'); gameSettings.musicEnabled = !gameSettings.musicEnabled; saveSettings(); updateSettingsUI(); if (gameSettings.musicEnabled) ambiance.start(); else ambiance.stop(); });
        soundToggle.addEventListener('click', () => { playSound('click'); gameSettings.soundEnabled = !gameSettings.soundEnabled; saveSettings(); updateSettingsUI(); });
        animationToggle.addEventListener('click', () => { playSound('click'); gameSettings.animationsEnabled = !gameSettings.animationsEnabled; saveSettings(); updateSettingsUI(); });
        autosaveToggle.addEventListener('click', () => { playSound('click'); gameSettings.autoSave = !gameSettings.autoSave; saveSettings(); updateSettingsUI(); });
        hintsToggle.addEventListener('click', () => { playSound('click'); gameSettings.hintsEnabled = !gameSettings.hintsEnabled; saveSettings(); updateSettingsUI(); });
        resetProgressBtn.addEventListener('click', () => {
            playSound('click');
            // Custom modal for confirm would be better, but this is a quick fix.
            const userConfirmed = window.confirm("Are you sure you want to reset ALL your progress? This cannot be undone.");
            if (userConfirmed) {
                localStorage.removeItem(`colorSortState_${state.userId}`);
                window.location.reload();
            }
        });

        retryLevelBtn.addEventListener('click', () => { playSound('click'); hideGameOverModal(); cachedGameState = null; setupLevel(state.currentLevel); });
        gameOverHomeBtn.addEventListener('click', () => { playSound('click'); hideGameOverModal(); showHomeScreen(); });

        dailyBonusBtn.addEventListener('click', () => {
            playSound('click');
            if (isNewDay(state.lastLogin)) {
                const callback = () => {
                    const bonusCoins = 1000;
                    showToast(`You received ${bonusCoins} coins!`);
                    animateCoinGain(bonusCoins);
                    state.lastLogin = new Date().toISOString();
                    saveProgress();
                    updateDailyBonusButtonState();
                    updateMissionProgress('watch_ad', 1);
                    updateNotificationDots();
                };
                if (!state.isPro) {
                    showAdModal('Watch Ad for Daily Bonus!', callback);
                } else {
                    callback();
                }
            } else {
                showToast("Bonus already claimed today. Come back tomorrow!");
            }
        });

        profileBtn.addEventListener('click', () => { playSound('click'); openFeatureModal('profile-modal'); });
        inviteBtn.addEventListener('click', () => { playSound('click'); openFeatureModal('invite-modal'); });
        withdrawBtn.addEventListener('click', () => { playSound('click'); openFeatureModal('withdraw-modal'); });
        missionsBtn.addEventListener('click', () => { playSound('click'); openFeatureModal('missions-modal'); });
        spinWheelBtn.addEventListener('click', () => { playSound('click'); openSpinWheelModal(); });
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
        copyCodeBtn.addEventListener('click', () => {
            playSound('click');
            const code = document.getElementById('referral-code').textContent;
            const tempInput = document.createElement('textarea');
            document.body.appendChild(tempInput);
            tempInput.value = code;
            tempInput.select();
            document.execCommand('copy');
            document.body.removeChild(tempInput);
            showToast('Referral code copied!');
        });
        shareInviteBtn.addEventListener('click', handleShareInvite);
        withdrawAmountInput.addEventListener('input', updateWithdrawConversion);
        submitWithdrawBtn.addEventListener('click', handleSubmitWithdrawal);
        confirmWithdrawBtn.addEventListener('click', handleConfirmWithdrawal);
        spinBtn.addEventListener('click', handleSpinClick);

        missionTabs.forEach(tab => {
            tab.addEventListener('click', () => {
                const activeTab = tab.dataset.tab;
                missionTabs.forEach(t => t.classList.remove('active'));
                tab.classList.add('active');
                if (activeTab === 'daily') {
                    dailyMissionsContainer.classList.remove('hidden');
                    weeklyMissionsContainer.classList.add('hidden');
                    updateMissionTimer('daily');
                } else {
                    dailyMissionsContainer.classList.add('hidden');
                    weeklyMissionsContainer.classList.remove('hidden');
                    updateMissionTimer('weekly');
                }
            });
        });

        // Ad choice modal listeners (now only has one button visible)
        adChoiceWatchBtn.addEventListener('click', () => {
            playSound('click');
            adChoiceModal.classList.add('hidden');
            showAdModal("Thanks for playing!", adCallback);
        });

        // Mission claim listener (delegated)
        missionsModal.addEventListener('click', (e) => {
            if (e.target.matches('.mission-claim-btn')) {
                handleMissionClaim(e.target.dataset.missionId);
            }
        });

        createWheel();
    }

    function showSettings() { settingsModal.classList.remove('hidden'); }
    function hideSettings() { settingsModal.classList.add('hidden'); }

    function showHomeScreen() {
        homeScreen.classList.remove('hidden');
        levelSelectScreen.classList.add('hidden');
        gameScreen.classList.add('hidden');
        updateCoinDisplay();
        updateDailyBonusButtonState();
        startEarnerNotifications();
        updateNotificationDots();
    }

    function showLevelSelectScreen() {
        renderLevelSelect();
        homeScreen.classList.add('hidden');
        levelSelectScreen.classList.remove('hidden');
        gameScreen.classList.add('hidden');
        clearInterval(earnerNotificationInterval);

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
        clearInterval(earnerNotificationInterval);
    }

    function setupLevel(levelIndex) {
        updateMissionProgress('play_game', 1);

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
        if (!state.userId) return;
        const savedState = localStorage.getItem(`colorSortState_${state.userId}`);
        if (savedState) {
            const loadedData = JSON.parse(savedState);
            // Merge loaded data carefully to not overwrite functions or new state properties
            Object.keys(state).forEach(key => {
                if (loadedData.hasOwnProperty(key)) {
                    state[key] = loadedData[key];
                }
            });
        }
        // Ensure mission stats object exists
        if (!state.missionStats) {
            state.missionStats = { daily: {}, weekly: {} };
        }
        if (!state.missionStats.daily) state.missionStats.daily = {};
        if (!state.missionStats.weekly) state.missionStats.weekly = {};

        updateCoinDisplay();
        profileUserId.textContent = state.userId;
        document.getElementById('referral-code').textContent = state.userId.substring(0, 8).toUpperCase();
    }

    function saveProgress() {
        if (gameSettings.autoSave && state.userId) {
            localStorage.setItem(`colorSortState_${state.userId}`, JSON.stringify(state));
        }
    }

    function updateCoinDisplay() {
        const points = Math.floor(state.coins / 10000);
        const usd = (points / 1000).toFixed(2);
        homeCoins.textContent = state.coins;
        gameCoins.textContent = state.coins;
        homePoints.textContent = points;
        homeUsd.textContent = usd;
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
        const available = 2 - state.adBottlesUsedCount;
        addBottleCount.textContent = available;
        addBottleButton.disabled = available <= 0;
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
            const starsEarned = 3 - (state.undosUsedInLevel > 5 ? 1 : 0) - (state.undosUsedInLevel > 10 ? 1 : 0);
            state.levelStars[levelNum] = Math.max(state.levelStars[levelNum] || 0, starsEarned);

            let coinsAwarded;
            if (isFirstCompletion) {
                coinsAwarded = 500;
                state.completedLevels.push(levelNum);
                state.highestLevelUnlocked = Math.max(state.highestLevelUnlocked, levelNum + 1);
            } else {
                coinsAwarded = 25;
            }

            // Mission Progress Updates on Win
            updateMissionProgress('complete_level', 1);
            updateMissionProgress('earn_coins', coinsAwarded);
            if (state.undosUsedInLevel === 0) {
                updateMissionProgress('solve_level_no_undos', 1);
            }
            if (LEVELS[state.currentLevel].hasBomb) {
                updateMissionProgress('complete_bomb_level', 1);
            }
            if (LEVELS[state.currentLevel].hasStone) {
                updateMissionProgress('complete_stone_level', 1);
            }
            if (LEVELS[state.currentLevel].hasChainLock) {
                updateMissionProgress('complete_chain_level', 1);
            }
            updateMissionProgress('reach_level', state.highestLevelUnlocked);
            updateMissionProgress('collect_stars', starsEarned);

            saveProgress();
            setTimeout(() => showWinModal(starsEarned, coinsAwarded), 200);
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

    function showAdChoiceModal(callback) {
        adCallback = callback;
        // NEW: Hide the skip button as requested for simplicity.
        // If more complex ad logic is needed later, this can be changed.
        adChoiceSkipBtn.style.display = 'none';
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
        LEVELS.forEach((level, index) => {
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
            if (index < LEVELS.length - 1) {
                const road = document.createElement('div');
                road.className = 'level-road';
                road.style.height = '4rem';
                road.style.top = '70px';
                node.appendChild(road);
            }
        });
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
                updateMissionProgress('watch_ad', 1);
            });
        }
    }

    function undoMove() {
        if (!state.isPro) {
            state.freeUndos--;
        }
        state.undosUsedInLevel++;
        updateMissionProgress('use_undo', 1);
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
                            showGameOverModal("You used the wrong color for the key bottle!");
                            return true;
                        }
                        if (i !== state.chainLockKeyBottleIndex && firstColor === state.chainLockKeyColor) {
                            showGameOverModal("You sorted the key color into the wrong bottle!");
                            return true;
                        }
                    }
                }
            }
        }
        return false;
    }

    function triggerBombExplosion(bottleIndex) {
        state.isAnimating = true;
        playSound('explode');
        vibrate([100, 50, 200]);
        const bottleWrapper = bottlesContainer.children[bottleIndex];
        const rect = bottleWrapper.getBoundingClientRect();
        gameArea.style.setProperty('--explode-x', `${rect.left + rect.width / 2}px`);
        gameArea.style.setProperty('--explode-y', `${rect.top + rect.height / 2}px`);
        gameArea.classList.add('exploded');
        showGameOverModal("You ran out of moves for the bomb!");
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

    function showWinModal(stars = 3, coinsAwarded = 0) {
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
        doubleCoinsBtn.onclick = () => {
            playSound('click');
            const callback = () => {
                animateCoinGain(coinsAwarded);
                doubleCoinsBtn.style.display = 'none';
                updateMissionProgress('watch_ad', 1);
            };
            if (!state.isPro) {
                showAdModal('Watch Ad for 2x Coins', callback);
            } else {
                callback();
            }
        };
        doubleCoinsBtn.style.display = state.isPro ? 'none' : 'flex';
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
        const callback = () => {
            gameOverMessage.textContent = message;
            gameOverModal.classList.remove('hidden');
            gameOverModal.classList.add('visible');
            playSound('explode');
            vibrate([100, 50, 100]);
        };
        if (!state.isPro) {
            showAdModal("Game Over", callback);
        } else {
            callback();
        }
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
        while (queue.length > 0) {
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
        if (!isNewDay(state.lastLogin)) {
            dailyBonusBtn.disabled = true;
            dailyBonusBtn.textContent = "Claimed Today";
        } else {
            dailyBonusBtn.disabled = false;
            dailyBonusBtn.textContent = "Daily Bonus";
        }
    }

    function openFeatureModal(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) {
            if (modalId === 'profile-modal') {
                document.getElementById('profile-current-level').textContent = state.currentLevel + 1;
                document.getElementById('profile-highest-level').textContent = state.highestLevelUnlocked;
                document.getElementById('profile-total-coins').innerHTML = `🪙 ${state.coins}`;
                document.getElementById('profile-total-points').innerHTML = `💠 ${Math.floor(state.coins / 10000)}`;
                document.getElementById('profile-friends-invited').textContent = state.friendsInvited || 0;
            } else if (modalId === 'withdraw-modal') {
                const points = Math.floor(state.coins / 10000);
                document.getElementById('withdraw-points-balance').innerHTML = `💠 ${points}`;
                withdrawAmountInput.value = '';
                binanceIdInput.value = '';
                updateWithdrawConversion();
                updateWithdrawalUI(); // NEW: Update UI based on pending request
            } else if (modalId === 'missions-modal') {
                generateAndRenderMissions();
                updateMissionTimer('daily');
            }
            modal.classList.remove('hidden');
        }
    }

    function closeFeatureModal(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) {
            modal.classList.add('hidden');
        }
        if (modalId === 'missions-modal' || modalId === 'spin-wheel-modal') {
            clearInterval(missionTimerInterval);
            clearInterval(spinCooldownInterval);
        }
    }

    function updateWithdrawConversion() {
        const points = parseInt(withdrawAmountInput.value, 10) || 0;
        const usdValue = (points / 1000).toFixed(2);
        withdrawUsdValue.textContent = `$${usdValue}`;
    }

    // --- NEW/MODIFIED Withdrawal Logic ---

    function handleSubmitWithdrawal() {
        playSound('click');
        const pointsToWithdraw = parseInt(withdrawAmountInput.value, 10) || 0;
        const binanceId = binanceIdInput.value.trim();
        const availablePoints = Math.floor(state.coins / 10000);
        const MIN_WITHDRAWAL_POINTS = 10000;
        if (pointsToWithdraw < MIN_WITHDRAWAL_POINTS) {
            showToast(`Minimum withdrawal is ${MIN_WITHDRAWAL_POINTS} points ($10).`);
            return;
        }
        if (pointsToWithdraw <= 0) {
            showToast("Please enter a valid amount of points.");
            return;
        }
        if (pointsToWithdraw > availablePoints) {
            showToast("You don't have enough points to withdraw.");
            return;
        }
        if (binanceId === '') {
            showToast("Please enter your Binance ID.");
            return;
        }
        const coinsToDeduct = pointsToWithdraw * 10000;
        state.coins -= coinsToDeduct;
        state.withdrawalRequest = {
            amount: pointsToWithdraw,
            binanceId: binanceId,
            submittedAt: new Date().toISOString()
        };
        saveProgress();
        updateCoinDisplay();
        updateWithdrawalUI();
        showToast(`Withdrawal request for ${pointsToWithdraw} points submitted!`);
    }

    function handleConfirmWithdrawal() {
        playSound('reward');
        showToast(`Withdrawal of ${state.withdrawalRequest.amount} points confirmed! Processing now.`);
        // In a real app, this would send the request to a server.
        // Resetting state for the next withdrawal.
        state.withdrawalRequest = null;
        state.dailyMissionCompletionDates = [];
        state.friendsInvited = 0; // Resetting invite count per withdrawal
        saveProgress();
        updateWithdrawalUI();
    }

    function updateWithdrawalUI() {
        if (state.withdrawalRequest) {
            submitWithdrawBtn.classList.add('hidden');
            withdrawAmountInput.disabled = true;
            binanceIdInput.disabled = true;

            withdrawalRequirements.classList.remove('hidden');
            confirmWithdrawBtn.classList.remove('hidden');
            checkConfirmationConditions();
        } else {
            submitWithdrawBtn.classList.remove('hidden');
            withdrawAmountInput.disabled = false;
            binanceIdInput.disabled = false;

            withdrawalRequirements.classList.add('hidden');
            confirmWithdrawBtn.classList.add('hidden');
        }
    }

    function checkConfirmationConditions() {
        // Condition 1: 7 Friends Invited
        const invitesMet = (state.friendsInvited || 0) >= 7;
        reqInvitesStatus.textContent = `${state.friendsInvited || 0}/7 Friends`;
        reqInvitesStatus.className = `status ${invitesMet ? 'met' : 'not-met'}`;

        // Condition 2: 7 Consecutive Days of Missions
        let consecutiveDays = 0;
        if (state.dailyMissionCompletionDates && state.dailyMissionCompletionDates.length > 0) {
            const sortedDates = [...new Set(state.dailyMissionCompletionDates)].sort();
            let streak = 1;
            for (let i = sortedDates.length - 1; i > 0; i--) {
                const currentDay = new Date(sortedDates[i]);
                const prevDay = new Date(sortedDates[i-1]);
                const diff = (currentDay - prevDay) / (1000 * 60 * 60 * 24);
                if (diff === 1) {
                    streak++;
                } else {
                    break; // Streak broken
                }
            }
            consecutiveDays = streak;
        }
        const daysMet = consecutiveDays >= 7;
        reqDaysStatus.textContent = `${consecutiveDays}/7 Days`;
        reqDaysStatus.className = `status ${daysMet ? 'met' : 'not-met'}`;

        // Enable/Disable Confirm Button
        if (invitesMet && daysMet) {
            confirmWithdrawBtn.disabled = false;
        } else {
            confirmWithdrawBtn.disabled = true;
        }
    }

    function checkDailyMissionsCompletion() {
        const allDailyComplete = state.dailyMissions.missions.every(m => m.claimed);
        if (allDailyComplete) {
            const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
            if (!state.dailyMissionCompletionDates.includes(today)) {
                state.dailyMissionCompletionDates.push(today);
                showToast("Daily missions complete! Day streak +1");
                saveProgress();
            }
        }
    }

    function handleShareInvite() {
        playSound('click');
        // We increment the count here for simulation.
        // In a real app, this would be handled server-side when a new user signs up with the code.
        state.friendsInvited = (state.friendsInvited || 0) + 1;
        saveProgress();
        updateMissionProgress('invite_friend', 1);

        const referralCode = document.getElementById('referral-code').textContent;
        const inviteText = `Let's play Color Sort! It's a fun puzzle game. Use my referral code to get a bonus: ${referralCode}`;
        const tempInput = document.createElement('textarea');
        document.body.appendChild(tempInput);
        tempInput.value = inviteText;
        tempInput.select();
        document.execCommand('copy');
        document.body.removeChild(tempInput);
        showToast('Invite message copied! Friend count +1.');
    }

    function startEarnerNotifications() {
        clearInterval(earnerNotificationInterval);
        const topEarners = [
            { name: 'Cosmo', score: 'an iPhone 15 Pro' }, { name: 'Galaxy', score: '$100.00' },
            { name: 'Stardust', score: 215.50 }, { name: 'PlayerX', score: '5000 Points' },
            { name: 'Nebula', score: 198.20 }, { name: 'Astro', score: '$50.00' },
            { name: 'Quasar', score: 'a Samsung S24' }, { name: 'Pulsar', score: 175.10 },
            { name: 'Andromeda', score: '$100.00' }, { name: 'Supernova', score: '10000 Points' },
            { name: 'Orion', score: 152.30 }, { name: 'Comet', score: '$75.00' }
        ];
        let currentIndex = 0;

        function showNextEarner() {
            const earner = topEarners[currentIndex];
            earnerNotificationContent.classList.remove('visible');

            setTimeout(() => {
                let scoreText = typeof earner.score === 'number' ? `$${earner.score.toFixed(2)}` : earner.score;
                earnerNotificationContent.innerHTML = `🏆 <span class="earner-name">${earner.name}</span> just won ${scoreText}!`;
                earnerNotificationContent.classList.add('visible');
                currentIndex = (currentIndex + 1) % topEarners.length;
            }, 500);
        }

        showNextEarner();
        earnerNotificationInterval = setInterval(showNextEarner, 4000);
    }

    // --- Spin Wheel Logic ---
    const WHEEL_PRIZES = [
        { text: 'iPhone', icon: '📱', type: 'major' }, { text: 'Coin 500', icon: '🪙', type: 'coin', value: 500 },
        { text: 'Samsung', icon: '📱', type: 'major' }, { text: 'Coin 800', icon: '🪙', type: 'coin', value: 800 },
        { text: '$100', icon: '💵', type: 'major' }, { text: 'Coin 300', icon: '🪙', type: 'coin', value: 300 },
        { text: 'Try Again', icon: '😢', type: 'lose' }, { text: 'Coin 700', icon: '🪙', type: 'coin', value: 700 },
        { text: '1000 Pts', icon: '💠', type: 'major' }, { text: 'Coin 200', icon: '🪙', type: 'coin', value: 200 },
        { text: 'Coin 900', icon: '🪙', type: 'coin', value: 900 }, { text: 'Coin 400', icon: '🪙', type: 'coin', value: 400 },
        { text: 'Coin 600', icon: '🪙', type: 'coin', value: 600 }, { text: 'Try Again', icon: '😢', type: 'lose' }
    ];
    const SEGMENT_COLORS = ['#3498db', '#2ecc71', '#9b59b6', '#e67e22', '#e74c3c', '#1abc9c', '#f1c40f'];

    function createWheel() {
        wheel.innerHTML = '';
        const segmentAngle = 360 / WHEEL_PRIZES.length;
        WHEEL_PRIZES.forEach((prize, i) => {
            const segment = document.createElement('div');
            segment.className = 'wheel-segment';
            segment.style.transform = `rotate(${i * segmentAngle}deg)`;
            segment.style.backgroundColor = SEGMENT_COLORS[i % SEGMENT_COLORS.length];

            const content = document.createElement('div');
            content.className = 'segment-content';
            if (prize.type === 'major') {
                content.classList.add('major-prize');
            }
            content.innerHTML = `<span class="icon">${prize.icon}</span><span>${prize.text}</span>`;
            segment.appendChild(content);
            wheel.appendChild(segment);
        });
    }

    function openSpinWheelModal() {
        openFeatureModal('spin-wheel-modal');
        clearInterval(spinCooldownInterval);
        const lastSpin = state.lastSpinTime ? new Date(state.lastSpinTime).getTime() : 0;
        const now = new Date().getTime();
        const cooldown = 5 * 60 * 1000;
        const timeSinceSpin = now - lastSpin;

        if (timeSinceSpin < cooldown && !state.isPro) {
            spinBtn.disabled = true;
            spinTimer.classList.remove('hidden');
            let remaining = cooldown - timeSinceSpin;
            const updateTimer = () => {
                remaining -= 1000;
                if (remaining <= 0) {
                    clearInterval(spinCooldownInterval);
                    spinTimer.classList.add('hidden');
                    spinBtn.disabled = false;
                    spinBtn.innerHTML = `<i class="fas fa-video mr-2"></i> Watch Ad to Spin`;
                    updateNotificationDots();
                } else {
                    const minutes = Math.floor(remaining / 60000);
                    const seconds = Math.floor((remaining % 60000) / 1000);
                    spinBtn.innerHTML = `Spin available in:`;
                    spinTimer.textContent = `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
                }
            };
            updateTimer();
            spinCooldownInterval = setInterval(updateTimer, 1000);
        } else {
            spinBtn.disabled = false;
            spinTimer.classList.add('hidden');
            spinBtn.innerHTML = state.isPro ? `<i class="fas fa-sync-alt mr-2"></i> Spin for Free` : `<i class="fas fa-video mr-2"></i> Watch Ad to Spin`;
        }
    }

    function handleSpinClick() {
        playSound('click');
        const callback = () => {
            spinTheWheel();
            updateMissionProgress('watch_ad', 1);
        };
        if (!state.isPro) {
            showAdModal("Watch Ad for a Spin", callback);
        } else {
            callback();
        }
    }

    function spinTheWheel() {
        spinBtn.disabled = true;
        spinBtn.innerHTML = `Spinning...`;

        const winnableIndex = Math.floor(Math.random() * WHEEL_PRIZES.length);
        const segmentAngle = 360 / WHEEL_PRIZES.length;
        const randomOffset = (Math.random() - 0.5) * (segmentAngle * 0.8);

        // Get current rotation to ensure it keeps spinning forward
        const currentRotationMatch = wheel.style.transform.match(/rotate\((.+)deg\)/);
        const currentRotation = currentRotationMatch ? parseFloat(currentRotationMatch[1]) : 0;
        const revolutions = Math.floor(currentRotation / 360) + 5 + Math.floor(Math.random() * 3);

        const targetRotation = (360 * revolutions) - (winnableIndex * segmentAngle) - (segmentAngle / 2) + randomOffset;

        wheel.style.transform = `rotate(${targetRotation}deg)`;

        wheel.addEventListener('transitionend', () => {
            const prize = WHEEL_PRIZES[winnableIndex];
            showToast(`You won: ${prize.text}!`);
            if (prize.type === 'coin') {
                animateCoinGain(prize.value);
                updateMissionProgress('earn_coins', prize.value);
            }
            state.lastSpinTime = new Date().toISOString();
            saveProgress();
            openSpinWheelModal(); // Re-check cooldown
            updateNotificationDots();
        }, { once: true });
    }

    // --- Mission Logic ---
    function getDayOfYear(date) {
        const start = new Date(date.getFullYear(), 0, 0);
        const diff = date - start;
        const oneDay = 1000 * 60 * 60 * 24;
        return Math.floor(diff / oneDay);
    }

    function getWeekNumber(date) {
        const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        const dayNum = d.getUTCDay() || 7;
        d.setUTCDate(d.getUTCDate() + 4 - dayNum);
        const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
        return Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
    }

    function seededRandom(seed) {
        let x = Math.sin(seed) * 10000;
        return x - Math.floor(x);
    }

    function generateAndRenderMissions() {
        const now = new Date();
        const currentDay = getDayOfYear(now);
        const currentWeek = getWeekNumber(now);
        if (state.dailyMissions.date !== currentDay) {
            state.dailyMissions = { date: currentDay, missions: generateMissions('daily', currentDay) };
            Object.keys(state.missionStats.daily).forEach(key => state.missionStats.daily[key] = 0);
        }
        if (state.weeklyMissions.week !== currentWeek) {
            state.weeklyMissions = { week: currentWeek, missions: generateMissions('weekly', currentWeek) };
            Object.keys(state.missionStats.weekly).forEach(key => state.missionStats.weekly[key] = 0);
        }

        // Sync progress from stats to missions
        state.dailyMissions.missions.forEach(m => m.progress = state.missionStats.daily[m.id.replace('daily-', '')] || 0);
        state.weeklyMissions.missions.forEach(m => m.progress = state.missionStats.weekly[m.id.replace('weekly-', '')] || 0);

        saveProgress();
        renderMissions('daily');
        renderMissions('weekly');
    }

    function generateMissions(type, seed) {
        const missions = [];
        const missionPool = type === 'daily' ? DAILY_MISSIONS : WEEKLY_MISSIONS;
        const numMissions = 5;
        let tempPool = [...missionPool];
        for (let i = 0; i < numMissions; i++) {
            const missionSeed = seed + i;
            const index = Math.floor(seededRandom(missionSeed) * tempPool.length);
            const missionTemplate = tempPool.splice(index, 1)[0];
            if (!missionTemplate) continue;
            missions.push({
                id: `${type}-${missionTemplate.id}`, desc: missionTemplate.desc,
                icon: missionTemplate.icon, target: missionTemplate.target,
                reward: missionTemplate.reward, progress: 0, claimed: false
            });
            if (tempPool.length === 0) tempPool = [...missionPool];
        }
        return missions;
    }

    const DAILY_MISSIONS = [
        { id: 'play_3_games', desc: 'Play 3 Levels', icon: '🕹️', target: 3, reward: 100 },
        { id: 'complete_1_level', desc: 'Complete 1 Level', icon: '✅', target: 1, reward: 50 },
        { id: 'use_5_undos', desc: 'Use 5 Undos', icon: '⏪', target: 5, reward: 75 },
        { id: 'watch_2_ads', desc: 'Watch 2 Ads', icon: '📺', target: 2, reward: 150 },
        { id: 'complete_bomb_level', desc: 'Complete a Bomb Level', icon: '💣', target: 1, reward: 200 },
        { id: 'earn_500_coins', desc: 'Earn 500 Coins', icon: '🪙', target: 500, reward: 100 },
        { id: 'solve_level_no_undos', desc: 'Solve a level without undos', icon: '⭐', target: 1, reward: 250 },
        { id: 'invite_5_friends', desc: 'Invite 5 Friends', icon: '👨‍👩‍👧‍👦', target: 5, reward: 500 },
    ];

    const WEEKLY_MISSIONS = [
        { id: 'complete_25_levels', desc: 'Complete 25 Levels', icon: '🏆', target: 25, reward: 1000 },
        { id: 'earn_10000_coins', desc: 'Earn 10,000 Coins', icon: '💰', target: 10000, reward: 1500 },
        { id: 'complete_5_stone_levels', desc: 'Beat 5 Stone Wall levels', icon: '🧱', target: 5, reward: 750 },
        { id: 'complete_5_chain_levels', desc: 'Beat 5 Chained levels', icon: '⛓️', target: 5, reward: 750 },
        { id: 'reach_level_50', desc: 'Reach Level 50', icon: '🚀', target: 50, reward: 2000 },
        { id: 'invite_10_friends', desc: 'Invite 10 Friends', icon: '👨‍👩‍👧‍👦', target: 10, reward: 5000 },
        { id: 'collect_100_stars', desc: 'Collect 100 Stars', icon: '🌟', target: 100, reward: 1200 },
    ];

    function renderMissions(type) {
        const container = type === 'daily' ? dailyMissionsContainer : weeklyMissionsContainer;
        const missions = type === 'daily' ? state.dailyMissions.missions : state.weeklyMissions.missions;
        container.innerHTML = '';
        if (!missions || missions.length === 0) return;
        missions.forEach(mission => {
            const progressPercent = Math.min((mission.progress / mission.target) * 100, 100);
            const isComplete = mission.progress >= mission.target;
            const item = document.createElement('div');
            item.className = 'mission-item';
            item.innerHTML = `
                <div class="mission-icon">${mission.icon}</div>
                <div class="mission-details">
                    <div class="mission-desc">${mission.desc} (${mission.progress}/${mission.target})</div>
                    <div class="mission-progress-bar">
                        <div class="mission-progress-fill" style="width: ${progressPercent}%"></div>
                    </div>
                </div>
                <button class="neat-button mission-claim-btn" data-mission-id="${mission.id}" ${(!isComplete || mission.claimed) ? 'disabled' : ''}>
                    ${mission.claimed ? 'Claimed' : `+${mission.reward}`}
                </button>
            `;
            container.appendChild(item);
        });
    }

    function updateMissionProgress(action, value) {
        const mapping = {
            'play_game': ['play_3_games'],
            'complete_level': ['complete_1_level', 'complete_25_levels'],
            'use_undo': ['use_5_undos'],
            'watch_ad': ['watch_2_ads'],
            'earn_coins': ['earn_500_coins', 'earn_10000_coins'],
            'solve_level_no_undos': ['solve_level_no_undos'],
            'complete_bomb_level': ['complete_bomb_level'],
            'complete_stone_level': ['complete_5_stone_levels'],
            'complete_chain_level': ['complete_5_chain_levels'],
            'reach_level': ['reach_level_50'],
            'collect_stars': ['collect_100_stars'],
            'invite_friend': ['invite_5_friends', 'invite_10_friends'],
        };

        if (!mapping[action]) return;

        mapping[action].forEach(missionId => {
            if (state.missionStats.daily.hasOwnProperty(missionId)) {
                if (action === 'reach_level') {
                    state.missionStats.daily[missionId] = Math.max(state.missionStats.daily[missionId], value);
                } else {
                    state.missionStats.daily[missionId] = (state.missionStats.daily[missionId] || 0) + value;
                }
            }
            if (state.missionStats.weekly.hasOwnProperty(missionId)) {
                 if (action === 'reach_level') {
                    state.missionStats.weekly[missionId] = Math.max(state.missionStats.weekly[missionId], value);
                } else {
                    state.missionStats.weekly[missionId] = (state.missionStats.weekly[missionId] || 0) + value;
                }
            }
        });
        generateAndRenderMissions(); // This will re-sync and re-render
        updateNotificationDots();
    }

    function handleMissionClaim(missionId) {
        const type = missionId.startsWith('daily') ? 'daily' : 'weekly';
        const missions = state[`${type}Missions`].missions;
        const mission = missions.find(m => m.id === missionId);

        if (mission && !mission.claimed && mission.progress >= mission.target) {
            playSound('reward');
            mission.claimed = true;
            animateCoinGain(mission.reward);
            showToast(`Claimed ${mission.reward} coins!`);
            saveProgress();
            renderMissions(type);
            updateNotificationDots();
            if (type === 'daily') {
                checkDailyMissionsCompletion();
            }
        }
    }

    function updateMissionTimer(type) {
        clearInterval(missionTimerInterval);
        missionTimerInterval = setInterval(() => {
            const now = new Date();
            let endOfPeriod;
            if (type === 'daily') {
                endOfPeriod = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 0, 0);
            } else {
                const dayOfWeek = now.getDay();
                const daysUntilSunday = dayOfWeek === 0 ? 0 : 7 - dayOfWeek;
                endOfPeriod = new Date(now.getFullYear(), now.getMonth(), now.getDate() + daysUntilSunday);
                endOfPeriod.setHours(23, 59, 59, 999);
            }
            const diff = endOfPeriod - now;
            const d = Math.floor(diff / (1000 * 60 * 60 * 24));
            const h = Math.floor((diff / (1000 * 60 * 60)) % 24);
            const m = Math.floor(diff / 1000 / 60) % 60;
            const s = Math.floor(diff / 1000) % 60;

            let timerText = type === 'daily'
                ? `${h.toString().padStart(2,'0')}:${m.toString().padStart(2,'0')}:${s.toString().padStart(2,'0')}`
                : `${d}d ${h.toString().padStart(2,'0')}h ${m.toString().padStart(2,'0')}m`;

            missionTimer.textContent = `Resets in: ${timerText}`;
        }, 1000);
    }

    function updateUIForPro() {
        if (state.isPro) {
            proModeBtn.style.display = 'none';
            const proBadge = document.createElement('span');
            proBadge.className = 'pro-badge';
            proBadge.textContent = 'PRO';
            profileBtn.appendChild(proBadge);
        } else {
            proModeBtn.style.display = 'flex';
            const existingBadge = profileBtn.querySelector('.pro-badge');
            if (existingBadge) existingBadge.remove();
        }
        updateUndoButtonUI();
    }

    // --- NEW: Notification Dot Logic ---
    function updateNotificationDots() {
        // Daily Bonus
        if (isNewDay(state.lastLogin)) {
            addDotToButton('daily-bonus-btn');
        } else {
            removeDotFromButton('daily-bonus-btn');
        }

        // Spin Wheel
        const lastSpin = state.lastSpinTime ? new Date(state.lastSpinTime).getTime() : 0;
        const now = new Date().getTime();
        const cooldown = 5 * 60 * 1000;
        if (now - lastSpin >= cooldown) {
            addDotToButton('spin-wheel-btn');
        } else {
            removeDotFromButton('spin-wheel-btn');
        }

        // Missions
        const hasClaimableMission = (state.dailyMissions.missions.some(m => m.progress >= m.target && !m.claimed) ||
                                     state.weeklyMissions.missions.some(m => m.progress >= m.target && !m.claimed));
        if (hasClaimableMission) {
            addDotToButton('missions-btn');
        } else {
            removeDotFromButton('missions-btn');
        }
    }

    function addDotToButton(buttonId) {
        const button = document.getElementById(buttonId);
        if (button && !button.querySelector('.notification-dot')) {
            const dot = document.createElement('div');
            dot.className = 'notification-dot';
            button.appendChild(dot);
        }
    }

    function removeDotFromButton(buttonId) {
        const button = document.getElementById(buttonId);
        const dot = button ? button.querySelector('.notification-dot') : null;
        if (dot) {
            dot.remove();
        }
    }

    init();
});
