#ifndef Runner_Bridging_Header_h
#define Runner_Bridging_Header_h
#import "GeneratedPluginRegistrant.h"
// 声明官方nodejs-mobile的C API函数
int nodeStart(int argc, char *argv[]);
void nodejs_channel_send(NSString *message);
void nodejs_channel_set_listener(void (^listener)(NSString *message));
#endif
