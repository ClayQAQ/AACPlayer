//
//  AACPlayer.m
//  AACPlayer
//
//  Created by 李文仲 on 2021/10/19.
//  Copyright © 2021 CLAY. All rights reserved.
//

#import "AACPlayer.h"
#import <AudioToolbox/AudioToolbox.h>

const uint32_t CONST_BUFFER_COUNT = 3;
const uint32_t CONST_BUFFER_SIZE = 0x10000;


@implementation AACPlayer
{
    AudioFileID audioFileID; // An opaque data type that represents an audio file object.
    AudioStreamBasicDescription audioStreamBasicDescrpition; // An audio data format specification for a stream of audio
    AudioStreamPacketDescription *audioStreamPacketDescrption; // Describes one packet in a buffer of audio data where the sizes of the packets differ or where there is non-audio data between audio packets.

    AudioQueueRef audioQueue; // Defines an opaque data type that represents an audio queue.
    AudioQueueBufferRef audioBuffers[CONST_BUFFER_COUNT];

    SInt64 readedPacket; //参数类型
    u_int32_t packetNums;

}


- (instancetype)init {
    self = [super init];
    [self customAudioConfig];

    return self;
}

- (void)customAudioConfig {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"ribuluo" withExtension:@"aac"];
    //打开音频文件, 得到audioFileID  (audio toolbox 的方法)
    OSStatus status = AudioFileOpenURL((__bridge CFURLRef)url, kAudioFileReadPermission, 0, &audioFileID); //Open an existing audio file specified by a URL.
    if (status != noErr) {
        NSLog(@"打开文件失败 %@", url);
        return ;
    }
    uint32_t size = sizeof(audioStreamBasicDescrpition);
    //得到音频文件format
    status = AudioFileGetProperty(audioFileID, kAudioFilePropertyDataFormat, &size, &audioStreamBasicDescrpition); // Gets the value of an audio file property.
    NSAssert(status == noErr, @"error"); //Generates an assertion if a given condition is false.

    //得到audioQueue
    //bufferReady是函数指针, 指向的函数会重复填充音频数据packet 进行播放; A callback function to use with the playback audio queue. The audio queue invokes the callback when the audio queue has finished acquiring a buffer.
    status = AudioQueueNewOutput(&audioStreamBasicDescrpition, bufferReady, (__bridge void * _Nullable)(self), NULL, NULL, 0, &audioQueue); // Creates a new playback audio queue object.
    NSAssert(status == noErr, @"error");

    if (audioStreamBasicDescrpition.mBytesPerPacket == 0 || audioStreamBasicDescrpition.mFramesPerPacket == 0) {
        uint32_t maxSize;
        size = sizeof(maxSize);
        AudioFileGetProperty(audioFileID, kAudioFilePropertyPacketSizeUpperBound, &size, &maxSize); // The theoretical maximum packet size in the file.
        if (maxSize > CONST_BUFFER_SIZE) {
            maxSize = CONST_BUFFER_SIZE;
        }
        packetNums = CONST_BUFFER_SIZE / maxSize;
        audioStreamPacketDescrption = malloc(sizeof(AudioStreamPacketDescription) * packetNums);
    }
    else {
        packetNums = CONST_BUFFER_SIZE / audioStreamBasicDescrpition.mBytesPerPacket;
        audioStreamPacketDescrption = nil;
    }

    char cookies[100] = {0};
//    memset(cookies, 0, sizeof(cookies));
    // 这里的100 有问题
    AudioFileGetProperty(audioFileID, kAudioFilePropertyMagicCookieData, &size, cookies); // Some file types require that a magic cookie be provided before packets can be written to an audio file.
    if (size > 0) {
        AudioQueueSetProperty(audioQueue, kAudioQueueProperty_MagicCookie, cookies, size); // Sets an audio queue property value.
    }

    readedPacket = 0;
    for (int i = 0; i < CONST_BUFFER_COUNT; ++i) {
        //CONST_BUFFER_COUNT是指的3个音频缓冲区
        //CONST_BUFFER_SIZE是一个缓冲区的大小, 还挺大的字节数
        //方法是用来-> 申请3个音频缓冲区
        AudioQueueAllocateBuffer(audioQueue, CONST_BUFFER_SIZE, &audioBuffers[i]); // Asks an audio queue object to allocate an audio queue buffer.
        if ([self fillBuffer:audioBuffers[i]]) {
            // full
            break;
        }
        NSLog(@"buffer%d full", i);
    }
}

//A callback function to use with the playback audio queue.
//The audio queue invokes the callback when the audio queue has finished acquiring a buffer. 即:3个缓冲区,一开始在customAudioConfig全部填满,  当某个缓冲区添加到audioQueue后, 会自己自动调用此callback, 继续进行填充(填充并加到audioQueue)
void bufferReady(void *inUserData,AudioQueueRef inAQ,
                 AudioQueueBufferRef buffer){
    NSLog(@"refresh buffer");
    AACPlayer* player = (__bridge AACPlayer *)inUserData;
    if (!player) {
        NSLog(@"player nil");
        return ;
    }
    if ([player fillBuffer:buffer]) {
        NSLog(@"play end");
    }

}


- (void)play {
    //音量设置  //设置都是配置给audioQueue
    AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, 1.0); // Sets a playback audio queue parameter value.
    //开始播放
    AudioQueueStart(audioQueue, NULL); // Begins playing or recording audio.
}


- (bool)fillBuffer:(AudioQueueBufferRef)buffer {
    bool full = NO;
    uint32_t bytes = 0, packets = (uint32_t)packetNums;
    //读aac文件的packets
    /*!
        @function    AudioFileReadPackets
        @abstract   Read packets of audio data from the audio file.
        @discussion AudioFileReadPackets is DEPRECATED. Use AudioFileReadPacketData instead.
                    READ THE HEADER DOC FOR AudioFileReadPacketData. It is not a drop-in replacement.
                    In particular, for AudioFileReadPacketData ioNumBytes must be initialized to the buffer size.
                    AudioFileReadPackets assumes you have allocated your buffer to ioNumPackets times the maximum packet size.
                    For many compressed formats this will only use a portion of the buffer since the ratio of the maximum
                    packet size to the typical packet size can be large. Use AudioFileReadPacketData instead.

        @param inAudioFile                an AudioFileID.
        @param inUseCache                 true if it is desired to cache the data upon read, else false
        @param outNumBytes      读了多少字节           on output, the number of bytes actually returned
        @param outPacketDescriptions     on output, an array of packet descriptions describing
                                        the packets being returned. NULL may be passed for this
                                        parameter. Nothing will be returned for linear pcm data.
        @param inStartingPacket         the packet index of the first packet desired to be returned
        @param ioNumPackets 读了多少packet            on input, the number of packets to read, on output, the number of
                                        packets actually read.
        @param outBuffer     返回packet数据            outBuffer should be a pointer to user allocated memory of size:
                                        number of packets requested times file's maximum (or upper bound on)
                                        packet size.
        @result                            returns noErr if successful.
    */
    OSStatus status = AudioFileReadPackets(audioFileID, NO, &bytes, audioStreamPacketDescrption, readedPacket, &packets, buffer->mAudioData); // Reads packets of audio data from an audio file.

    NSAssert(status == noErr, ([NSString stringWithFormat:@"error status %d", status]) );
    if (packets > 0) { //packets:读到的packets数量
        buffer->mAudioDataByteSize = bytes; //填充当次读了多少字节
        //添加填满后的buffer 到audioQueue中
        AudioQueueEnqueueBuffer(audioQueue, buffer, packets, audioStreamPacketDescrption);
        readedPacket += packets; //记录当前读到的packets索引数
    }
    else { //文件中读不到packet了 -> 可能文件读取完毕; 也可能是当前没有读到
        AudioQueueStop(audioQueue, NO);
        full = YES;
    }

    return full;
}



- (double)getCurrentTime {
    Float64 timeInterval = 0.0;
    if (audioQueue) {
        AudioQueueTimelineRef timeLine;
        AudioTimeStamp timeStamp;
        OSStatus status = AudioQueueCreateTimeline(audioQueue, &timeLine); // Creates a timeline object for an audio queue.
        if(status == noErr)
        {
            AudioQueueGetCurrentTime(audioQueue, timeLine, &timeStamp, NULL); // Gets the current audio queue time.
            timeInterval = timeStamp.mSampleTime / audioStreamBasicDescrpition.mSampleRate; // The number of sample frames per second of the data in the stream.
        }
    }
    return timeInterval;
}


@end
