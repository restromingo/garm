//
//  AccordionAudioEngine.h
//  LidAngleSensor
//
//  Created for Accordion mode
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

/**
 * AccordionButton представляет одну кнопку гармошки с двумя нотами
 */
@interface AccordionButton : NSObject
@property (nonatomic, assign) int pullNote;  // Нота при разжимании мехов (вдох)
@property (nonatomic, assign) int pushNote;  // Нота при сжатии мехов (выдох)
@end

/**
 * AccordionAudioEngine provides real-time accordion audio that responds to MacBook lid angle changes.
 * 
 * Features:
 * - Play notes by pressing keyboard keys (each key = accordion button)
 * - Each button plays different note when bellows open vs close (bisonoric)
 * - Control bellows (меха) volume/timbre based on lid angle movement
 * - Multiple simultaneous notes (polyphonic)
 * - Sound only when bellows are moving
 */
@interface AccordionAudioEngine : NSObject

@property (nonatomic, assign, readonly) BOOL isEngineRunning;
@property (nonatomic, assign, readonly) double currentVelocity;
@property (nonatomic, assign, readonly) double currentBellowsVolume;
@property (nonatomic, assign) BOOL useSamples; // YES = use sample file, NO = synthesized sound

/**
 * Initialize the accordion audio engine.
 * @return Initialized engine instance, or nil if initialization failed
 */
- (instancetype)init;

/**
 * Start the audio engine and begin tone generation.
 */
- (void)startEngine;

/**
 * Stop the audio engine and halt tone generation.
 */
- (void)stopEngine;

/**
 * Update the accordion audio based on new lid angle measurement.
 * This controls the bellows (меха) - volume and timbre based on movement.
 * @param lidAngle Current lid angle in degrees
 */
- (void)updateWithLidAngle:(double)lidAngle;

/**
 * Press an accordion button (key down).
 * @param buttonIndex Index of accordion button (0-11)
 */
- (void)pressNote:(int)buttonIndex;

/**
 * Release an accordion button (key up).
 * @param buttonIndex Index of accordion button (0-11)
 */
- (void)releaseNote:(int)buttonIndex;

/**
 * Get currently pressed buttons.
 * @return Array of NSNumber objects representing button indices
 */
- (NSArray<NSNumber *> *)pressedNotes;

@end
