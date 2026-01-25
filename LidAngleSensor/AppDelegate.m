//
//  AppDelegate.m
//  LidAngleSensor
//
//  Created by Sam on 2025-09-06.
//

#import "AppDelegate.h"
#import "LidAngleSensor.h"
#import "CreakAudioEngine.h"
#import "ThereminAudioEngine.h"
#import "AccordionAudioEngine.h"
#import "NSLabel.h"

typedef NS_ENUM(NSInteger, AudioMode) {
    AudioModeCreak,
    AudioModeTheremin,
    AudioModeAccordion
};

@interface AppDelegate ()
@property (strong, nonatomic) LidAngleSensor *lidSensor;
@property (strong, nonatomic) CreakAudioEngine *creakAudioEngine;
@property (strong, nonatomic) ThereminAudioEngine *thereminAudioEngine;
@property (strong, nonatomic) AccordionAudioEngine *accordionAudioEngine;
@property (strong, nonatomic) NSLabel *angleLabel;
@property (strong, nonatomic) NSLabel *statusLabel;
@property (strong, nonatomic) NSLabel *velocityLabel;
@property (strong, nonatomic) NSLabel *audioStatusLabel;
@property (strong, nonatomic) NSLabel *notesLabel;
@property (strong, nonatomic) NSButton *audioToggleButton;
@property (strong, nonatomic) NSSegmentedControl *modeSelector;
@property (strong, nonatomic) NSLabel *modeLabel;
@property (strong, nonatomic) NSImageView *accordionImageView;
@property (strong, nonatomic) NSButton *sampleModeCheckbox;
@property (strong, nonatomic) NSTimer *updateTimer;
@property (nonatomic, assign) AudioMode currentAudioMode;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.currentAudioMode = AudioModeAccordion; // Default to accordion mode
    [self createWindow];
    [self initializeLidSensor];
    [self initializeAudioEngines];
    [self setupKeyboardMonitoring];
    [self startUpdatingDisplay];
    
    // Show accordion image and sample mode checkbox since we start in accordion mode
    [self.accordionImageView setHidden:NO];
    [self.sampleModeCheckbox setHidden:NO];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self.updateTimer invalidate];
    [self.lidSensor stopLidAngleUpdates];
    [self.creakAudioEngine stopEngine];
    [self.thereminAudioEngine stopEngine];
    [self.accordionAudioEngine stopEngine];
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (void)createWindow {
    // Create the main window (taller to accommodate mode selection, audio controls, accordion image, and sample mode checkbox)
    NSRect windowFrame = NSMakeRect(100, 100, 450, 620);
    self.window = [[NSWindow alloc] initWithContentRect:windowFrame
                                              styleMask:NSWindowStyleMaskTitled | 
                                                       NSWindowStyleMaskClosable | 
                                                       NSWindowStyleMaskMiniaturizable
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    
    [self.window setTitle:@"MacBook Lid Angle Sensor"];
    [self.window makeKeyAndOrderFront:nil];
    [self.window center];
    [self.window setAcceptsMouseMovedEvents:YES];
    
    // Create the content view
    NSView *contentView = [[NSView alloc] initWithFrame:windowFrame];
    [self.window setContentView:contentView];
    
    // Create angle display label with tabular numbers (larger, light font)
    self.angleLabel = [[NSLabel alloc] init];
    [self.angleLabel setStringValue:@"Initializing..."];
    [self.angleLabel setFont:[NSFont monospacedDigitSystemFontOfSize:48 weight:NSFontWeightLight]];
    [self.angleLabel setAlignment:NSTextAlignmentCenter];
    [self.angleLabel setTextColor:[NSColor systemBlueColor]];
    [contentView addSubview:self.angleLabel];
    
    // Create velocity display label with tabular numbers
    self.velocityLabel = [[NSLabel alloc] init];
    [self.velocityLabel setStringValue:@"Velocity: 00 deg/s"];
    [self.velocityLabel setFont:[NSFont monospacedDigitSystemFontOfSize:14 weight:NSFontWeightRegular]];
    [self.velocityLabel setAlignment:NSTextAlignmentCenter];
    [contentView addSubview:self.velocityLabel];
    
    // Create status label
    self.statusLabel = [[NSLabel alloc] init];
    [self.statusLabel setStringValue:@"Detecting sensor..."];
    [self.statusLabel setFont:[NSFont systemFontOfSize:14]];
    [self.statusLabel setAlignment:NSTextAlignmentCenter];
    [self.statusLabel setTextColor:[NSColor secondaryLabelColor]];
    [contentView addSubview:self.statusLabel];
    
    // Create audio toggle button
    self.audioToggleButton = [[NSButton alloc] init];
    [self.audioToggleButton setTitle:@"Start Audio"];
    // Use modern button style (compatible with macOS 11.5+)
    // NSBezelStyleRounded is deprecated but still works; using buttonType for better compatibility
    [self.audioToggleButton setButtonType:NSButtonTypePushOnPushOff];
    [self.audioToggleButton setBezelStyle:NSBezelStyleRounded]; // Still supported for compatibility
    [self.audioToggleButton setTarget:self];
    [self.audioToggleButton setAction:@selector(toggleAudio:)];
    [self.audioToggleButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [contentView addSubview:self.audioToggleButton];
    
    // Create audio status label
    self.audioStatusLabel = [[NSLabel alloc] init];
    [self.audioStatusLabel setStringValue:@""];
    [self.audioStatusLabel setFont:[NSFont systemFontOfSize:14]];
    [self.audioStatusLabel setAlignment:NSTextAlignmentCenter];
    [self.audioStatusLabel setTextColor:[NSColor secondaryLabelColor]];
    [contentView addSubview:self.audioStatusLabel];
    
    // Create mode label
    self.modeLabel = [[NSLabel alloc] init];
    [self.modeLabel setStringValue:@"Audio Mode:"];
    [self.modeLabel setFont:[NSFont systemFontOfSize:14 weight:NSFontWeightMedium]];
    [self.modeLabel setAlignment:NSTextAlignmentCenter];
    [self.modeLabel setTextColor:[NSColor labelColor]];
    [contentView addSubview:self.modeLabel];
    
    // Create notes label (for accordion mode)
    self.notesLabel = [[NSLabel alloc] init];
    [self.notesLabel setStringValue:@""];
    [self.notesLabel setFont:[NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightRegular]];
    [self.notesLabel setAlignment:NSTextAlignmentCenter];
    [self.notesLabel setTextColor:[NSColor secondaryLabelColor]];
    [contentView addSubview:self.notesLabel];
    
    // Create accordion image view
    self.accordionImageView = [[NSImageView alloc] init];
    [self.accordionImageView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [self.accordionImageView setImageAlignment:NSImageAlignCenter];
    [self.accordionImageView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [contentView addSubview:self.accordionImageView];
    
    // Create accordion icon programmatically (simple drawing)
    NSImage *accordionIcon = [self createAccordionIcon];
    [self.accordionImageView setImage:accordionIcon];
    [self.accordionImageView setHidden:YES]; // Hidden by default, shown in accordion mode
    
    // Create sample mode checkbox (only visible in accordion mode)
    self.sampleModeCheckbox = [[NSButton alloc] init];
    [self.sampleModeCheckbox setButtonType:NSButtonTypeSwitch];
    [self.sampleModeCheckbox setTitle:@"Use Sample Sound"];
    [self.sampleModeCheckbox setState:NSControlStateValueOff]; // Default to synthesis
    [self.sampleModeCheckbox setTarget:self];
    [self.sampleModeCheckbox setAction:@selector(sampleModeChanged:)];
    [self.sampleModeCheckbox setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.sampleModeCheckbox setHidden:YES]; // Hidden by default, shown in accordion mode
    [contentView addSubview:self.sampleModeCheckbox];
    
    // Create mode selector
    self.modeSelector = [[NSSegmentedControl alloc] init];
    [self.modeSelector setSegmentCount:3];
    [self.modeSelector setLabel:@"Creak" forSegment:0];
    [self.modeSelector setLabel:@"Theremin" forSegment:1];
    [self.modeSelector setLabel:@"Accordion" forSegment:2];
    [self.modeSelector setSelectedSegment:2]; // Default to accordion
    [self.modeSelector setTarget:self];
    [self.modeSelector setAction:@selector(modeChanged:)];
    [self.modeSelector setTranslatesAutoresizingMaskIntoConstraints:NO];
    [contentView addSubview:self.modeSelector];
    
    // Set up auto layout constraints
    [NSLayoutConstraint activateConstraints:@[
        // Angle label (main display, now at top)
        [self.angleLabel.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:40],
        [self.angleLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.angleLabel.widthAnchor constraintLessThanOrEqualToAnchor:contentView.widthAnchor constant:-40],
        
        // Velocity label
        [self.velocityLabel.topAnchor constraintEqualToAnchor:self.angleLabel.bottomAnchor constant:15],
        [self.velocityLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.velocityLabel.widthAnchor constraintLessThanOrEqualToAnchor:contentView.widthAnchor constant:-40],
        
        // Status label
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.velocityLabel.bottomAnchor constant:15],
        [self.statusLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.statusLabel.widthAnchor constraintLessThanOrEqualToAnchor:contentView.widthAnchor constant:-40],
        
        // Audio toggle button
        [self.audioToggleButton.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:25],
        [self.audioToggleButton.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.audioToggleButton.widthAnchor constraintEqualToConstant:120],
        [self.audioToggleButton.heightAnchor constraintEqualToConstant:32],
        
        // Audio status label
        [self.audioStatusLabel.topAnchor constraintEqualToAnchor:self.audioToggleButton.bottomAnchor constant:15],
        [self.audioStatusLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.audioStatusLabel.widthAnchor constraintLessThanOrEqualToAnchor:contentView.widthAnchor constant:-40],
        
        // Notes label (for accordion)
        [self.notesLabel.topAnchor constraintEqualToAnchor:self.audioStatusLabel.bottomAnchor constant:10],
        [self.notesLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.notesLabel.widthAnchor constraintLessThanOrEqualToAnchor:contentView.widthAnchor constant:-40],
        
        // Accordion image view (show only in accordion mode)
        [self.accordionImageView.topAnchor constraintEqualToAnchor:self.notesLabel.bottomAnchor constant:15],
        [self.accordionImageView.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.accordionImageView.widthAnchor constraintEqualToConstant:120],
        [self.accordionImageView.heightAnchor constraintEqualToConstant:80],
        
        // Sample mode checkbox
        [self.sampleModeCheckbox.topAnchor constraintEqualToAnchor:self.accordionImageView.bottomAnchor constant:15],
        [self.sampleModeCheckbox.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        
        // Mode label
        [self.modeLabel.topAnchor constraintEqualToAnchor:self.sampleModeCheckbox.bottomAnchor constant:20],
        [self.modeLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.modeLabel.widthAnchor constraintLessThanOrEqualToAnchor:contentView.widthAnchor constant:-40],
        
        // Mode selector
        [self.modeSelector.topAnchor constraintEqualToAnchor:self.modeLabel.bottomAnchor constant:10],
        [self.modeSelector.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.modeSelector.widthAnchor constraintEqualToConstant:300],
        [self.modeSelector.heightAnchor constraintEqualToConstant:28],
        [self.modeSelector.bottomAnchor constraintLessThanOrEqualToAnchor:contentView.bottomAnchor constant:-20]
    ]];
}

- (void)initializeLidSensor {
    self.lidSensor = [[LidAngleSensor alloc] init];
    
    if (self.lidSensor.isAvailable) {
        [self.statusLabel setStringValue:@"Sensor detected - Reading angle..."];
        [self.statusLabel setTextColor:[NSColor systemGreenColor]];
    } else {
        [self.statusLabel setStringValue:@"Lid angle sensor not available on this device"];
        [self.statusLabel setTextColor:[NSColor systemRedColor]];
        [self.angleLabel setStringValue:@"Not Available"];
        [self.angleLabel setTextColor:[NSColor systemRedColor]];
    }
}

- (void)initializeAudioEngines {
    self.creakAudioEngine = [[CreakAudioEngine alloc] init];
    self.thereminAudioEngine = [[ThereminAudioEngine alloc] init];
    self.accordionAudioEngine = [[AccordionAudioEngine alloc] init];
    
    if (self.creakAudioEngine && self.thereminAudioEngine && self.accordionAudioEngine) {
        [self.audioStatusLabel setStringValue:@""];
    } else {
        [self.audioStatusLabel setStringValue:@"Audio initialization failed"];
        [self.audioStatusLabel setTextColor:[NSColor systemRedColor]];
        [self.audioToggleButton setEnabled:NO];
    }
}

- (IBAction)toggleAudio:(id)sender {
    id currentEngine = [self currentAudioEngine];
    if (!currentEngine) {
        return;
    }
    
    if ([currentEngine isEngineRunning]) {
        [currentEngine stopEngine];
        [self.audioToggleButton setTitle:@"Start Audio"];
        [self.audioStatusLabel setStringValue:@""];
    } else {
        [currentEngine startEngine];
        [self.audioToggleButton setTitle:@"Stop Audio"];
        [self.audioStatusLabel setStringValue:@""];
    }
}

- (IBAction)modeChanged:(id)sender {
    NSSegmentedControl *control = (NSSegmentedControl *)sender;
    AudioMode newMode = (AudioMode)control.selectedSegment;
    
    // Stop current engine if running
    id currentEngine = [self currentAudioEngine];
    BOOL wasRunning = [currentEngine isEngineRunning];
    if (wasRunning) {
        [currentEngine stopEngine];
    }
    
    // Update mode
    self.currentAudioMode = newMode;
    
    // Show/hide accordion image and sample mode checkbox based on mode
    BOOL isAccordionMode = (newMode == AudioModeAccordion);
    [self.accordionImageView setHidden:!isAccordionMode];
    [self.sampleModeCheckbox setHidden:!isAccordionMode];
    
    // Start new engine if the previous one was running
    if (wasRunning) {
        id newEngine = [self currentAudioEngine];
        [newEngine startEngine];
        [self.audioToggleButton setTitle:@"Stop Audio"];
    } else {
        [self.audioToggleButton setTitle:@"Start Audio"];
    }
    
    [self.audioStatusLabel setStringValue:@""];
}

- (IBAction)sampleModeChanged:(id)sender {
    NSButton *checkbox = (NSButton *)sender;
    BOOL useSamples = (checkbox.state == NSControlStateValueOn);
    
    if (self.currentAudioMode == AudioModeAccordion && self.accordionAudioEngine) {
        self.accordionAudioEngine.useSamples = useSamples;
        NSLog(@"[AppDelegate] Sample mode changed: %@", useSamples ? @"Samples" : @"Synthesis");
    }
}

- (id)currentAudioEngine {
    switch (self.currentAudioMode) {
        case AudioModeCreak:
            return self.creakAudioEngine;
        case AudioModeTheremin:
            return self.thereminAudioEngine;
        case AudioModeAccordion:
            return self.accordionAudioEngine;
        default:
            return self.creakAudioEngine;
    }
}

- (void)startUpdatingDisplay {
    // Update every 16ms (60Hz) for smooth real-time audio and display updates
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.016
                                                        target:self
                                                      selector:@selector(updateAngleDisplay)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)updateAngleDisplay {
    if (!self.lidSensor.isAvailable) {
        return;
    }
    
    double angle = [self.lidSensor lidAngle];
    
    if (angle == -2.0) {
        [self.angleLabel setStringValue:@"Read Error"];
        [self.angleLabel setTextColor:[NSColor systemOrangeColor]];
        [self.statusLabel setStringValue:@"Failed to read sensor data"];
        [self.statusLabel setTextColor:[NSColor systemOrangeColor]];
    } else {
        [self.angleLabel setStringValue:[NSString stringWithFormat:@"%.1f°", angle]];
        [self.angleLabel setTextColor:[NSColor systemBlueColor]];
        
        // Update current audio engine with new angle
        id currentEngine = [self currentAudioEngine];
        if (currentEngine) {
            [currentEngine updateWithLidAngle:angle];
            
            // Update velocity display with leading zero and whole numbers
            double velocity = [currentEngine currentVelocity];
            int roundedVelocity = (int)round(velocity);
            if (roundedVelocity < 100) {
                [self.velocityLabel setStringValue:[NSString stringWithFormat:@"Velocity: %02d deg/s", roundedVelocity]];
            } else {
                [self.velocityLabel setStringValue:[NSString stringWithFormat:@"Velocity: %d deg/s", roundedVelocity]];
            }
            
            // Show audio parameters when running
            if ([currentEngine isEngineRunning]) {
                if (self.currentAudioMode == AudioModeCreak) {
                    double gain = [currentEngine currentGain];
                    double rate = [currentEngine currentRate];
                    [self.audioStatusLabel setStringValue:[NSString stringWithFormat:@"Gain: %.2f, Rate: %.2f", gain, rate]];
                    [self.notesLabel setStringValue:@""];
                } else if (self.currentAudioMode == AudioModeTheremin) {
                    double frequency = [currentEngine currentFrequency];
                    double volume = [currentEngine currentVolume];
                    [self.audioStatusLabel setStringValue:[NSString stringWithFormat:@"Freq: %.1f Hz, Vol: %.2f", frequency, volume]];
                    [self.notesLabel setStringValue:@""];
                } else if (self.currentAudioMode == AudioModeAccordion) {
                    AccordionAudioEngine *accordion = (AccordionAudioEngine *)currentEngine;
                    double bellowsVolume = [accordion currentBellowsVolume];
                    [self.audioStatusLabel setStringValue:[NSString stringWithFormat:@"Bellows: %.2f", bellowsVolume]];
                    
                    // Show pressed buttons
                    NSArray<NSNumber *> *pressedButtons = [accordion pressedNotes];
                    if (pressedButtons.count > 0) {
                        NSMutableArray<NSString *> *buttonLabels = [[NSMutableArray alloc] init];
                        for (NSNumber *buttonNum in pressedButtons) {
                            int buttonIndex = [buttonNum intValue];
                            [buttonLabels addObject:[NSString stringWithFormat:@"Btn%d", buttonIndex + 1]];
                        }
                        [self.notesLabel setStringValue:[NSString stringWithFormat:@"Buttons: %@", [buttonLabels componentsJoinedByString:@", "]]];
                    } else {
                        [self.notesLabel setStringValue:@"Press keys to play (move lid to activate)"];
                    }
                }
            } else {
                if (self.currentAudioMode == AudioModeAccordion) {
                    [self.notesLabel setStringValue:@"Start audio and press keys"];
                } else {
                    [self.notesLabel setStringValue:@""];
                }
            }
        }
        
        // Provide contextual status based on angle
        NSString *status;
        if (angle < 5.0) {
            status = @"Lid is closed";
        } else if (angle < 45.0) {
            status = @"Lid slightly open";
        } else if (angle < 90.0) {
            status = @"Lid partially open";
        } else if (angle < 120.0) {
            status = @"Lid mostly open";
        } else {
            status = @"Lid fully open";
        }
        
        // Update status based on mode
        if (self.currentAudioMode == AudioModeAccordion) {
            if (angle < 5.0) {
                status = @"Меха закрыты (закройте крышку)";
            } else if (angle < 45.0) {
                status = @"Меха слегка открыты";
            } else if (angle < 90.0) {
                status = @"Меха частично открыты";
            } else if (angle < 120.0) {
                status = @"Меха открыты";
            } else {
                status = @"Меха полностью открыты";
            }
        }
        
        [self.statusLabel setStringValue:status];
        [self.statusLabel setTextColor:[NSColor secondaryLabelColor]];
    }
}

#pragma mark - Keyboard Handling

- (void)setupKeyboardMonitoring {
    // Use global monitor for keyboard events (works even when window doesn't have focus)
    NSEventMask eventMask = NSEventMaskKeyDown | NSEventMaskKeyUp;
    [NSEvent addGlobalMonitorForEventsMatchingMask:eventMask handler:^(NSEvent * _Nonnull event) {
        [self handleKeyboardEvent:event];
    }];
    
    // Also add local monitor for when window has focus
    // Return nil to prevent system sounds when keys are pressed
    [NSEvent addLocalMonitorForEventsMatchingMask:eventMask handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        if (self.currentAudioMode == AudioModeAccordion) {
            [self handleKeyboardEvent:event];
            // Return nil to prevent system keyboard sounds
            return nil;
        }
        return event;
    }];
}

- (void)handleKeyboardEvent:(NSEvent *)event {
    if (self.currentAudioMode != AudioModeAccordion) {
        return;
    }
    
    if (!self.accordionAudioEngine || ![self.accordionAudioEngine isEngineRunning]) {
        return;
    }
    
    NSEventType eventType = event.type;
    
    if (eventType == NSEventTypeKeyDown) {
        int buttonIndex = [self accordionButtonIndexFromKeyCode:event.keyCode];
        if (buttonIndex >= 0) {
            [self.accordionAudioEngine pressNote:buttonIndex];
        }
    } else if (eventType == NSEventTypeKeyUp) {
        int buttonIndex = [self accordionButtonIndexFromKeyCode:event.keyCode];
        if (buttonIndex >= 0) {
            [self.accordionAudioEngine releaseNote:buttonIndex];
        }
    }
}

// Map QWERTY keyboard keys to accordion button indices
// Layout: A S D F G H J K L ; ' (white keys)
//         W E   T Y U   O P [ (black keys)
- (int)accordionButtonIndexFromKeyCode:(unsigned short)keyCode {
    // QWERTY keyboard mapping to accordion button indices (0-11)
    // Key codes based on macOS virtual key codes
    switch (keyCode) {
        // Белые клавиши -> основные кнопки гармошки
        case 0: return 0;  // A -> Кнопка 1 (C/D)
        case 1: return 1;   // S -> Кнопка 2 (E/F)
        case 2: return 2;  // D -> Кнопка 3 (G/A)
        case 3: return 3;  // F -> Кнопка 4 (B/C)
        case 5: return 8;  // G -> Кнопка 9 (D/E)
        case 4: return 9;   // H -> Кнопка 10 (F/G)
        case 38: return 10; // J -> Кнопка 11 (A/B)
        case 40: return 11; // K -> Кнопка 12 (C/D)
        case 37: return 4;  // L -> Кнопка 5 (C#/D#)
        case 41: return 5;  // ; -> Кнопка 6 (F#/G#)
        case 39: return 6;  // ' -> Кнопка 7 (A#/C)
        
        // Черные клавиши -> дополнительные кнопки
        case 13: return 4;  // W -> Кнопка 5 (C#/D#)
        case 14: return 5;  // E -> Кнопка 6 (F#/G#)
        case 17: return 6;   // T -> Кнопка 7 (A#/C)
        case 16: return 7;   // Y -> Кнопка 8 (C#/D#)
        case 32: return 7;   // U -> Кнопка 8 (C#/D#)
        case 31: return 7;   // O -> Кнопка 8 (C#/D#)
        case 35: return 7;   // P -> Кнопка 8 (C#/D#)
        case 33: return 7;  // [ -> Кнопка 8 (C#/D#)
        
        default:
            return -1; // Invalid key
    }
}

- (NSString *)noteNameFromMIDI:(int)midiNote {
    static NSArray<NSString *> *noteNames = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        noteNames = @[@"C", @"C#", @"D", @"D#", @"E", @"F", @"F#", @"G", @"G#", @"A", @"A#", @"B"];
    });
    
    int octave = (midiNote / 12) - 1;
    int note = midiNote % 12;
    return [NSString stringWithFormat:@"%@%d", noteNames[note], octave];
}

- (NSImage *)createAccordionIcon {
    // Create a simple accordion icon programmatically using modern API (compatible with macOS 11.5+)
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(120, 80)];
    
    // Use modern drawing API instead of deprecated lockFocus/unlockFocus
    [image lockFocus];
    @try {
        // Set background to transparent
        [[NSColor clearColor] set];
        NSRectFill(NSMakeRect(0, 0, 120, 80));
        
        // Draw accordion body (rectangular shape)
        NSBezierPath *body = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(20, 20, 80, 40) xRadius:5 yRadius:5];
        [[NSColor systemBlueColor] set];
        [body fill];
        [[NSColor systemBlueColor] setStroke];
        [body setLineWidth:2];
        [body stroke];
        
        // Draw bellows (accordion folds)
        for (int i = 0; i < 5; i++) {
            NSRect foldRect = NSMakeRect(30 + i * 12, 25, 8, 30);
            NSBezierPath *fold = [NSBezierPath bezierPathWithRoundedRect:foldRect xRadius:2 yRadius:2];
            [[NSColor colorWithWhite:0.3 alpha:1.0] set];
            [fold fill];
        }
        
        // Draw keyboard buttons
        for (int i = 0; i < 8; i++) {
            NSRect buttonRect = NSMakeRect(25 + i * 8, 15, 6, 4);
            [[NSColor colorWithWhite:0.9 alpha:1.0] set];
            NSRectFill(buttonRect);
        }
    } @finally {
        [image unlockFocus];
    }
    
    return image;
}

@end
