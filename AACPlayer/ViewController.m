//
//  ViewController.m
//  AACPlayer
//
//  Created by 李文仲 on 2021/10/19.
//  Copyright © 2021 CLAY. All rights reserved.
//

#import "ViewController.h"
#import "AACPlayer.h"
#import <AVFoundation/AVFoundation.h>


@interface ViewController ()
@property (nonatomic , strong) UILabel  *mLabel;
@property (nonatomic , strong) UILabel *mCurrentTimeLabel;
@property (nonatomic , strong) UIButton *mButton;
@property (nonatomic , strong) UIButton *mDecodeButton;
@property (nonatomic , strong) CADisplayLink *mDispalyLink;
@property (nonatomic , strong) AVAudioPlayer *audiopPlayer;
@end

@implementation ViewController
{
    AACPlayer *_aacPlayer;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.



    self.mLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 200, 100)];
    self.mLabel.textColor = [UIColor redColor];
    [self.view addSubview:self.mLabel];
    self.mLabel.text = @"测试ACC播放";

    self.mCurrentTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, 200, 100)];
    self.mCurrentTimeLabel.textColor = [UIColor redColor];
    [self.view addSubview:self.mCurrentTimeLabel];


    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(20, 250, 100, 50)];
    [button setTitle:@"play" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [self.view addSubview:button];
    [button addTarget:self action:@selector(onClick:) forControlEvents:UIControlEventTouchUpInside];
    self.mButton = button;

    self.mDecodeButton = [[UIButton alloc] initWithFrame:CGRectMake(20, 350, 100, 50)];
    [self.mDecodeButton setTitle:@"decode" forState:UIControlStateNormal];
    [self.mDecodeButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [self.view addSubview:self.mDecodeButton];
    [self.mDecodeButton addTarget:self action:@selector(onDecodeStart) forControlEvents:UIControlEventTouchUpInside];


    self.mDispalyLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateFrame)];
    self.mDispalyLink.preferredFramesPerSecond = 5; // 默认是30FPS的帧率录制
    [self.mDispalyLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
//    [self.mDispalyLink setPaused:YES];

}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)onClick:(UIButton *)button {
//    [self.mButton setHidden:YES];
    //audioURL=nil的主要原因是, 资源文件配置 没有对当前项目target打钩. 即当前资源实际没有加到工程里(main包里).
//    NSURL *audioURL =[[NSBundle mainBundle] URLForResource:@"ribuluo" withExtension:@"aac"];
    NSString *str = [[NSBundle mainBundle] pathForResource:@"ribuluo" ofType:@"aac"];
    NSURL *audioURL = [NSURL URLWithString:str];

    //1. 设置为系统音, 并播放系统音. (30s内的音乐才可以)
//    SystemSoundID soundID;
//    //Creates a system sound object.
//    AudioServicesCreateSystemSoundID((__bridge CFURLRef)(audioURL), &soundID);
//    //Registers a callback function that is invoked when a specified system sound finishes playing.
//    AudioServicesAddSystemSoundCompletion(soundID, NULL, NULL, &playCallback, (__bridge void * _Nullable)(self));
//    //AudioServicesPlayAlertSound，此方法在播放音效的同时会发出震动，给用户提醒。
//    //    AudioServicesPlayAlertSound(soundID);
//    AudioServicesPlaySystemSound(soundID);

    //2. 使用AVAudioPlayer播放 (AVFoundation)
    //AVAudioPlayer 必须设置为属性, 保证生命, 否则无法播放
    _audiopPlayer = [[AVAudioPlayer alloc]initWithContentsOfURL:audioURL error:nil];
    //设置音乐播放次数.numberOfLoops。设为0仅播放一次；设为1则循环1次播放2次；设为-1则循环播放不间断；
    _audiopPlayer.numberOfLoops = -1;
    //设置音乐声音大小.volume。
    _audiopPlayer.volume = 1.0f;
    [_audiopPlayer prepareToPlay];
    //开始播放，调用方法 play；停止播放：stop；
    [_audiopPlayer play];
}

- (void)onPlayCallback {
//    [self.mButton setHidden:NO];
}

void playCallback(SystemSoundID ID, void  * clientData){
    //3. 使用audioQueue 播放 (基于AudioToolbox框架, 填充3缓冲区加入音频队列)
    ViewController* controller = (__bridge ViewController *)clientData;
    [controller onPlayCallback];
}


- (void)onDecodeStart {
//    self.mDecodeButton.hidden = YES;
    _aacPlayer = [[AACPlayer alloc] init];
    [_aacPlayer play];
}


- (void)updateFrame {
    if (_aacPlayer) {
        double time = [_aacPlayer getCurrentTime];
        if (time >= 0) {
            self.mCurrentTimeLabel.text = [NSString stringWithFormat:@"当前时间:%.1fs", time];
        } else {
            self.mCurrentTimeLabel.text = [NSString stringWithFormat:@"当前时间:0s"];
        }

    }
}




@end
