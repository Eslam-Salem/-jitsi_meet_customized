#import "JitsiMeetPlugin.h"
#if __has_include(<custom_jitsi_meet/custom_jitsi_meet-Swift.h>)
#import <custom_jitsi_meet/custom_jitsi_meet-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "custom_jitsi_meet-Swift.h"
#endif

@implementation JitsiMeetPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftJitsiMeetPlugin registerWithRegistrar:registrar];
}
@end
