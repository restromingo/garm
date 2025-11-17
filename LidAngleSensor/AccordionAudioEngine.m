//
//  AccordionAudioEngine.m
//  LidAngleSensor
//
//  Created for Accordion mode
//

#import "AccordionAudioEngine.h"
#import <AudioToolbox/AudioToolbox.h>

@implementation AccordionButton
@end

// Accordion parameter mapping constants
static const double kMinBellowsVolume = 0.0;        // НОЛЬ когда меха не двигаются!
static const double kMaxBellowsVolume = 1.0;        
static const double kMinAngle = 0.0;                
static const double kMaxAngle = 135.0;              

// Velocity-based bellows control
static const double kVelocityVolumeBoost = 1.0;     
static const double kVelocityMin = 0.5;              // Минимальная скорость для минимальной громкости (deg/s)
static const double kVelocityMax = 30.0;             // Скорость для максимальной громкости (deg/s)
static const double kMinVelocityThreshold = 1.0;    // Минимальная скорость для звука (deg/s) - звук только при скорости > 1 deg/s

// Bellows direction detection
static const double kBellowsDirectionThreshold = 0.5; // Порог для определения направления (deg/s)

// Smoothing constants
static const double kAngleSmoothingFactor = 0.1;     
static const double kVelocitySmoothingFactor = 0.3;  
static const double kVolumeRampTimeMs = 50.0;       
static const double kMovementThreshold = 0.2;       // Снижено для более чувствительного определения движения
static const double kMovementTimeoutMs = 1000.0;      // Увеличено для более длинного звука (1000ms = 1 секунда)
static const double kVelocityDecayFactor = 0.98;     // Очень медленное затухание (0.98)
static const double kAdditionalDecayFactor = 0.99;    // Почти не затухает (0.99)    

// Audio constants
static const double kSampleRate = 44100.0;
static const UInt32 kBufferSize = 512;
static const int kMaxPolyphony = 16;                

// MIDI note constants
static const int kBaseNote = 60;                    // C4
static const double kNoteReleaseTime = 0.1;         

@interface AccordionNote : NSObject
@property (nonatomic, assign) int buttonIndex;         // Индекс кнопки гармошки (0, 1, 2...)
@property (nonatomic, assign) int currentPlayingNote;   // Текущая играемая нота (зависит от направления)
@property (nonatomic, assign) double phase;
@property (nonatomic, assign) double phaseIncrement;
@property (nonatomic, assign) double volume;
@property (nonatomic, assign) double targetVolume;
@property (nonatomic, assign) BOOL isReleasing;
@property (nonatomic, assign) NSTimeInterval releaseStartTime;
@end

@implementation AccordionNote
@end

@interface AccordionAudioEngine ()

// Audio engine components
@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, strong) AVAudioSourceNode *sourceNode;
@property (nonatomic, strong) AVAudioMixerNode *mixerNode;

// State tracking
@property (nonatomic, assign) double lastLidAngle;
@property (nonatomic, assign) double smoothedLidAngle;
@property (nonatomic, assign) double lastUpdateTime;
@property (nonatomic, assign) double smoothedVelocity;
@property (nonatomic, assign) double targetBellowsVolume;
@property (nonatomic, assign) double currentBellowsVolume;
@property (nonatomic, assign) BOOL isFirstUpdate;
@property (nonatomic, assign) NSTimeInterval lastMovementTime;

// Notes management
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, AccordionNote *> *activeNotes;

// Accordion buttons mapping (каждая кнопка = две ноты)
@property (nonatomic, strong) NSArray<AccordionButton *> *accordionButtons;

// Bellows direction tracking
@property (nonatomic, assign) BOOL isBellowsOpening;   // TRUE = разжимание (pull), FALSE = сжатие (push)
@property (nonatomic, assign) double lastAngleForDirection;

// Sample-based audio (when useSamples = YES)
@property (nonatomic, strong) AVAudioFile *sampleFile;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, AVAudioPlayerNode *> *samplePlayers; // buttonIndex -> player
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, AVAudioUnitTimePitch *> *samplePitchUnits; // buttonIndex -> pitch unit

@end

@implementation AccordionAudioEngine

- (instancetype)init {
    self = [super init];
    if (self) {
        _isFirstUpdate = YES;
        _lastUpdateTime = CACurrentMediaTime();
        _lastMovementTime = CACurrentMediaTime();
        _lastLidAngle = 0.0;
        _lastAngleForDirection = 0.0;
        _smoothedLidAngle = 0.0;
        _smoothedVelocity = 0.0;
        _targetBellowsVolume = kMinBellowsVolume;
        _currentBellowsVolume = kMinBellowsVolume;
        _isBellowsOpening = YES; // По умолчанию разжимание
        _activeNotes = [[NSMutableDictionary alloc] init];
        _useSamples = NO; // По умолчанию синтез
        _samplePlayers = [[NSMutableDictionary alloc] init];
        _samplePitchUnits = [[NSMutableDictionary alloc] init];
        
        // Инициализировать кнопки гармошки
        [self setupAccordionButtons];
        
        // Загрузить сэмпл файл (если доступен)
        [self loadSampleFile];
        
        if (![self setupAudioEngine]) {
            NSLog(@"[AccordionAudioEngine] Failed to setup audio engine");
            return nil;
        }
    }
    return self;
}

- (void)dealloc {
    [self stopEngine];
}

#pragma mark - Accordion Buttons Setup

- (void)setupAccordionButtons {
    // Создать массив кнопок гармошки
    // Каждая кнопка имеет две ноты: pullNote (разжимание) и pushNote (сжатие)
    // Пример:
    // Кнопка 1: C (pull=60) / D (push=62)
    // Кнопка 2: E (pull=64) / F (push=65)
    // Кнопка 3: G (pull=67) / A (push=69)
    // Кнопка 4: B (pull=71) / C (push=72)
    
    NSMutableArray<AccordionButton *> *buttons = [[NSMutableArray alloc] init];
    
    // Кнопка 1: C/D
    AccordionButton *btn1 = [[AccordionButton alloc] init];
    btn1.pullNote = 60; // C4
    btn1.pushNote = 62;  // D4
    [buttons addObject:btn1];
    
    // Кнопка 2: E/F
    AccordionButton *btn2 = [[AccordionButton alloc] init];
    btn2.pullNote = 64; // E4
    btn2.pushNote = 65; // F4
    [buttons addObject:btn2];
    
    // Кнопка 3: G/A
    AccordionButton *btn3 = [[AccordionButton alloc] init];
    btn3.pullNote = 67; // G4
    btn3.pushNote = 69; // A4
    [buttons addObject:btn3];
    
    // Кнопка 4: B/C
    AccordionButton *btn4 = [[AccordionButton alloc] init];
    btn4.pullNote = 71; // B4
    btn4.pushNote = 72; // C5
    [buttons addObject:btn4];
    
    // Кнопка 5: C#/D#
    AccordionButton *btn5 = [[AccordionButton alloc] init];
    btn5.pullNote = 61; // C#4
    btn5.pushNote = 63;  // D#4
    [buttons addObject:btn5];
    
    // Кнопка 6: F#/G#
    AccordionButton *btn6 = [[AccordionButton alloc] init];
    btn6.pullNote = 66; // F#4
    btn6.pushNote = 68; // G#4
    [buttons addObject:btn6];
    
    // Кнопка 7: A#/C
    AccordionButton *btn7 = [[AccordionButton alloc] init];
    btn7.pullNote = 70; // A#4
    btn7.pushNote = 72; // C5
    [buttons addObject:btn7];
    
    // Кнопка 8: C#/D#
    AccordionButton *btn8 = [[AccordionButton alloc] init];
    btn8.pullNote = 73; // C#5
    btn8.pushNote = 75; // D#5
    [buttons addObject:btn8];
    
    // Кнопка 9: D/E
    AccordionButton *btn9 = [[AccordionButton alloc] init];
    btn9.pullNote = 62; // D4
    btn9.pushNote = 64; // E4
    [buttons addObject:btn9];
    
    // Кнопка 10: F/G
    AccordionButton *btn10 = [[AccordionButton alloc] init];
    btn10.pullNote = 65; // F4
    btn10.pushNote = 67; // G4
    [buttons addObject:btn10];
    
    // Кнопка 11: A/B
    AccordionButton *btn11 = [[AccordionButton alloc] init];
    btn11.pullNote = 69; // A4
    btn11.pushNote = 71; // B4
    [buttons addObject:btn11];
    
    // Кнопка 12: C/D
    AccordionButton *btn12 = [[AccordionButton alloc] init];
    btn12.pullNote = 72; // C5
    btn12.pushNote = 74; // D5
    [buttons addObject:btn12];
    
    self.accordionButtons = buttons;
    NSLog(@"[AccordionAudioEngine] Initialized %lu accordion buttons", (unsigned long)buttons.count);
}

#pragma mark - Sample Loading

- (void)loadSampleFile {
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *samplePath = [bundle pathForResource:@"гармошка" ofType:@"wav"];
    if (!samplePath) {
        NSLog(@"[AccordionAudioEngine] Sample file not found, using synthesized sound");
        return;
    }
    
    NSError *error;
    NSURL *sampleURL = [NSURL fileURLWithPath:samplePath];
    self.sampleFile = [[AVAudioFile alloc] initForReading:sampleURL error:&error];
    if (!self.sampleFile) {
        NSLog(@"[AccordionAudioEngine] Failed to load sample file: %@", error.localizedDescription);
        return;
    }
    
    NSLog(@"[AccordionAudioEngine] Sample file loaded successfully (G4 note)");
}

#pragma mark - Audio Engine Setup

- (BOOL)setupAudioEngine {
    self.audioEngine = [[AVAudioEngine alloc] init];
    self.mixerNode = self.audioEngine.mainMixerNode;
    
    // Create audio format for our sine wave
    AVAudioFormat *format = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                             sampleRate:kSampleRate
                                                               channels:1
                                                            interleaved:NO];
    
    // Create source node for sine wave generation
    __weak typeof(self) weakSelf = self;
    self.sourceNode = [[AVAudioSourceNode alloc] initWithFormat:format renderBlock:^OSStatus(BOOL * _Nonnull isSilence, const AudioTimeStamp * _Nonnull timestamp, AVAudioFrameCount frameCount, AudioBufferList * _Nonnull outputData) {
        return [weakSelf renderAccordionSound:isSilence timestamp:timestamp frameCount:frameCount outputData:outputData];
    }];
    
    // Attach and connect the source node
    [self.audioEngine attachNode:self.sourceNode];
    [self.audioEngine connect:self.sourceNode to:self.mixerNode format:format];
    
    return YES;
}

#pragma mark - Engine Control

- (void)startEngine {
    if (self.isEngineRunning) {
        return;
    }
    
    NSError *error;
    if (![self.audioEngine startAndReturnError:&error]) {
        NSLog(@"[AccordionAudioEngine] Failed to start audio engine: %@", error.localizedDescription);
        return;
    }
    
    NSLog(@"[AccordionAudioEngine] Started accordion engine");
}

- (void)stopEngine {
    if (!self.isEngineRunning) {
        return;
    }
    
    // Stop all sample players
    for (NSNumber *buttonKey in self.samplePlayers.allKeys) {
        AVAudioPlayerNode *player = self.samplePlayers[buttonKey];
        AVAudioUnitTimePitch *pitchUnit = self.samplePitchUnits[buttonKey];
        [player stop];
        [self.audioEngine detachNode:player];
        [self.audioEngine detachNode:pitchUnit];
    }
    [self.samplePlayers removeAllObjects];
    [self.samplePitchUnits removeAllObjects];
    
    [self.activeNotes removeAllObjects];
    [self.audioEngine stop];
    NSLog(@"[AccordionAudioEngine] Stopped accordion engine");
}

- (BOOL)isEngineRunning {
    return self.audioEngine.isRunning;
}

#pragma mark - Sound Generation

- (OSStatus)renderAccordionSound:(BOOL *)isSilence
                       timestamp:(const AudioTimeStamp *)timestamp
                      frameCount:(AVAudioFrameCount)frameCount
                      outputData:(AudioBufferList *)outputData {
    
    float *output = (float *)outputData->mBuffers[0].mData;
    
    // If using samples, don't generate synthesized sound
    if (self.useSamples && self.sampleFile) {
        *isSilence = YES;
        memset(output, 0, frameCount * sizeof(float));
        return noErr;
    }
    
    // Check if we have any active notes
    if (self.activeNotes.count == 0) {
        *isSilence = YES;
        memset(output, 0, frameCount * sizeof(float));
        return noErr;
    }
    
    *isSilence = NO;
    
    // Mix all active notes
    memset(output, 0, frameCount * sizeof(float));
    
    // Collect notes to remove (can't modify dictionary while iterating)
    NSMutableArray<NSNumber *> *notesToRemove = [[NSMutableArray alloc] init];
    NSArray<AccordionNote *> *notes = [self.activeNotes allValues];
    
    for (AccordionNote *note in notes) {
        // Update note volume (for release fade)
        double currentTime = CACurrentMediaTime();
        if (note.isReleasing) {
            double releaseElapsed = currentTime - note.releaseStartTime;
            if (releaseElapsed >= kNoteReleaseTime) {
                // Note fully released, mark for removal
                [notesToRemove addObject:@(note.buttonIndex)];
                continue;
            } else {
                // Fade out during release
                double releaseProgress = releaseElapsed / kNoteReleaseTime;
                note.targetVolume = 0.0;
                note.volume = note.volume * (1.0 - releaseProgress);
            }
        } else {
            // Smooth volume ramp
            double alpha = 0.1;
            note.volume = note.volume + (note.targetVolume - note.volume) * alpha;
        }
        
        // Generate sine wave for this note
        for (AVAudioFrameCount i = 0; i < frameCount; i++) {
            // Add harmonics for accordion-like timbre (fundamental + octave + fifth)
            double sample = sin(note.phase) * 0.6;                    // Fundamental
            sample += sin(note.phase * 2.0) * 0.25;                  // Octave
            sample += sin(note.phase * 3.0) * 0.15;                  // Fifth
            
            // Apply note volume and bellows volume
            output[i] += (float)(sample * note.volume * self.currentBellowsVolume * 0.4);
            
            // Update phase
            note.phase += note.phaseIncrement;
            if (note.phase >= 2.0 * M_PI) {
                note.phase -= 2.0 * M_PI;
            }
        }
    }
    
    // Remove fully released notes
    for (NSNumber *noteKey in notesToRemove) {
        [self.activeNotes removeObjectForKey:noteKey];
    }
    
    return noErr;
}

#pragma mark - Note Management

- (void)pressNote:(int)buttonIndex {
    if (buttonIndex < 0 || buttonIndex >= self.accordionButtons.count) {
        return;
    }
    
    if (self.useSamples && self.sampleFile) {
        // Use sample-based playback
        [self pressNoteWithSample:buttonIndex];
    } else {
        // Use synthesized sound
        [self pressNoteWithSynthesis:buttonIndex];
    }
}

- (void)pressNoteWithSynthesis:(int)buttonIndex {
    // Limit polyphony
    if (self.activeNotes.count >= kMaxPolyphony) {
        // Remove oldest note
        NSNumber *oldestKey = [[self.activeNotes allKeys] firstObject];
        [self.activeNotes removeObjectForKey:oldestKey];
    }
    
    // Get accordion button
    AccordionButton *button = self.accordionButtons[buttonIndex];
    
    // Create or reactivate note
    NSNumber *noteKey = @(buttonIndex);
    AccordionNote *accordionNote = self.activeNotes[noteKey];
    
    if (!accordionNote) {
        accordionNote = [[AccordionNote alloc] init];
        accordionNote.buttonIndex = buttonIndex;
        
        // Определить текущую играемую ноту в зависимости от направления мехов
        accordionNote.currentPlayingNote = [self getPlayingNoteForButton:button];
        
        accordionNote.phase = 0.0;
        
        // Calculate frequency from current playing note
        double frequency = 440.0 * pow(2.0, (accordionNote.currentPlayingNote - 69) / 12.0);
        accordionNote.phaseIncrement = 2.0 * M_PI * frequency / kSampleRate;
        
        accordionNote.volume = 0.0;
        accordionNote.targetVolume = 1.0;
        accordionNote.isReleasing = NO;
        
        self.activeNotes[noteKey] = accordionNote;
    } else {
        // Reactivate if releasing
        accordionNote.isReleasing = NO;
        accordionNote.targetVolume = 1.0;
        accordionNote.releaseStartTime = 0;
        
        // Обновить играемую ноту в зависимости от текущего направления
        accordionNote.currentPlayingNote = [self getPlayingNoteForButton:button];
        
        // Пересчитать частоту для новой ноты
        double frequency = 440.0 * pow(2.0, (accordionNote.currentPlayingNote - 69) / 12.0);
        accordionNote.phaseIncrement = 2.0 * M_PI * frequency / kSampleRate;
    }
    
    NSLog(@"[AccordionAudioEngine] Pressed button: %d, playing note: %d (%@) [Synthesis]", 
          buttonIndex, accordionNote.currentPlayingNote, self.isBellowsOpening ? @"pull" : @"push");
}

- (void)pressNoteWithSample:(int)buttonIndex {
    if (!self.isEngineRunning) {
        return;
    }
    
    // Limit polyphony
    if (self.samplePlayers.count >= kMaxPolyphony) {
        // Remove oldest player
        NSNumber *oldestKey = [[self.samplePlayers allKeys] firstObject];
        [self releaseNoteWithSample:[oldestKey intValue]];
    }
    
    NSNumber *buttonKey = @(buttonIndex);
    
    // Check if already playing
    if (self.samplePlayers[buttonKey]) {
        // Already playing, just update pitch if direction changed
        [self updateSamplePitchForButton:buttonIndex];
        return;
    }
    
    // Get accordion button
    AccordionButton *button = self.accordionButtons[buttonIndex];
    int playingNote = [self getPlayingNoteForButton:button];
    
    // Calculate pitch shift from G4 (note 67) to target note
    // Sample is G4, so we need to shift pitch
    int semitones = playingNote - 67; // G4 = MIDI note 67
    float pitchInCents = semitones * 100.0; // 100 cents per semitone
    
    // Create player node
    AVAudioPlayerNode *player = [[AVAudioPlayerNode alloc] init];
    AVAudioUnitTimePitch *pitchUnit = [[AVAudioUnitTimePitch alloc] init];
    pitchUnit.pitch = pitchInCents;
    
    // Attach nodes
    [self.audioEngine attachNode:player];
    [self.audioEngine attachNode:pitchUnit];
    
    // Connect: Player -> Pitch -> Mixer
    AVAudioFormat *format = self.sampleFile.processingFormat;
    [self.audioEngine connect:player to:pitchUnit format:format];
    [self.audioEngine connect:pitchUnit to:self.mixerNode format:format];
    
    // Load sample into buffer
    // Reset file position to beginning before reading
    self.sampleFile.framePosition = 0;
    
    AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format 
                                                              frameCapacity:(AVAudioFrameCount)self.sampleFile.length];
    NSError *error;
    if (![self.sampleFile readIntoBuffer:buffer error:&error]) {
        NSLog(@"[AccordionAudioEngine] Failed to read sample: %@", error.localizedDescription);
        return;
    }
    
    // Schedule buffer to loop
    [player scheduleBuffer:buffer atTime:nil options:AVAudioPlayerNodeBufferLoops completionHandler:nil];
    
    // Start playing
    [player play];
    
    // Store references
    self.samplePlayers[buttonKey] = player;
    self.samplePitchUnits[buttonKey] = pitchUnit;
    
    NSLog(@"[AccordionAudioEngine] Pressed button: %d, playing note: %d (%@) [Sample, pitch: %.1f cents]", 
          buttonIndex, playingNote, self.isBellowsOpening ? @"pull" : @"push", pitchInCents);
}

- (void)releaseNote:(int)buttonIndex {
    if (self.useSamples && self.sampleFile) {
        // Use sample-based playback
        [self releaseNoteWithSample:buttonIndex];
    } else {
        // Use synthesized sound
        [self releaseNoteWithSynthesis:buttonIndex];
    }
}

- (void)releaseNoteWithSynthesis:(int)buttonIndex {
    NSNumber *noteKey = @(buttonIndex);
    AccordionNote *accordionNote = self.activeNotes[noteKey];
    
    if (accordionNote && !accordionNote.isReleasing) {
        accordionNote.isReleasing = YES;
        accordionNote.releaseStartTime = CACurrentMediaTime();
        NSLog(@"[AccordionAudioEngine] Released button: %d [Synthesis]", buttonIndex);
    }
}

- (void)releaseNoteWithSample:(int)buttonIndex {
    NSNumber *buttonKey = @(buttonIndex);
    AVAudioPlayerNode *player = self.samplePlayers[buttonKey];
    AVAudioUnitTimePitch *pitchUnit = self.samplePitchUnits[buttonKey];
    
    if (player) {
        // Stop and remove player
        [player stop];
        [self.audioEngine detachNode:player];
        [self.audioEngine detachNode:pitchUnit];
        
        [self.samplePlayers removeObjectForKey:buttonKey];
        [self.samplePitchUnits removeObjectForKey:buttonKey];
        
        NSLog(@"[AccordionAudioEngine] Released button: %d [Sample]", buttonIndex);
    }
}

- (void)updateSamplePitchForButton:(int)buttonIndex {
    NSNumber *buttonKey = @(buttonIndex);
    AVAudioUnitTimePitch *pitchUnit = self.samplePitchUnits[buttonKey];
    
    if (!pitchUnit) {
        return;
    }
    
    AccordionButton *button = self.accordionButtons[buttonIndex];
    int playingNote = [self getPlayingNoteForButton:button];
    
    // Calculate new pitch shift
    int semitones = playingNote - 67; // G4 = MIDI note 67
    float pitchInCents = semitones * 100.0;
    
    pitchUnit.pitch = pitchInCents;
    
    NSLog(@"[AccordionAudioEngine] Updated pitch for button %d: note %d, pitch %.1f cents", 
          buttonIndex, playingNote, pitchInCents);
}

- (NSArray<NSNumber *> *)pressedNotes {
    NSMutableArray<NSNumber *> *pressed = [[NSMutableArray alloc] init];
    
    if (self.useSamples && self.sampleFile) {
        // Return all active sample players
        [pressed addObjectsFromArray:[self.samplePlayers allKeys]];
    } else {
        // Return all active synthesized notes
        for (NSNumber *noteKey in self.activeNotes.allKeys) {
            AccordionNote *note = self.activeNotes[noteKey];
            if (!note.isReleasing) {
                [pressed addObject:noteKey];
            }
        }
    }
    
    return pressed;
}

// Новый метод для определения играемой ноты
- (int)getPlayingNoteForButton:(AccordionButton *)button {
    if (self.isBellowsOpening) {
        // Разжимание (pull) - вдох
        return button.pullNote;
    } else {
        // Сжатие (push) - выдох
        return button.pushNote;
    }
}

#pragma mark - Lid Angle Processing

- (void)updateWithLidAngle:(double)lidAngle {
    double currentTime = CACurrentMediaTime();
    
    if (self.isFirstUpdate) {
        self.lastLidAngle = lidAngle;
        self.lastAngleForDirection = lidAngle;
        self.smoothedLidAngle = lidAngle;
        self.lastUpdateTime = currentTime;
        self.lastMovementTime = currentTime;
        self.isFirstUpdate = NO;
        
        [self updateTargetBellowsVolumeWithAngle:lidAngle velocity:0.0];
        return;
    }
    
    double deltaTime = currentTime - self.lastUpdateTime;
    if (deltaTime <= 0 || deltaTime > 1.0) {
        self.lastUpdateTime = currentTime;
        return;
    }
    
    // Stage 1: Smooth the raw angle input
    self.smoothedLidAngle = (kAngleSmoothingFactor * lidAngle) + 
                           ((1.0 - kAngleSmoothingFactor) * self.smoothedLidAngle);
    
    // Stage 2: Calculate velocity and direction
    double deltaAngle = self.smoothedLidAngle - self.lastAngleForDirection;
    double instantVelocity;
    
    // Определить направление движения мехов
    if (fabs(deltaAngle) >= kBellowsDirectionThreshold / 100.0) {
        // Угол увеличивается = крышка открывается = меха разжимаются (pull/inhale)
        // Угол уменьшается = крышка закрывается = меха сжимаются (push/exhale)
        BOOL newDirection = deltaAngle > 0; // TRUE = разжимание (pull), FALSE = сжатие (push)
        
        if (newDirection != self.isBellowsOpening) {
            // Направление изменилось! Обновить ноты для всех активных кнопок
            self.isBellowsOpening = newDirection;
            [self updateNotesForDirectionChange];
        }
        
        self.lastAngleForDirection = self.smoothedLidAngle;
    }
    
    // Apply movement threshold
    double angleDelta = self.smoothedLidAngle - self.lastLidAngle;
    if (fabs(angleDelta) < kMovementThreshold) {
        instantVelocity = 0.0;
    } else {
        instantVelocity = fabs(angleDelta / deltaTime);
        self.lastLidAngle = self.smoothedLidAngle;
    }
    
    // Stage 3: Apply velocity smoothing and decay
    if (instantVelocity > 0.0) {
        self.smoothedVelocity = (kVelocitySmoothingFactor * instantVelocity) + 
                               ((1.0 - kVelocitySmoothingFactor) * self.smoothedVelocity);
        self.lastMovementTime = currentTime;
    } else {
        self.smoothedVelocity *= kVelocityDecayFactor;
    }
    
    double timeSinceMovement = currentTime - self.lastMovementTime;
    if (timeSinceMovement > (kMovementTimeoutMs / 1000.0)) {
        self.smoothedVelocity *= kAdditionalDecayFactor;
    }
    
    self.lastUpdateTime = currentTime;
    
    [self updateTargetBellowsVolumeWithAngle:self.smoothedLidAngle velocity:self.smoothedVelocity];
    [self rampToTargetBellowsVolume];
}

// Новый метод для обновления нот при изменении направления
- (void)updateNotesForDirectionChange {
    if (self.useSamples && self.sampleFile) {
        // Update pitch for all active sample players
        for (NSNumber *buttonKey in self.samplePlayers.allKeys) {
            [self updateSamplePitchForButton:[buttonKey intValue]];
        }
    } else {
        // Update frequency for synthesized notes
        for (NSNumber *buttonKey in self.activeNotes.allKeys) {
            AccordionNote *note = self.activeNotes[buttonKey];
            if (!note.isReleasing) {
                AccordionButton *button = self.accordionButtons[note.buttonIndex];
                
                // Обновить играемую ноту
                int oldNote = note.currentPlayingNote;
                note.currentPlayingNote = [self getPlayingNoteForButton:button];
                
                // Плавно изменить частоту
                double oldFrequency = 440.0 * pow(2.0, (oldNote - 69) / 12.0);
                double newFrequency = 440.0 * pow(2.0, (note.currentPlayingNote - 69) / 12.0);
                
                double frequencyRatio = newFrequency / oldFrequency;
                note.phaseIncrement *= frequencyRatio;
                
                NSLog(@"[AccordionAudioEngine] Direction changed: button %d, note %d -> %d (%@)", 
                      note.buttonIndex, oldNote, note.currentPlayingNote, 
                      self.isBellowsOpening ? @"pull" : @"push");
            }
        }
    }
}

- (void)updateTargetBellowsVolumeWithAngle:(double)angle velocity:(double)velocity {
    // Угол влияет на максимальную громкость
    double normalizedAngle = fmax(0.0, fmin(1.0, (angle - kMinAngle) / (kMaxAngle - kMinAngle)));
    double maxVolumeFromAngle = kMinBellowsVolume + normalizedAngle * (kMaxBellowsVolume - kMinBellowsVolume);
    
    // Громкость зависит от скорости движения: БЫСТРЕЕ = ГРОМЧЕ
    double velocityVolume = 0.0;
    
    if (velocity > kMinVelocityThreshold) {
        // Есть движение - громкость пропорциональна скорости
        // Нормализуем скорость от kVelocityMin до kVelocityMax
        double normalizedVelocity = fmin(1.0, fmax(0.0, (velocity - kVelocityMin) / (kVelocityMax - kVelocityMin)));
        
        // Используем smoothstep для плавной кривой: медленное = тихо, быстрое = громко
        double t = normalizedVelocity;
        double s = t * t * (3.0 - 2.0 * t); // smoothstep
        
        // Применяем: минимальная громкость при медленном движении, максимальная при быстром
        double minVolumeRatio = 0.2; // Минимум 20% от максимальной громкости
        velocityVolume = (minVolumeRatio + s * (1.0 - minVolumeRatio)) * maxVolumeFromAngle;
    } else {
        // Очень медленное движение или почти остановилось - плавное затухание
        double fadeRatio = velocity / kMinVelocityThreshold; // От 0 до 1
        fadeRatio = fmax(0.0, fmin(1.0, fadeRatio));
        velocityVolume = self.currentBellowsVolume * fadeRatio * 0.3; // Плавное затухание до 30% от текущей
    }
    
    self.targetBellowsVolume = velocityVolume;
    self.targetBellowsVolume = fmax(0.0, fmin(kMaxBellowsVolume, self.targetBellowsVolume));
}

- (double)rampValue:(double)current toward:(double)target withDeltaTime:(double)dt timeConstantMs:(double)tauMs {
    double alpha = fmin(1.0, dt / (tauMs / 1000.0));
    return current + (target - current) * alpha;
}

- (void)rampToTargetBellowsVolume {
    // Calculate delta time for ramping
    static double lastRampTime = 0;
    double currentTime = CACurrentMediaTime();
    if (lastRampTime == 0) lastRampTime = currentTime;
    double deltaTime = currentTime - lastRampTime;
    lastRampTime = currentTime;
    
    // Ramp current bellows volume toward target
    self.currentBellowsVolume = [self rampValue:self.currentBellowsVolume 
                                        toward:self.targetBellowsVolume 
                                 withDeltaTime:deltaTime 
                               timeConstantMs:kVolumeRampTimeMs];
    
    // Update volume for sample players if using samples
    if (self.useSamples && self.sampleFile) {
        for (NSNumber *buttonKey in self.samplePlayers.allKeys) {
            AVAudioPlayerNode *player = self.samplePlayers[buttonKey];
            if (player) {
                player.volume = (float)self.currentBellowsVolume;
            }
        }
    }
}

#pragma mark - Property Accessors

- (double)currentVelocity {
    return self.smoothedVelocity;
}

- (double)currentBellowsVolume {
    return _currentBellowsVolume;
}

- (void)setUseSamples:(BOOL)useSamples {
    if (_useSamples == useSamples) {
        return;
    }
    
    BOOL wasRunning = self.isEngineRunning;
    
    // Stop current playback
    if (wasRunning) {
        [self stopEngine];
    }
    
    // Clear all active notes/players
    [self.activeNotes removeAllObjects];
    for (NSNumber *buttonKey in self.samplePlayers.allKeys) {
        AVAudioPlayerNode *player = self.samplePlayers[buttonKey];
        AVAudioUnitTimePitch *pitchUnit = self.samplePitchUnits[buttonKey];
        [player stop];
        [self.audioEngine detachNode:player];
        [self.audioEngine detachNode:pitchUnit];
    }
    [self.samplePlayers removeAllObjects];
    [self.samplePitchUnits removeAllObjects];
    
    _useSamples = useSamples;
    
    NSLog(@"[AccordionAudioEngine] Switched to %@ mode", useSamples ? @"Sample" : @"Synthesis");
    
    // Restart engine if it was running
    if (wasRunning) {
        [self startEngine];
    }
}

@end
