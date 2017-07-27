//
//  BRChatViewController.m
//  TestIMDemo
//
//  Created by 任波 on 2017/7/25.
//  Copyright © 2017年 renb. All rights reserved.
//

#import "BRChatViewController.h"
#import "BRChatCell.h"

@interface BRChatViewController ()<UITableViewDataSource, UITableViewDelegate, UITextViewDelegate>
/** 输入toolBar底部的约束 */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *toolBarBottomLayoutConstraint;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

// 用这个cell对象来计算cell的高度
@property (nonatomic, strong) BRChatCell *chatCellTool;

@property (nonatomic, strong) NSMutableArray *messageModelArr;

@end

@implementation BRChatViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = self.contactUsername;
    // 监听键盘的弹出(显示)，更改toolBar底部的约束（将工具条往上移，防止被键盘挡住）
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShowToAction:) name:UIKeyboardWillShowNotification object:nil];
    
    // 监听键盘的退出(隐藏)，工具条恢复原位
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHideToAction:) name:UIKeyboardWillHideNotification object:nil];
    
    [self loadData];
}

- (void)loadData {
    // 获取一个会话
    EMConversation *conversation = [[EMClient sharedClient].chatManager getConversation:self.contactUsername type:EMConversationTypeChat createIfNotExist:YES];
    // 加载本地数据库聊天记录
    [conversation loadMessagesStartFromId:nil count:10 searchDirection:EMMessageSearchDirectionUp completion:^(NSArray *aMessages, EMError *aError) {
        if (!aError) {
            NSLog(@"获取到的消息 aMessages：%@", aMessages);
            [self.messageModelArr addObjectsFromArray:aMessages];
            [self.tableView reloadData];
        }
    }];
}

#pragma mark - 键盘显示时会触发的方法
- (void)keyboardWillShowToAction:(NSNotification *)sender {
    // 1.获取键盘的高度
    // 1.1 获取键盘弹出结束时的位置
    CGRect endFrame = [sender.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat keyboardHeight = endFrame.size.height;
    // 2.更改工具条底部的约束
    self.toolBarBottomLayoutConstraint.constant = keyboardHeight;
    // 添加动画：保证键盘的弹出和工具条的上移 同步
    [UIView animateWithDuration:0.2 animations:^{
        // 刷新布局，重新布局子控件
        [self.view layoutIfNeeded];
    }];
}

#pragma mark - 键盘隐藏时会触发的方法
- (void)keyboardWillHideToAction:(NSNotification *)sender {
    // 工具条恢复原位
    self.toolBarBottomLayoutConstraint.constant = 0;
    [UIView animateWithDuration:0.2 animations:^{
        [self.view layoutIfNeeded];
    }];
}

#pragma mark - UITableViewDataSource, UITableViewDelegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messageModelArr.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    EMMessage *messageModel = self.messageModelArr[indexPath.row];
    
    static NSString *cellID = nil;
    if ([messageModel.from isEqualToString:self.contactUsername]) { //接收方（好友） 显示在左边
        cellID = @"leftCell";
    } else { // 发送方（自己）显示在右边
        cellID = @"rightCell";
    }
    BRChatCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    
    cell.messageModel = messageModel;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // 点击tableView隐藏键盘
    [self.view endEditing:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    // 随便获取一个cell对象（目的是拿到一个模块装入数据，计算出高度）
    self.chatCellTool = [tableView dequeueReusableCellWithIdentifier:@"leftCell"];
    // 给模型赋值
    self.chatCellTool.messageModel = self.messageModelArr[indexPath.row];
    
    return [self.chatCellTool cellHeight];
}

#pragma mark - UITextViewDelegate
- (void)textViewDidChange:(UITextView *)textView {
    // 监听send事件(判断最后一个字符是不是 "\n" 换行字符)
    if ([textView.text hasSuffix:@"\n"]) {
        NSLog(@"发送操作");
        // 清除最后的换行字符（换行字符 只占用一个长度）
        textView.text = [textView.text substringToIndex:textView.text.length - 1];
        // 发送消息
        [self sendMessage:textView.text];
        // 发送消息后，清空输入框
        textView.text = nil;
    }
}

#pragma mark - 发送消息
- (void)sendMessage:(NSString *)text {
    NSLog(@"contactUsername:%@", self.contactUsername);
    // 消息 = 消息头 + 消息体
    // 1.构造消息（构造文字消息）
    EMTextMessageBody *body = [[EMTextMessageBody alloc] initWithText:text];
    NSString *username = [[EMClient sharedClient] currentUsername];
    EMMessage *message = [[EMMessage alloc] initWithConversationID:self.contactUsername from:username to:self.contactUsername body:body ext:nil];
    // 消息类型：设置为单聊消息（一对一聊天）
    message.chatType = EMChatTypeChat;
    // 2.发送消息（异步方法）
    [[EMClient sharedClient].chatManager sendMessage:message progress:nil completion:^(EMMessage *message, EMError *error) {
        if (!error) {
            NSLog(@"发送消息成功！");
        }
    }];
    // 3.把消息添加到数据源，再刷新表格
    [self.messageModelArr addObject:message];
    [self.tableView reloadData];
    //[self loadData];
    // 4.把消息显示在顶部
    [self scrollToBottom];
}

- (void)scrollToBottom {
    if (self.messageModelArr.count == 0) {
        return;
    }
    // 获取最后一行
    NSIndexPath *lastIndex = [NSIndexPath indexPathForRow:self.messageModelArr.count - 1 inSection:0];
    // 滚动到底部可见
    [self.tableView scrollToRowAtIndexPath:lastIndex atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

- (NSMutableArray *)messageModelArr {
    if (!_messageModelArr) {
        _messageModelArr = [[NSMutableArray alloc]init];
    }
    return _messageModelArr;
}

- (void)dealloc {
    // 移除通知
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end